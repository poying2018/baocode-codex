import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:baocode/kernel/agent_kernel.dart';
import 'package:baocode/kernel/kernel_types.dart';
import 'package:baocode/kernel/codex/codex_kernel.dart';
import 'package:baocode/kernel/codex/codex_transport.dart';
import 'package:baocode/kernel/mock/mock_kernels.dart';

/// A transport that answers everything and remembers the methods asked, so
/// the test can say what the kernel speaks.
class _RecordingTransport implements CodexTransport {
  final methods = <String>[];
  final _answers = <String, Map<String, Object?>>{
    'model/list': {
      'data': [
        {
          'id': 'gpt-6.1-sol',
          'displayName': 'GPT-6.1-Sol',
          'description': '',
          'defaultReasoningEffort': 'medium',
          'isDefault': true,
          'inputModalities': ['text'],
          'supportedReasoningEfforts': [
            {'reasoningEffort': 'medium', 'description': ''},
          ],
          'serviceTiers': <Object?>[],
        },
      ],
      'nextCursor': null,
    },
    'thread/start': {'thread': {'id': 'thr_1'}},
    'thread/resume': {'thread': {'id': 'thr_1'}},
    'thread/turns/list': {'data': <Object?>[], 'nextCursor': null},
    'turn/interrupt': {},
    'thread/fork': {'thread': {'id': 'thr_2'}, 'rootTurnId': 't0'},
    'thread/name/set': {},
    'thread/revert': {},
    'account/rateLimits/read': {'rate_limits': <Object?>[]},
    'config/mcpServer/reload': {},
    'config/value/write': {},
    'mcpServerStatus/list': {'data': <Object?>[]},
    'mcpServer/oauth/login': {},
    'fuzzyFileSearch': {'matches': <Object?>[]},
    'thread/delete': {},
  };

  @override
  Stream<Map<String, Object?>> get messages => const Stream.empty();

  @override
  void write(Map<String, Object?> message) {}

  @override
  Future<Map<String, Object?>> request(
    String method, [
    Map<String, Object?> params = const {},
  ]) {
    methods.add(method);
    return Future.value(_answers[method] ?? const {});
  }

  @override
  Future<void> get exited => Completer<void>().future;

  @override
  List<String> get stderr => const [];

  @override
  void restart() {}

  @override
  void close() {}
}

/// The protocol the kernel speaks, said as a list: when the server changes a
/// name, this is the list to check the new schema against, and when a method
/// goes away, this is where the break is named.
void main() {
  test('the methods the kernel asks the server for', () async {
    final transport = _RecordingTransport();
    final kernel = CodexKernel(
      MockKernels.codex,
      transport,
      context: KernelContext(cwd: Directory.current.path),
    );
    addTearDown(kernel.closeEvents);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // A turn goes out, which is what carries the rest of the methods: the
    // model list is asked as the kernel is made, the rest as it works.
    kernel.send(const KernelTurn(id: 't1', text: 'hello'));
    await Future<void>.delayed(const Duration(seconds: 1));

    // The list said out loud: not derived, so a change is a change here too.
    // What a first turn asks: the models as it is made, then the thread and
    // its turn. (An opened conversation asks thread/resume first; the ones
    // for renaming, forking, reverting and the rest go out when used.)
    expect(
      transport.methods.toSet(),
      containsAll(const ['model/list', 'turn/start']),
    );
    expect(transport.methods, contains('turn/start'));
    // ignore: avoid_print
    print('the kernel asked: ${transport.methods.toSet().toList()..sort()}');
  });

  test('every method literal in the kernel is one 0.166 knows', () {
    // The kernel's own literals, read from the source: what it says, not
    // what a test drove it to say. Against the frozen list of what 0.166's
    // ClientRequest accepts - the requests, that is; the notifications the
    // kernel listens for are checked against the fixture of those.
    final source = [
      File('lib/kernel/codex/codex_kernel.dart').readAsStringSync(),
      File('lib/kernel/codex/codex_catalog.dart').readAsStringSync(),
    ].join();
    final literals = RegExp(
      "'((thread|turn|model|account|config|mcpServer|mcpServerStatus|review|fuzzyFileSearch)/[A-Za-z0-9/]+)'",
    )
        .allMatches(source)
        .map((m) => m.group(1)!)
        .toSet();

    const clientRequests = [
      'account/chatgptAuthTokens/refresh',
      'account/rateLimits/read',
      'config/mcpServer/reload',
      'config/value/write',
      'fuzzyFileSearch',
      'mcpServer/oauth/login',
      'mcpServerStatus/list',
      'model/list',
      'review/start',
      'thread/compact/start',
      'thread/delete',
      'thread/fork',
      'thread/list',
      'thread/name/set',
      'thread/resume',
      'thread/revert',
      'thread/start',
      'thread/turns/list',
      'turn/interrupt',
      'turn/start',
    ];
    const notifications = [
      'account/chatgptAuthTokens/refresh',
      'account/rateLimits/updated',
      'config/mcpServer/reload',
      'mcpServer/elicitation/request',
      'mcpServer/oauth/login',
      'mcpServer/startupStatus/updated',
      // The older names the kernel keeps accepting beside these: a server on
      // 0.164's CLI still says them (0.166 renamed both).
      'mcpServerStatus/updated',
      'thread/closed',
      'mcpServerStatus/list',
      'model/list',
      'review/start',
      'thread/compact/start',
      'thread/delete',
      'thread/deleted',
      'thread/fork',
      'thread/goal/cleared',
      'thread/goal/updated',
      'thread/list',
      'thread/name/set',
      'thread/name/updated',
      'thread/prediction/updated',
      'thread/resume',
      'thread/revert',
      'thread/settings/updated',
      'thread/start',
      'thread/tokenUsage/updated',
      'thread/turns/list',
      'turn/completed',
      'turn/interrupt',
      'turn/plan/updated',
      'turn/start',
      'turn/started',
    ];
    final unknown = literals
        .where((m) => !clientRequests.contains(m) && !notifications.contains(m))
        .toList();
    expect(unknown, isEmpty,
        reason: 'methods 0.166 does not know: $unknown');
  });
}