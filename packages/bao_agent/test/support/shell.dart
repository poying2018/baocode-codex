// Whether the engine can run commands here at all. A security policy that
// denies the MSYS runtime its `\BaseNamedObjects` object makes every bash
// started by a Dart VM exit at once (docs/codex-project.md, 本机限制), and
// the tests that need a real command would otherwise fail on what the
// machine cannot do rather than on what the engine does.
import 'dart:io';

import 'package:bao_agent/src/util/processes.dart' show Shell;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

bool? _starts;

/// Runs one `echo` in the shell the engine would pick, once, and says
/// whether it came back.
Future<bool> shellStarts() async => _starts ??= await () async {
  final shell = Shell.find(Platform.environment);
  try {
    final ran = await Process.run(
      shell.executable,
      shell.arguments(
        'echo bao',
        p.join(Directory.systemTemp.path, 'bao-agent-shell-probe'),
      ),
    );
    return ran.exitCode == 0;
  } on ProcessException {
    return false;
  }
}();

/// For the first line of a test that needs a real command: skips the test
/// with the reason where the shell cannot start, and says so — the caller
/// returns; false where it can, and the test goes on.
Future<bool> skipWithoutShell() async {
  if (await shellStarts()) return false;
  markTestSkipped(
    'This machine cannot start a shell — bash exits at once (0xC0000022); '
    'CI runs this.',
  );
  return true;
}
