import 'package:flutter_test/flutter_test.dart';

import 'package:baocode/models/proxy/translate/codex_responses_request.dart';

void main() {
  test('a Responses request becomes Claude messages', () {
    final claude = convertResponsesRequestToClaude('qoder-cn/dfmodel', {
      'model': 'qoder-cn/dfmodel',
      'instructions': 'You are a coding agent.',
      'input': [
        {
          'type': 'message',
          'role': 'user',
          'content': [
            {'type': 'input_text', 'text': 'list the files'},
          ],
        },
        {
          'type': 'function_call',
          'call_id': 'call_1',
          'name': 'shell',
          'arguments': '{"command":["ls"]}',
        },
        {
          'type': 'function_call_output',
          'call_id': 'call_1',
          'output': 'a.dart\nb.dart',
        },
      ],
      'tools': [
        {
          'type': 'function',
          'name': 'shell',
          'description': 'Run a command',
          'parameters': {
            'type': 'object',
            'properties': {
              'command': {'type': 'array'},
            },
          },
        },
      ],
    });
    expect(claude['model'], 'qoder-cn/dfmodel');
    expect(claude['system'], [
      {'type': 'text', 'text': 'You are a coding agent.'},
    ]);
    final messages = claude['messages'] as List;
    expect(messages, hasLength(3));
    expect((messages[0] as Map)['role'], 'user');
    expect((messages[1] as Map)['role'], 'assistant');
    final toolUse = ((messages[1] as Map)['content'] as List).first as Map;
    expect(toolUse['type'], 'tool_use');
    expect(toolUse['name'], 'shell');
    expect((messages[2] as Map)['role'], 'user');
    final toolResult = ((messages[2] as Map)['content'] as List).first as Map;
    expect(toolResult['type'], 'tool_result');
    expect(toolResult['tool_use_id'], 'call_1');
    expect(toolResult['content'], 'a.dart\nb.dart');
    final tools = claude['tools'] as List;
    expect((tools.first as Map)['name'], 'shell');
    expect((tools.first as Map)['input_schema'], isA<Map>());
  });

  test('reasoning effort becomes a thinking budget', () {
    final claude = convertResponsesRequestToClaude('m', {
      'model': 'm',
      'reasoning': {'effort': 'high'},
    });
    expect((claude['thinking'] as Map)['budget_tokens'], 16384);
  });
}
