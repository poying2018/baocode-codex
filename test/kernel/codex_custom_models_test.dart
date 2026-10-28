import 'package:flutter_test/flutter_test.dart';

import 'package:baocode/kernel/agent_kernel.dart';
import 'package:baocode/kernel/codex/codex_kernel.dart';
import 'package:baocode/kernel/codex/mock_codex_transport.dart';
import 'package:baocode/kernel/mock/mock_kernels.dart';
import 'package:baocode/models/model_provider.dart';
import 'package:baocode/models/model_providers.dart';

void main() {
  test('the models configured in Settings show in the picker', () async {
    // Three of the user's own, as Settings → Models keeps them.
    final providers = ModelProviders.memory(
      providers: const [
        ModelProvider(
          id: 'deepseek',
          name: 'DeepSeek',
          baseUrl: 'https://api.deepseek.com',
          models: [
            ProviderModel(id: 'deepseek-chat'),
            ProviderModel(id: 'deepseek-reasoner'),
          ],
        ),
        ModelProvider(
          id: 'kimi',
          name: 'Kimi',
          baseUrl: 'https://api.moonshot.cn',
          models: [ProviderModel(id: 'kimi-k2')],
        ),
      ],
    );
    final was = ModelProviders.current;
    ModelProviders.current = providers;
    addTearDown(() => ModelProviders.current = was);

    final kernel = CodexKernel(
      MockKernels.codex,
      MockCodexTransport(),
      context: const KernelContext(),
    );
    addTearDown(kernel.closeEvents);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final ids = kernel.model.options.map((option) => option.id).toList();
    expect(ids, contains('@deepseek/deepseek-chat'));
    expect(ids, contains('@deepseek/deepseek-reasoner'));
    expect(ids, contains('@kimi/kimi-k2'));
    // The server's own models are still there, first.
    expect(ids.first, 'gpt-6.1-sol');
  });
}
