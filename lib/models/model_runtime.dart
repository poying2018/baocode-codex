// What the providers need of the machine: asking an upstream for its
// models, the local proxy, and the environment a session on a provider
// starts with. None of it on the web.

import 'codex/codex_service.dart';
import 'image_api.dart';
import 'launch_environment.dart' show ProxyEndpoint;
import 'model_provider.dart';
import 'model_runtime_stub.dart'
    if (dart.library.io) 'model_runtime_io.dart'
    as platform;
import 'upstream.dart';

/// [provider]'s models, as it lists them (`GET /v1/models`), asked with
/// [key]. Throws [UpstreamException].
Future<List<RemoteModel>> listUpstreamModels(
  ModelProvider provider,
  String? key,
) => platform.listUpstreamModels(provider, key);

/// The environment (Claude Code's `--settings` `env`) for a session on
/// [provider] that asks for [model] ([requestedModel]): the proxy started
/// for it, if it needs one, and its key read.
Future<Map<String, String>> providerLaunchEnvironment(
  ModelProvider provider,
  String model,
) => platform.providerLaunchEnvironment(provider, model);

/// Where the app's proxy takes [providerId]'s requests, and the token it
/// asks for: what a session on that upstream is pointed at (Codex, which
/// speaks one protocol, is pointed at the proxy for any other).
Future<ProxyEndpoint> proxyEndpoint(String providerId) =>
    platform.proxyEndpoint(providerId);

/// [request]'s pictures, made by [model] (an image model) of [provider]:
/// the bytes of each (fetched where it answered with a link). Throws
/// [UpstreamException].
Future<List<GeneratedImage>> generateImages(
  ModelProvider provider,
  ProviderModel model,
  ImageRequest request, {
  String? session,
}) => platform.generateImages(provider, model, request, session: session);

/// The ChatGPT (Codex) providers' accounts: signing in, their quota.
CodexService get codexService => platform.codexService;

/// Stops the local proxy, as the app quits.
Future<void> stopModelProxy() => platform.stopModelProxy();

class UpstreamException implements Exception {
  const UpstreamException(this.message);

  final String message;

  @override
  String toString() => message;
}
