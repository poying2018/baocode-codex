import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:baocode/kernel/agent_kernel.dart';
import 'package:baocode/kernel/codex/codex_kernel.dart';
import 'package:baocode/kernel/codex/codex_transport.dart';
import 'package:baocode/kernel/kernel_event.dart';
import 'package:baocode/kernel/kernel_types.dart';
import 'package:baocode/kernel/codex/mock_codex_transport.dart';
import 'package:baocode/kernel/mock/mock_kernels.dart';

/// A transport that answers nothing: the kernel is not asked to work.
class _SilentTransport implements CodexTransport {
  @override
  Stream<Map<String, Object?>> get messages => const Stream.empty();

  @override
  void write(Map<String, Object?> message) {}

  @override
  Future<Map<String, Object?>> request(
    String method, [
    Map<String, Object?> params = const {},
  ]) => Future.value(const {});

  @override
  Future<void> get exited => Completer<void>().future;

  @override
  List<String> get stderr => const [];

  @override
  void restart() {}

  @override
  void close() {}
}

/// The kernel's own state, and when it says so.
void main() {
  test('a project folder that is gone is said after the view is built', () async {
    final folder = '${Directory.systemTemp.path}\\baocode-codex-gone';
    final kernel = CodexKernel(
      const KernelDescriptor(
        id: 'codex',
        label: 'Codex',
        icon: Icons.code,
        description: 'Codex',
        create: _never,
      ),
      _SilentTransport(),
      context: KernelContext(cwd: folder),
    );
    addTearDown(kernel.closeEvents);
    final told = <KernelEvent>[];
    kernel.events.listen(told.add);

    // A view attaches while it is being built: saying the folder is gone
    // now would make the workspace notify its listeners during that
    // build, and the framework would have none of it.
    kernel.prepare();
    expect(told.whereType<KernelInfoChanged>(), isEmpty);
    expect(kernel.health.status, KernelHealthStatus.failed);

    await Future<void>.delayed(Duration.zero);
    expect(told.whereType<KernelInfoChanged>(), isNotEmpty);
  });

  group('the models', () {
    _models(
      (context) => CodexKernel(
        MockKernels.codex,
        MockCodexTransport(),
        context: context,
      ),
    );
  });
}

AgentKernel _never(KernelContext context) => throw UnimplementedError();

/// The models: the software picks one, the server lists what it has.
void _models(CodexKernel Function(KernelContext) make) {
  test('the model the software picked is what is in effect', () async {
    final kernel = make(
      KernelContext(
        settings: {KernelChoiceKind.model.name: 'gpt-5.5'},
      ),
    );
    addTearDown(kernel.closeEvents);
    expect(kernel.model.selected, 'gpt-5.5');
  });

  test('what the server lists is what the picker offers', () async {
    final kernel = make(const KernelContext());
    addTearDown(kernel.closeEvents);
    // Asked for as the kernel is made, so the picker is right before the
    // first message starts the server.
    await _settled();
    expect(kernel.model.options.map((option) => option.id), [
      'gpt-6.1-sol',
      'gpt-5.5',
    ]);
    expect(kernel.model.selected, 'gpt-6.1-sol');
  });

  test('the software\'s pick stands once the server has listed', () async {
    final kernel = make(
      KernelContext(
        settings: {KernelChoiceKind.model.name: 'gpt-5.5'},
      ),
    );
    addTearDown(kernel.closeEvents);
    await _settled();
    expect(kernel.model.selected, 'gpt-5.5');
  });

  test('a pick the server does not list still shows, and stands', () async {
    final kernel = make(
      KernelContext(
        settings: {KernelChoiceKind.model.name: 'gpt-9-experimental'},
      ),
    );
    addTearDown(kernel.closeEvents);
    await _settled();
    expect(
      kernel.model.options.map((option) => option.id),
      contains('gpt-9-experimental'),
    );
    expect(kernel.model.selected, 'gpt-9-experimental');
  });

  test('picking another makes it the one in effect', () async {
    final kernel = make(const KernelContext());
    addTearDown(kernel.closeEvents);
    await _settled();
    kernel.model.select('gpt-5.5');
    expect(kernel.model.selected, 'gpt-5.5');
    expect(kernel.model.options.map((option) => option.id), contains('gpt-5.5'));
  });
}

/// Long enough for the server's answer to be in.
Future<void> _settled() =>
    Future<void>.delayed(const Duration(milliseconds: 50));
