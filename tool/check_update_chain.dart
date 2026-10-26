// Says whether the update chain is whole, from where an installed app stands:
// the manifest is reachable with no token, it is for this product, the
// download it names is on a host the app may fetch from, and the signature
// verifies against the key the app carries.
//
//   dart tool/check_update_chain.dart [--product <id>] [--version <x.y.z+b>]
//                                     [--url <manifest>] [--platform <key>]
//
// The product is baocode-codex (this repository's) unless said otherwise; the
// version is the one the code is at (lib/update/version.dart), and the
// platform windows-x64. Exit 0 when the chain is whole, 1 when it is not —
// with the reason said, so a release that publishes a broken chain is caught
// before anyone installs it.
//
// It reads the manifest the way the app does: anonymously, and with the app's
// own parser, URL policy and pinned public key.
import 'dart:convert';
import 'dart:io';

import 'package:baocode/update/update_manifest.dart';
import 'package:baocode/update/update_signature.dart';
import 'package:baocode/update/version.dart';

Future<void> main(List<String> arguments) async {
  final product = _option(arguments, '--product') ?? 'baocode-codex';
  final platform = _option(arguments, '--platform') ?? 'windows-x64';
  final version = AppVersion.parse(
    _option(arguments, '--version') ?? currentAppVersion.toString(),
  );
  final manifestUrl = Uri.parse(
    _option(arguments, '--url') ?? manifestUrlFor(product),
  );

  stdout.writeln('product:  $product (this app: $version)');
  stdout.writeln('platform: $platform');
  stdout.writeln('manifest: $manifestUrl');

  final (status, text) = await _get(manifestUrl);
  if (status != HttpStatus.ok) {
    _broken('the manifest answered $status — an installed app fetches it '
        'with no token, so a private repository (or a wrong URL) is a '
        'chain that does not work');
  }
  stdout.writeln('fetched:  ${utf8.encode(text).length} bytes, signed '
      'manifest is what it is');

  final UpdateManifest manifest;
  try {
    manifest = UpdateManifest.parse(text);
  } on UpdateManifestException catch (error) {
    _broken('the manifest does not parse: ${error.message}');
  }

  if (!manifest.isFor(product)) {
    _broken('the manifest is for "${manifest.product ?? 'baocode'}", not '
        '$product — the app would refuse it as another product\'s');
  }
  stdout.writeln('version:  ${manifest.version}');
  stdout.writeln('notes:    ${manifest.notes.keys.join(', ')}');

  final asset = manifest.assetFor(platform);
  if (asset == null) {
    _broken('no $platform in it — the app on that platform is offered '
        'nothing');
  }
  stdout.writeln('download: ${asset.url}');
  stdout.writeln('  size ${asset.size}, sha256 ${asset.sha256}');

  if (!UpdateUrlPolicy.forManifest(manifestUrl).allows(asset.url)) {
    _broken('the download is not on a host the app may fetch from');
  }
  final verified = UpdateSignature.verify(
    payload: UpdateSignature.payload(
      version: manifest.version.toString(),
      platform: platform,
      size: asset.size,
      sha256: asset.sha256,
    ),
    signature: asset.signature,
  );
  if (!verified) {
    _broken('the signature does not verify against the key the app carries '
        '($updatePublicKey) — the app would refuse this update');
  }
  stdout.writeln('signature: verifies ($updatePublicKey)');

  // What an installed app on this version would do with it.
  final newer = manifest.version.compareTo(version) > 0;
  stdout.writeln(
    newer
        ? 'an app at $version is offered ${manifest.version}'
        : 'an app at $version is offered nothing (this is that version, or '
              'a newer one)',
  );
  stdout.writeln('the chain is whole.');
}

/// [name]'s value, if it is given.
String? _option(List<String> arguments, String name) {
  final at = arguments.indexOf(name);
  if (at < 0 || at + 1 >= arguments.length) return null;
  return arguments[at + 1];
}

/// The text at [url], fetched as an installed app fetches it: no token, no
/// proxy of its own (the environment's proxy, if any, is the machine's).
Future<(int, String)> _get(Uri url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(url).timeout(
      const Duration(seconds: 30),
    );
    final response = await request.close().timeout(const Duration(seconds: 30));
    final body = await response.transform(utf8.decoder).join();
    return (response.statusCode, body);
  } on Object catch (error) {
    return (0, '$error');
  } finally {
    client.close(force: true);
  }
}

/// Says why the chain is broken, and stops with a failure.
Never _broken(String why) {
  stderr.writeln('BROKEN: $why');
  exit(1);
}
