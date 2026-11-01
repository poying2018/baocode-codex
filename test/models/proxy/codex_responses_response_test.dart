import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:baocode/models/proxy/translate/codex_responses_response.dart';

void main() {
  test('a text reply comes out as the Responses events a server reads', () {
    final builder = CodexResponseBuilder();
    final events = [
      ...builder.convert(
        'data: ${jsonEncode({
          'type': 'message_start',
          'message': {'id': 'msg_1', 'model': 'm'},
        })}',
      ),
      ...builder.convert(
        'data: ${jsonEncode({
          'type': 'content_block_start',
          'index': 0,
          'content_block': {'type': 'text', 'text': ''},
        })}',
      ),
      ...builder.convert(
        'data: ${jsonEncode({
          'type': 'content_block_delta',
          'index': 0,
          'delta': {'type': 'text_delta', 'text': 'hello'},
        })}',
      ),
      ...builder.convert(
        'data: ${jsonEncode({
          'type': 'message_delta',
          'delta': {},
          'usage': {'input_tokens': 10, 'output_tokens': 2},
        })}',
      ),
      ...builder.convert(
        'data: ${jsonEncode({'type': 'message_stop'})}',
      ),
    ].join();
    expect(events, contains('event: response.created'));
    expect(events, contains('event: response.output_item.added'));
    expect(events, contains('event: response.output_text.delta'));
    expect(events, contains('"delta":"hello"'));
    expect(events, contains('event: response.output_item.done'));
    expect(events, contains('event: response.completed'));
    expect(events, contains('"input_tokens":10'));
    expect(events, contains('"output_tokens":2'));
  });

  test('a function call comes out whole, its arguments carried', () {
    final builder = CodexResponseBuilder();
    final events = [
      ...builder.convert(
        'data: ${jsonEncode({
          'type': 'content_block_start',
          'index': 0,
          'content_block': {
            'type': 'tool_use',
            'id': 'call_1',
            'name': 'shell',
          },
        })}',
      ),
      ...builder.convert(
        'data: ${jsonEncode({
          'type': 'content_block_delta',
          'index': 0,
          'delta': {
            'type': 'input_json_delta',
            'partial_json': '{"command":["ls"]}',
          },
        })}',
      ),
      ...builder.convert(
        'data: ${jsonEncode({'type': 'content_block_stop', 'index': 0})}',
      ),
    ].join();
    expect(events, contains('event: response.output_item.added'));
    expect(events, contains('"name":"shell"'));
    expect(
      events,
      contains('event: response.function_call_arguments.delta'),
    );
    // The delta rides inside a JSON-encoded event, its quotes escaped.
    expect(events, contains(r'\"command\":[\"ls\"]'));
    expect(events, contains('event: response.output_item.done'));
  });

  test('a stream that ends without saying so is finished whole', () {
    final builder = CodexResponseBuilder();
    builder.convert(
      'data: ${jsonEncode({
        'type': 'content_block_start',
        'index': 0,
        'content_block': {'type': 'text', 'text': ''},
      })}',
    );
    builder.convert(
      'data: ${jsonEncode({
        'type': 'content_block_delta',
        'index': 0,
        'delta': {'type': 'text_delta', 'text': 'partial'},
      })}',
    );
    final events = builder.finish().join();
    expect(events, contains('event: response.output_item.done'));
    expect(events, contains('event: response.completed'));
  });
}
