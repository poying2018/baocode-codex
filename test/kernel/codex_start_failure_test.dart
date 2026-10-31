import 'dart:io';

import 'package:baocode/kernel/codex/codex_process_transport_io.dart';
import 'package:baocode/kernel/codex/codex_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The Dart that runs the failing stub: the SDK of the Flutter that runs
/// this.
String? _dart() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null || root.isEmpty) return null;
  final name = Platform.isWindows ? 'dart.exe' : 'dart';
  final dart = p.join(root, 'bin', 'cache', 'dart-sdk', 'bin', name);
  return File(dart).existsSync() ? dart : null;
}

/// A stub of an app-server that says something on stderr and ends before
/// it answers the initialize request.
const _dyingStub = '''
void main() {
  stderr.writeln('some trouble of its own');
  stderr.flush();
  exit(1);
}
''';

/// One that says a folder was held, the words the lock guess is for.
const _lockedStub = '''
void main() {
  stderr.writeln('database is locked by another process');
  stderr.flush();
  exit(1);
}
''';

void main() {
  test('a start that ends before it was ready says what Codex said', () async {
    final dart = _dart();
    if (dart == null) {
      markTestSkipped('no Dart SDK beside the Flutter that runs this');
      return;
    }
    final home = await Directory.systemTemp.createTemp('baocode-codex-fail');
    addTearDown(() => home.deleteSync(recursive: true));
    final stub = File(p.join(home.path, 'dying.dart'))
      ..writeAsStringSync(_dyingStub);
    ProcessCodexTransport.command = CodexExecutable(
      dart,
      arguments: [stub.path],
    );
    addTearDown(() => ProcessCodexTransport.command = null);

    Object? failure;
    try {
      // Two tries, both of which end: the retry is not silent forever.
      await ProcessCodexTransport.start(
        CodexLaunch(cwd: Directory.current.path, home: home.path),
      );
    } catch (error) {
      failure = error;
    }
    expect(failure, isA<CodexUnavailable>());
    final detail = (failure! as dynamic).detail as String;
    // Its own words are carried, not a guess about a folder held.
    expect(detail, contains('some trouble of its own'));
    expect(detail, isNot(contains('holding its folder')));
    // The words are kept beside the state, so they outlive the attempt.
    expect(
      File(p.join(home.path, 'codex-stderr.log')).readAsStringSync(),
      contains('some trouble of its own'),
    );
  });

  test('a lock in its own words is told as one', () async {
    final dart = _dart();
    if (dart == null) {
      markTestSkipped('no Dart SDK beside the Flutter that runs this');
      return;
    }
    final home = await Directory.systemTemp.createTemp('baocode-codex-lock');
    addTearDown(() => home.deleteSync(recursive: true));
    final stub = File(p.join(home.path, 'locked.dart'))
      ..writeAsStringSync(_lockedStub);
    ProcessCodexTransport.command = CodexExecutable(
      dart,
      arguments: [stub.path],
    );
    addTearDown(() => ProcessCodexTransport.command = null);

    Object? failure;
    try {
      await ProcessCodexTransport.start(
        CodexLaunch(cwd: Directory.current.path, home: home.path),
      );
    } catch (error) {
      failure = error;
    }
    final detail = (failure! as dynamic).detail as String;
    expect(detail, contains('holding its folder'));
    expect(detail, contains('database is locked'));
  });
}
