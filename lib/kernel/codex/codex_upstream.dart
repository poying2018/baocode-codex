import '../../models/launch_environment.dart' show ProxyEndpoint;
import '../../models/model_provider.dart';
import '../../models/model_providers.dart';
import 'codex_transport.dart';

/// An upstream of the user's own (Settings → Models), as Codex is told
/// about it.
///
/// Codex has no notion of another upstream while it runs: its server lists
/// the models OpenAI serves, and nothing else. One of the user's is given at
/// start instead — `model_providers.<id>` through `--config`, its key
/// through an environment variable — and picking another one of them is a
/// restart on it, as picking another of Claude Code's providers is.
///
/// The endpoint is the app's own proxy ([ModelProxy]), which answers Codex
/// in the one protocol it speaks (OpenAI's Responses) and translates for
/// the upstream: that is what makes an upstream of any protocol usable.
class CodexUpstream {
  const CodexUpstream({
    required this.provider,
    required this.model,
    required this.baseUrl,
    required this.token,
  });

  final ModelProvider provider;
  final ProviderModel model;

  /// Where Codex sends its requests: the proxy, which knows the upstream.
  final String baseUrl;

  /// The proxy's own token, which is not the upstream's key.
  final String token;

  /// The name Codex knows the provider by: its id, made safe for a
  /// configuration key (letters, digits, `-`, `_`).
  String get id => provider.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

  /// The environment variable its token travels in: Codex reads the key from
  /// the environment, never from the configuration.
  String get keyVariable =>
      'BAOCODE_CODEX_KEY_${id.toUpperCase().replaceAll('-', '_')}';

  /// The model as Codex asks for it.
  String get modelId => model.id;

  /// What the `--config` overrides are, by key.
  Map<String, String> get overrides {
    final prefix = 'model_providers.$id';
    return {
      '$prefix.name': _tomlString(
        provider.name.isEmpty ? provider.id : provider.name,
      ),
      '$prefix.base_url': _tomlString(baseUrl),
      '$prefix.env_key': _tomlString(keyVariable),
      // The proxy answers OpenAI's Responses, whatever the upstream speaks.
      '$prefix.wire_api': _tomlString('responses'),
      // The provider serves its own models; Codex asks for them by name.
      'model_provider': _tomlString(id),
    };
  }

  /// The environment its token goes in.
  Map<String, String> get environment => {keyVariable: token};

  /// [value] as a TOML string, quoted and escaped.
  static String _tomlString(String value) {
    final escaped = value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
    return '"$escaped"';
  }
}

/// The upstream [ref] picks, if it is one of the user's
/// (`@<provider>/<model>`): null for the server's own models.
///
/// The proxy's endpoint is asked for here, which starts it: only a
/// provider with a base URL has one.
Future<CodexUpstream?> codexUpstreamOf(
  ModelProviders providers,
  String? ref, {
  required Future<ProxyEndpoint> Function(String providerId) endpoint,
}) async {
  final resolved = providers.resolve(ref);
  if (resolved == null) return null;
  final (provider, model) = resolved;
  if (provider.baseUrl.isEmpty) return null;
  if (!provider.enabled) return null;
  final at = await endpoint(provider.id);
  return CodexUpstream(
    provider: provider,
    model: model,
    baseUrl: at.baseUrl,
    token: at.token,
  );
}

/// What [launch] is, with [upstream] as the server it runs on.
CodexLaunch launchOn(CodexLaunch launch, CodexUpstream? upstream) {
  if (upstream == null) return launch;
  return CodexLaunch(
    cwd: launch.cwd,
    model: upstream.modelId,
    environment: {...?launch.environment, ...upstream.environment},
    home: launch.home,
    overrides: {...launch.overrides, ...upstream.overrides},
  );
}
