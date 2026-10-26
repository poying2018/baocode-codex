import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/bump_codex_version.dart';

/// The pin the bundle carries: the version and the checksum of the Codex
/// CLI package it is, in tool/build_windows.dart. The Codex version
/// workflow keeps it at the current build; a pin that cannot be read, or
/// written wrongly, would ship an agent nobody asked for.
void main() {
  const integrity =
      'sha512-urWPhwh9YavuoAPIkmVYKBTtd5OtGVL4Ki0Fb28dhK/Mz6Pt4LSy+gbRrZFz5+RXrw9ubvXuXDCcd8beYcWhDg==';

  /// A file with a pin in it, as tool/build_windows.dart has it.
  String pin({String version = '0.164.0', String sha = integrity}) => '''
/// The Codex CLI the bundle carries, its version and its checksum.
const _codexVersion = '$version';
const _codexPlatform = 'win32-x64';
const _codexIntegrity =
    '$sha';

/// Where that package is: the npm registry's own file for the platform.
const _codexUrl =
    'https://registry.npmjs.org/@openai/codex/-/codex-\$_codexVersion-\$_codexPlatform.tgz';
''';

  group('reading the pin', () {
    test('the version and the checksum beside it', () {
      final found = pinnedFrom(pin());
      expect(found, isNotNull);
      expect(found!.version, '0.164.0');
      expect(found.integrity, integrity);
    });

    test('the version alone, when the checksum is not there', () {
      final found = pinnedFrom("const _codexVersion = '0.164.0';\n");
      expect(found?.version, '0.164.0');
      expect(found?.integrity, isNull);
    });

    test('nothing, when there is no version in it', () {
      expect(pinnedFrom('const somethingElse = 1;\n'), isNull);
    });

    test('the pin the build script has', () {
      // The tool and the file it writes have to agree: the tool rewrites
      // what is there, and the build reads what the tool wrote.
      final text = File('tool/build_windows.dart').readAsStringSync();
      final found = pinnedFrom(text);
      expect(found, isNotNull, reason: 'the pin is in tool/build_windows.dart');
      expect(found!.version, isNotEmpty);
      expect(found.integrity, matches(RegExp(r'^sha512-[A-Za-z0-9+/]+=*$')));
    });
  });

  group('writing the pin', () {
    test('the version and the checksum are put in', () {
      final written = writtenWithPin(pin(), '0.165.0', 'sha512-${'a' * 86}==');
      final found = pinnedFrom(written);
      expect(found?.version, '0.165.0');
      expect(found?.integrity, 'sha512-${'a' * 86}==');
    });

    test('writing it twice changes nothing the second time', () {
      final once = writtenWithPin(pin(), '0.165.0', 'sha512-${'a' * 86}==');
      final twice = writtenWithPin(once, '0.165.0', 'sha512-${'a' * 86}==');
      expect(twice, once);
    });

    test('the rest of the file is left alone', () {
      final written = writtenWithPin(pin(), '0.165.0', 'sha512-${'a' * 86}==');
      expect(written, contains('registry.npmjs.org'));
      expect(written, contains('/// The Codex CLI the bundle carries'));
    });
  });

  group('two versions', () {
    test('the greater one is the newer', () {
      expect(compareVersions('0.165.0', '0.164.0'), greaterThan(0));
      expect(compareVersions('0.164.0', '0.165.0'), lessThan(0));
      expect(compareVersions('0.164.0', '0.164.0'), isZero);
      expect(compareVersions('1.0.0', '0.99.99'), greaterThan(0));
    });

    test('what a version does not say is zero', () {
      expect(compareVersions('0.164.1', '0.164'), greaterThan(0));
    });
  });

  test('the platform\'s package is the version with the platform in it', () {
    expect(platformVersion('0.164.0'), '0.164.0-win32-x64');
  });
}
