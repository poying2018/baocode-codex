// Ported in part from CLIProxyAPI's Codex translation (MIT License; see
// NOTICE.md beside this file).

import 'dart:convert';

import 'json_value.dart';

/// Turns an OpenAI Responses request (what a Codex server sends) into
/// Claude's Messages shape, for [model]: the `input` items (messages,
/// function calls and their outputs, reasoning) become Claude's messages,
/// `instructions` becomes the system, and the function tools become
/// Claude's tools. Reasoning is not asked for: the model of the upstream
/// decides.
Map<String, Object?> convertResponsesRequestToClaude(
  String model,
  Object? request,
) {
  final root = JsonValue.of(request);
  final out = <String, Object?>{
    'model': model,
    'max_tokens': root.get('max_output_tokens').exists
        ? root.get('max_output_tokens').number
        : 8192,
    'stream': true,
  };

  // The instructions as the system, first.
  final system = <Map<String, Object?>>[];
  final instructions = root.get('instructions');
  if (instructions.isString && instructions.string.isNotEmpty) {
    system.add({'type': 'text', 'text': instructions.string});
  }

  final messages = <Map<String, Object?>>[];
  final input = root.get('input');
  if (input.isArray) {
    var pendingCallIds = <String>[];
    for (final item in input.array) {
      switch (item.get('type').string) {
        case 'message':
          final role = item.get('role').string == 'assistant'
              ? 'assistant'
              : 'user';
          final content = <Object?>[];
          for (final part in item.get('content').array) {
            switch (part.get('type').string) {
              case 'input_text':
              case 'output_text':
              case 'text':
                final text = part.get('text').string;
                if (text.isNotEmpty) content.add({'type': 'text', 'text': text});
              case 'input_image':
                final url = part.get('image_url').string;
                if (url.isNotEmpty) {
                  content.add({
                    'type': 'image',
                    'source': {'type': 'url', 'url': url},
                  });
                }
            }
          }
          if (content.isNotEmpty) {
            messages.add({'role': role, 'content': content});
          }
        case 'function_call':
          final name = item.get('name').string;
          if (name.isEmpty) continue;
          final callId = item.get('call_id').string;
          pendingCallIds.add(callId);
          final arguments = item.get('arguments').string;
          messages.add({
            'role': 'assistant',
            'content': [
              {
                'type': 'tool_use',
                'id': callId,
                'name': name,
                'input': arguments.isEmpty ? const {} : jsonDecode(arguments),
              },
            ],
          });
        case 'function_call_output':
          // The call that asked is answered: the ids are matched up. The
          // output is a string of the upstream's own making.
          messages.add({
            'role': 'user',
            'content': [
              {
                'type': 'tool_result',
                'tool_use_id': item.get('call_id').string,
                'content': item.get('output').string,
              },
            ],
          });
          if (pendingCallIds.isNotEmpty) pendingCallIds.removeAt(0);
        case 'reasoning':
          // Reasoning of an earlier turn is the upstream's own to replay;
          // the shape it comes back in is not carried over.
          continue;
      }
    }
  }

  if (system.isNotEmpty) out['system'] = system;
  out['messages'] = messages;

  // The function tools as Claude's, the names as they came: the upstream
  // sees the same the server asked for.
  final tools = root.get('tools');
  if (tools.isArray) {
    final claudeTools = <Object?>[];
    for (final tool in tools.array) {
      if (tool.get('type').string != 'function') continue;
      claudeTools.add({
        'name': tool.get('name').string,
        'description': tool.get('description').string,
        'input_schema': tool.get('parameters').exists
            ? jsonDecode(tool.get('parameters').raw)
            : {'type': 'object', 'properties': const {}},
      });
    }
    if (claudeTools.isNotEmpty) out['tools'] = claudeTools;
  }
  if (root.get('tool_choice').exists) {
    final choice = root.get('tool_choice');
    if (choice.isString) {
      out['tool_choice'] = switch (choice.string) {
        'auto' || 'none' => {'type': 'auto'},
        'required' => {'type': 'any'},
        final name => {'type': 'tool', 'name': name},
      };
    }
  }
  final effortText = root.get('reasoning').get('effort').string;
  if (effortText.isNotEmpty && effortText != 'none') {
    out['thinking'] = {
      'type': 'enabled',
      'budget_tokens': switch (effortText) {
        'low' => 2048,
        'high' => 16384,
        _ => 8192,
      },
    };
  }
  return out;
}
