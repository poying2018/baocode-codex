import 'package:flutter_test/flutter_test.dart';

import 'package:baocode/kernel/codex/codex_transport.dart';
import 'package:baocode/kernel/codex/codex_transport_factory.dart';
import 'package:baocode/kernel/codex/codex_upstream.dart';
import 'package:baocode/models/model_provider.dart';
import 'package:baocode/models/model_providers.dart';

void main() {
  test('the upstream becomes --config overrides Codex reads', () {
    final provider = const ModelProvider(
      id: 'deepseek',
      name: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com',
      models: [ProviderModel(id: 'deepseek-chat')],
    );
    final upstream = CodexUpstream(
      provider: provider,
      model: provider.models.first,
      baseUrl: 'http://127.0.0.1:1234/p/deepseek',
      token: 'proxy-token',
    );
    final launch = launchOn(const CodexLaunch(cwd: r'F:\Projects'), upstream);

    expect(launch.model, 'deepseek-chat');
    expect(launch.arguments, contains('--model'));
    expect(launch.arguments, contains('deepseek-chat'));
    // The endpoint, its key's variable and the wire protocol, each a
    // `--config` Codex reads over its own file.
    final configs = <String>[];
    for (var i = 0; i < launch.arguments.length; i++) {
      if (launch.arguments[i] == '--config') configs.add(launch.arguments[i + 1]);
    }
    expect(
      configs,
      contains('model_providers.deepseek.base_url="http://127.0.0.1:1234/p/deepseek"'),
    );
    expect(
      configs,
      contains('model_providers.deepseek.env_key="BAOCODE_CODEX_KEY_DEEPSEEK"'),
    );
    expect(configs, contains('model_providers.deepseek.wire_api="responses"'));
    expect(configs, contains('model_provider="deepseek"'));
    expect(launch.environment, {'BAOCODE_CODEX_KEY_DEEPSEEK': 'proxy-token'});
  });

  test('no upstream: the server is started as it was', () {
    final launch = launchOn(const CodexLaunch(cwd: r'F:\Projects'), null);
    expect(launch.arguments, ['app-server', '--stdio']);
    expect(launch.model, isNull);
  });

  test('a model of the user\'s is found by its ref, OpenAI\'s is not', () async {
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
    final mine = await codexUpstreamOf(
      providers,
      '@deepseek/deepseek-chat',
      endpoint: (id) async => (
        baseUrl: 'http://127.0.0.1:1/p/$id',
        token: 't',
      ),
    );
    expect(mine?.modelId, 'deepseek-chat');
    expect(mine?.id, 'deepseek');
    final openai = await codexUpstreamOf(
      providers,
      'gpt-6.1-sol',
      endpoint: (id) async => (baseUrl: '', token: ''),
    );
    expect(openai, isNull);
  });

  test('two upstreams keep homes apart, none inside the main one', () {
    // 1.7.5's invariant: the two servers never share a state folder - the
    // databases of one are locked while either runs.
    const home = r'C:\Users\me\AppData\Roaming\baocode-codex\codex';
    final alpha = upstreamHomeFor(home, 'alpha');
    final beta = upstreamHomeFor(home, 'beta');
    expect(alpha, isNot(beta));
    expect(alpha, isNot(home));
    expect(beta, isNot(home));
    expect(alpha, contains('alpha'));
    expect(beta, contains('beta'));
    expect(upstreamHomeFor(home, null), home,
        reason: 'the default model keeps the main folder');
  });
}