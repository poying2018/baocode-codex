/// The Codex CLI the app carries: beside the app's executable, in
/// `codex-cli/`, laid out as the platform's npm package is (the program
/// finds its resources beside itself that way).
///
/// A machine with no Codex of its own needs neither an install nor a
/// download: what `tool/build_windows.dart` puts there is the floor under
/// the ones the user has. Plain Dart, no Flutter: the build's own tools
/// ask it too.
library;

import 'dart:io';

import 'package:path/path.dart' as p;

/// Where the app carries its own Codex CLI.
abstract final class CodexBundle {
  /// The folder beside the app's executable.
  static const folder = 'codex-cli';

  /// The Codex CLI the app carries, when it carries one: the first
  /// `codex.exe` (or `codex` elsewhere) under [folder] beside
  /// [appExecutable], which is this program's own place when not given.
  static String? find([String? appExecutable]) {
    final executable = appExecutable ?? Platform.resolvedExecutable;
    final carried = Directory(p.join(p.dirname(executable), folder));
    if (!carried.existsSync()) return null;
    for (final entity in carried.listSync(recursive: true)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      // The CLI itself, not the hosts and helpers beside it
      // (codex-voice-host.exe, codex-command-runner.exe, …).
      if (name != 'codex.exe' && name != 'codex') continue;
      return entity.path;
    }
    return null;
  }

  /// The version of what [find] found, as the build wrote it down; null
  /// when the app carries none.
  static String? version([String? appExecutable]) {
    final executable = appExecutable ?? Platform.resolvedExecutable;
    final file = File(p.join(p.dirname(executable), folder, 'VERSION'));
    if (!file.existsSync()) return null;
    final text = file.readAsStringSync().trim();
    return text.isEmpty ? null : text;
  }
}
