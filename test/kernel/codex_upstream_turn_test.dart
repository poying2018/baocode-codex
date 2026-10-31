import 'package:flutter_test/flutter_test.dart';

import 'package:baocode/kernel/agent_kernel.dart';
import 'package:baocode/kernel/kernel_types.dart';
import 'package:baocode/kernel/codex/codex_kernel.dart';
import 'package:baocode/kernel/codex/mock_codex_transport.dart';
import 'package:baocode/kernel/mock/mock_kernels.dart';
import 'package:baocode/models/model_provider.dart';
import 'package:baocode/models/model_providers.dart';

void main() {
  test('a first turn on one of the users own upstreams does not crash', () async {
    final providers = ModelProviders.memory(
      providers: const [
        ModelProvider(
          id: 'deepseek',
          name: 'DeepSeek',
          baseUrl: 'https://api.deepseek.com',
          models: [ProviderModel(id: 'deepseek-chat')],
        ),
      ],
    );
    CodexKernel.allowTransportSwap = false;
    addTearDown(() => CodexKernel.allowTransportSwap = true);
    final was = ModelProviders.current;
    ModelProviders.current = providers;
    addTearDown(() => ModelProviders.current = was);
    final mock = MockCodexTransport();

    final kernel = CodexKernel(
      MockKernels.codex,
      mock,
      context: KernelContext(
        settings: {KernelChoiceKind.model.name: '@deepseek/deepseek-chat'},
      ),
    );
    addTearDown(kernel.closeEvents);
    kernel.send(const KernelTurn(id: 't1', text: 'hello'));
    await Future<void>.delayed(const Duration(seconds: 1));
    expect(kernel.health.status, isNot(KernelHealthStatus.failed),
        reason: 'the upstream switch must not break the kernel');
    // The turn asks for the model as the upstream serves it, not by the
    // app's reference for the pick: the server has no metadata for the
    // reference, and refuses the turn over it.
    expect(mock.modelsAsked.last, 'deepseek-chat');
  });
}
