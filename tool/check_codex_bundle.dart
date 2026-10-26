// Says which Codex the app carries, and whether it runs: the CLI a build
// puts beside the app's executable (codex-cli\), so that a machine with no
// Codex of its own needs neither an install nor a download.
//
//   dart tool/check_codex_bundle.dart [<app executable>]
//
// With no argument it asks about the folder this program is in; give a
// built app's path to ask about that build without running it.
import 'dart:io';

import 'package:baocode/kernel/codex/codex_bundle.dart';

void main(List<String> arguments) {
  final app = arguments.isEmpty ? null : arguments.first;
  final where = app ?? Platform.resolvedExecutable;
  final carried = CodexBundle.find(where);
  final version = CodexBundle.version(where);
  stdout.writeln('app:      $where');
  stdout.writeln('carried:  ${carried ?? '(none beside it)'}');
  stdout.writeln('version:  ${version ?? '(not written down)'}');
  if (carried == null) {
    stdout.writeln('runs:     no');
    exitCode = 1;
    return;
  }
  final result = Process.runSync(carried, ['--version']);
  final said = '${result.stdout}'.trim().isEmpty
      ? '${result.stderr}'.trim()
      : '${result.stdout}'.trim();
  stdout.writeln('runs:     ${result.exitCode == 0 ? said : 'no — $said'}');
  if (result.exitCode != 0) exitCode = 1;
}
