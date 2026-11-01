import 'dart:convert';

/// Turns Anthropic's server-sent events (what the proxy's forwarding
/// produces) into the OpenAI Responses events a Codex server reads: the
/// items it shows (`message`, `function_call`), the text deltas, and the
/// `response.completed` that carries the usage.
///
/// One [convert] per line of the upstream's stream, as for
/// [ResponsesResponseTranslator] of the other direction; the events for a
/// line may be several, and a line that is not `data:` is nothing.
class CodexResponseBuilder {
  String get id => _id;
  String _id = 'resp_${DateTime.now().microsecondsSinceEpoch}';

  bool _opened = false;
  int _outputIndex = 0;

  /// The text of the message item being streamed, to be closed whole.
  final StringBuffer _text = StringBuffer();
  bool _textOpened = false;

  /// The function call being streamed: its name comes first, its
  /// arguments as deltas after.
  String? _callName;
  String _callId = '';
  final StringBuffer _callArguments = StringBuffer();
  bool _callOpened = false;

  int _inputTokens = 0;
  int _outputTokens = 0;

  /// The events for one line of the upstream's stream; empty for a line
  /// that is not `data:`, or one that carries nothing new.
  List<String> convert(String line) {
    if (!line.startsWith('data:')) return const [];
    final payload = line.substring(5).trim();
    if (payload.isEmpty) return const [];
    Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException {
      return const [];
    }
    if (decoded is! Map<String, Object?>) return const [];
    final type = decoded['type'] as String?;
    switch (type) {
      case 'message_start':
        final message = decoded['message'];
        if (message is Map && message['id'] is String) _id = message['id']! as String;
        return [_event('response.created', _responseBody())];
      case 'content_block_start':
        final block = decoded['content_block'];
        if (block is! Map) return const [];
        return switch (block['type']) {
          'tool_use' => _openCall(
            block['id'] as String? ?? '',
            block['name'] as String? ?? '',
          ),
          _ => const [],
        };
      case 'content_block_delta':
        final delta = decoded['delta'];
        if (delta is! Map) return const [];
        switch (delta['type']) {
          case 'text_delta':
            return _textDelta(delta['text'] as String? ?? '');
          case 'input_json_delta':
            return _argumentsDelta(delta['partial_json'] as String? ?? '');
          case 'thinking_delta':
            // The server shows its own thinking; Codex is not told.
            return const [];
        }
        return const [];
      case 'content_block_stop':
        if (_callOpened) return _closeCall();
        return const [];
      case 'message_delta':
        final usage = decoded['usage'];
        if (usage is Map) {
          _inputTokens = (usage['input_tokens'] as num?)?.toInt() ?? _inputTokens;
          _outputTokens =
              (usage['output_tokens'] as num?)?.toInt() ?? _outputTokens;
        }
        return const [];
      case 'message_stop':
        return [...(_callOpened ? _closeCall() : const []), ...(_textOpened ? _closeText() : const []), _completed()];
      case 'error':
        final error = decoded['error'];
        return [
          _event('response.failed', {
            'response': {
              'id': _id,
              'error': {
                'code': 'upstream_error',
                'message': error is Map ? error['message'] ?? 'failed' : '$error',
              },
            },
          }),
        ];
    }
    return const [];
  }

  /// The events that end the message when the upstream's stream ended
  /// without saying so.
  List<String> finish() {
    final events = <String>[];
    if (_callOpened) events.addAll(_closeCall());
    if (_textOpened) events.addAll(_closeText());
    if (_opened) events.add(_completed());
    return events;
  }

  List<String> _openCall(String callId, String name) {
    if (!_opened) {
      _opened = true;
    }
    _callOpened = true;
    _callId = callId;
    _callName = name;
    final item = {
      'type': 'function_call',
      'id': 'fc_${DateTime.now().microsecondsSinceEpoch}',
      'call_id': callId,
      'name': name,
      'arguments': '',
      'status': 'in_progress',
    };
    return [
      _event('response.output_item.added', {
        'output_index': _outputIndex++,
        'item': item,
      }),
    ];
  }

  List<String> _argumentsDelta(String delta) {
    if (delta.isEmpty) return const [];
    _callArguments.write(delta);
    return [
      _event('response.function_call_arguments.delta', {
        'item_id': 'fc_${_outputIndex - 1}',
        'delta': delta,
      }),
    ];
  }

  List<String> _closeCall() {
    _callOpened = false;
    return [
      _event('response.output_item.done', {
        'output_index': _outputIndex - 1,
        'item': {
          'type': 'function_call',
          'id': 'fc_${_outputIndex - 1}',
          'call_id': _callId,
          'name': _callName ?? '',
          'arguments': _callArguments.toString(),
          'status': 'completed',
        },
      }),
    ];
  }

  List<String> _textDelta(String delta) {
    final events = <String>[];
    if (!_textOpened) {
      _textOpened = true;
      if (!_opened) _opened = true;
      events.add(
        _event('response.output_item.added', {
          'output_index': _outputIndex++,
          'item': {
            'type': 'message',
            'role': 'assistant',
            'id': 'msg_${DateTime.now().microsecondsSinceEpoch}',
            'status': 'in_progress',
            'content': <Object?>[],
          },
        }),
      );
    }
    _text.write(delta);
    events.add(
      _event('response.output_text.delta', {
        'item_id': 'msg_${_outputIndex - 1}',
        'delta': delta,
      }),
    );
    return events;
  }

  List<String> _closeText() {
    _textOpened = false;
    return [
      _event('response.output_item.done', {
        'output_index': _outputIndex - 1,
        'item': {
          'type': 'message',
          'role': 'assistant',
          'id': 'msg_${_outputIndex - 1}',
          'status': 'completed',
          'content': [
            {'type': 'output_text', 'text': _text.toString()},
          ],
        },
      }),
    ];
  }

  String _completed() {
    return _event('response.completed', {
      'response': {
        'id': _id,
        'usage': {
          'input_tokens': _inputTokens,
          'output_tokens': _outputTokens,
          'total_tokens': _inputTokens + _outputTokens,
        },
        'output': <Object?>[],
      },
    });
  }

  String _responseBody() => jsonEncode({
    'response': {
      'id': _id,
      'status': 'in_progress',
      'output': <Object?>[],
    },
  });

  String _event(String event, Object? data) =>
      'event: $event\ndata: ${data is String ? data : jsonEncode(data)}\n\n';
}
