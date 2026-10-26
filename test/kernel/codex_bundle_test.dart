// The Codex CLI the app carries: beside the app's executable, in
// `codex-cli/`, laid out as the platform's npm package is. A machine with
// no Codex of its own finds this one and needs neither an install nor a
// download.
import 'dart:io';

import 'package:baocode/kernel/codex/codex_bundle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('the Codex the app carries is found beside it', () {
    final app = Directory.systemTemp.createTempSync('codex-app-');
    addTearDown(() {
      try {
        app.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows: a handle it let go of a moment ago.
      }
    });
    final executable = p.join(app.path, 'baocode-codex.exe');

    // Nothing carried: nothing found.
    expect(CodexBundle.find(executable), isNull);

    // The package's own layout, as tool/build_windows.dart unpacks it.
    final carried = File(
      p.join(
        app.path,
        CodexBundle.folder,
        'vendor',
        'x86_64-pc-windows-msvc',
        'bin',
        'codex.exe',
      ),
    )..createSync(recursive: true);

    // A program beside it is not the CLI: the host the voice mode runs,
    // the command runner, the sandbox setup.
    for (final decoy in const [
      'codex-resources/voice/bin/codex-voice-host.exe',
      'codex-resources/codex-command-runner.exe',
      'codex-resources/codex-windows-sandbox-setup.exe',
      'bin/codex-code-mode-host.exe',
    ]) {
      File(p.join(app.path, CodexBundle.folder, decoy))
          .createSync(recursive: true);
    }

    expect(CodexBundle.find(executable), carried.path);
  });

  test('the version the build wrote down is read back', () {
    final app = Directory.systemTemp.createTempSync('codex-app-');
    addTearDown(() {
      try {
        app.deleteSync(recursive: true);
      } on FileSystemException {
        // As above.
      }
    });
    final executable = p.join(app.path, 'baocode-codex.exe');
    expect(CodexBundle.version(executable), isNull);
    File(p.join(app.path, CodexBundle.folder, 'VERSION'))
      ..createSync(recursive: true)
      ..writeAsStringSync('0.164.0-win32-x64\n');
    expect(CodexBundle.version(executable), '0.164.0-win32-x64');
  });

  test('a bundle of another platform is still the CLI', () {
    // The same check, without the Windows layout: a build for another
    // platform carries its own folder name, and the file is `codex`.
    final app = Directory.systemTemp.createTempSync('codex-app-');
    addTearDown(() {
      try {
        app.deleteSync(recursive: true);
      } on FileSystemException {
        // As above.
      }
    });
    final carried = File(
      p.join(
        app.path,
        CodexBundle.folder,
        'vendor',
        'aarch64-apple-darwin',
        'bin',
        'codex',
      ),
    )..createSync(recursive: true);

    expect(CodexBundle.find(p.join(app.path, 'baocode-codex')), carried.path);
  });
}
