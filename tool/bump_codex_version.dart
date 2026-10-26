// Keeps the Codex CLI the Windows bundle carries current: the version and
// the checksum of the package it is, pinned in tool/build_windows.dart so
// that a build carries that one build and no other.
//
// The bundle carries the Codex CLI itself, so that a machine with none of
// its own needs no install and no download. That copy cannot update itself
// (the app runs it from where it is, read-only, under Program Files), so
// the pin is what a release carries: this is what keeps the pin at the
// current build.
//
//   dart tool/bump_codex_version.dart            say what stands, and whether
//                                                it is behind the registry
//                                                (exit 1 when it is)
//   dart tool/bump_codex_version.dart --write    put the current one in
//
// The channel is npm's registry, where OpenAI's CLI is published per
// platform (`@openai/codex`, the platform's build as the version with the
// platform in it — `0.164.0-win32-x64`). Its `dist.integrity` is the
// checksum the pin holds, so nothing has to be downloaded to know it: the
// build downloads the package, and checks it against the pin.
//
// BAOCODE_CODEX_REGISTRY says another registry to read from, for a test.
import 'dart:convert';
import 'dart:io';

/// Where the packages are.
const _defaultRegistry = 'https://registry.npmjs.org';

/// The environment variable that says another registry to read from.
const _registryVariable = 'BAOCODE_CODEX_REGISTRY';

/// The package's name, as the registry knows it.
const _package = '@openai/codex';

/// The build the Windows bundle carries.
const _platform = 'win32-x64';

/// The file the pin is in.
const _pinFile = 'tool/build_windows.dart';

/// The name of the pinned version's constant.
const _versionConstant = '_codexVersion';

/// The name of the pinned checksum's constant.
const _integrityConstant = '_codexIntegrity';

Future<void> main(List<String> arguments) async {
  final write = arguments.contains('--write');
  final root = File.fromUri(Platform.script).parent.parent.absolute.path;
  final file = File('$root/$_pinFile');
  if (!file.existsSync()) {
    stderr.writeln('No $_pinFile in $root: run it from the repository.');
    exit(2);
  }
  final text = file.readAsStringSync();
  final pinned = pinnedFrom(text);
  if (pinned == null) {
    stderr.writeln('No $_versionConstant in $_pinFile: the pin is not there.');
    exit(2);
  }
  stdout.writeln('Codex carried: ${pinned.version}');

  final latest = await _current();
  if (latest == null) {
    // The registry could not be read: not a reason to fail, only to say so.
    // The pin stands, and a release carries it as it is.
    stderr.writeln('The registry could not be read: not checked.');
    exit(0);
  }
  stdout.writeln('Codex current: $latest');
  if (latest == pinned.version) {
    stdout.writeln('It is the current one.');
    exit(0);
  }
  if (compareVersions(latest, pinned.version) < 0) {
    // The pin is ahead of the registry (a build of their own, or a
    // version pulled early): not behind it.
    stdout.writeln('The pin is ahead of the registry: not behind it.');
    exit(0);
  }

  final integrity = await _integrity(latest);
  if (integrity == null) {
    stderr.writeln('No ${platformVersion(latest)} in the registry.');
    exit(2);
  }
  stdout.writeln('It is out: $latest.');
  stdout.writeln("  const $_versionConstant = '$latest';");
  stdout.writeln("  const $_integrityConstant =");
  stdout.writeln("      '$integrity';");
  if (!write) {
    stderr.writeln('Not written: run it with --write.');
    exit(1);
  }
  file.writeAsStringSync(writtenWithPin(text, latest, integrity));
  stdout.writeln('Written to $_pinFile.');
}

/// The version the pin holds, and the checksum beside it; null when the
/// text has no version in it.
({String version, String? integrity})? pinnedFrom(String text) {
  final version = RegExp(
    "const $_versionConstant = '([^']*)';",
  ).firstMatch(text)?.group(1);
  if (version == null) return null;
  final integrity = RegExp(
    "const $_integrityConstant =\\s*'([^']*)';",
  ).firstMatch(text)?.group(1);
  return (version: version, integrity: integrity);
}

/// [text] with the pin at [version] and [checksum]. The checksum is written
/// the way `dart format` writes it: on a line of its own, as the line it is
/// on would be too long for one.
String writtenWithPin(String text, String version, String checksum) => text
    .replaceAll(
      RegExp("const $_versionConstant = '[^']*';"),
      "const $_versionConstant = '$version';",
    )
    .replaceAll(
      RegExp("const $_integrityConstant =\\s*'[^']*';"),
      "const $_integrityConstant =\n      '$checksum';",
    );

/// The version the registry is at; null when it could not be read.
Future<String?> _current() async {
  final json = await _json('$_registry/$_packagePath/latest');
  final version = json?['version'];
  if (version is! String || version.isEmpty) return null;
  if (!RegExp(r'^\d+\.\d+\.\d+[A-Za-z0-9.+-]*$').hasMatch(version)) return null;
  return version;
}

/// The checksum the registry gives the [version]'s build for [_platform];
/// null when there is none.
Future<String?> _integrity(String version) async {
  final json = await _json(
    '$_registry/$_packagePath/${platformVersion(version)}',
  );
  final dist = json?['dist'];
  if (dist is! Map) return null;
  final integrity = dist['integrity'];
  if (integrity is! String) return null;
  if (!RegExp(r'^sha512-[A-Za-z0-9+/]+=*$').hasMatch(integrity)) return null;
  return integrity;
}

/// The package's name as a URL's path has it: its `/` written out.
String get _packagePath => _package.replaceAll('/', '%2F');

/// The version the platform's own package carries: npm publishes each build
/// under the same name with the platform in the version.
String platformVersion(String version) => '$version-$_platform';

/// Where the registry is.
String get _registry =>
    Platform.environment[_registryVariable]?.trim().isNotEmpty == true
    ? Platform.environment[_registryVariable]!.trim()
    : _defaultRegistry;

/// The JSON at [url]; null when it could not be read.
Future<Map<String, Object?>?> _json(String url) async {
  final text = await _get(url);
  if (text == null) return null;
  try {
    final json = jsonDecode(text);
    return json is Map ? json.cast<String, Object?>() : null;
  } on FormatException {
    return null;
  }
}

/// The text at [url]; null when it could not be read.
Future<String?> _get(String url) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url)).timeout(
      const Duration(seconds: 30),
    );
    final response = await request.close().timeout(const Duration(seconds: 30));
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      return null;
    }
    // Awaited here, not returned: a future returned from a try is awaited
    // outside it, and what it throws would not be caught here.
    return await response.transform(utf8.decoder).join();
  } on Object {
    return null;
  } finally {
    client.close(force: true);
  }
}

/// Two versions, compared number by number: the newer of the two is the
/// greater one.
int compareVersions(String a, String b) {
  final pa = _parts(a);
  final pb = _parts(b);
  for (var i = 0; i < 3; i++) {
    final c = pa[i].compareTo(pb[i]);
    if (c != 0) return c;
  }
  return 0;
}

/// The three numbers of a version; what it does not say is zero.
List<int> _parts(String version) {
  final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(version);
  return [
    for (var i = 1; i <= 3; i++) int.tryParse(match?.group(i) ?? '') ?? 0,
  ];
}
