import 'dart:io';

import 'package:baocode/kernel/codex/codex_process_transport_io.dart';
import 'package:baocode/kernel/codex/codex_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// The Dart that runs the retry stub: the SDK of the Flutter that runs
/// this.
String? _dart() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null || root.isEmpty) return null;
  final name = Platform.isWindows ? 'dart.exe' : 'dart';
  final dart = p.join(root, 'bin', 'cache', 'dart-sdk', 'bin', name);
  return File(dart).existsSync() ? dart : null;
}

/// An app-server whose first try ends before it was ready, and whose
/// second answers: the retry is what saves it. The first try marks its
/// pass with a file beside the working directory — each attempt is a
/// fresh process, so memory does not carry between them.
const _retryStub = '''
import 'dart:convert';
import 'dart:io';

void main() {
  final marker = File('codex_retry_marker');
  if (!marker.existsSync()) {
    marker.writeAsStringSync('x');
    stderr.writeln('first try fails on purpose');
    stderr.flush();
    exit(1);
  }
  stderr.writeln('second try lives');
  stderr.flush();
  stdin.transform(utf8.decoder).transform(const LineSplitter())
      .listen((line) {
    final request = line.trim().isEmpty ? null : line;
    if (request != null && request.contains('"method":"initialize"')) {
      stdout.writeln('{"id":0,"result":{"capabilities":{}}}');
      stdout.flush();
    }
  });
}
''';

void main() {
  test(
    'a start that ends once is saved by the automatic second try',
    () async {
      final dart = _dart();
      if (dart == null) {
        markTestSkipped('no Dart SDK beside the Flutter that runs this');
        return;
      }
      final home = await Directory.systemTemp.createTemp('baocode-codex-retry');
      addTearDown(() => home.deleteSync(recursive: true));
      final marker = File('codex_retry_marker');
      addTearDown(() {
        if (marker.existsSync()) marker.deleteSync();
      });
      final stub = File(p.join(home.path, 'retry.dart'))
        ..writeAsStringSync(_retryStub);
      ProcessCodexTransport.command = CodexExecutable(
        dart,
        arguments: [stub.path],
      );
      addTearDown(() => ProcessCodexTransport.command = null);

      final transport = await ProcessCodexTransport.start(
        CodexLaunch(cwd: Directory.current.path, home: home.path),
      );
      addTearDown(() async {
        transport.close();
        await transport.exited.timeout(
          const Duration(seconds: 5),
          onTimeout: () {},
        );
      });
      // It came up: the transport is the second attempt's, the one that
      // answered. Its log keeps the second attempt's words — the first
      // attempt's log was replaced when it was retried.
      expect(
        File(p.join(home.path, 'codex-stderr.log')).readAsStringSync(),
        contains('second try lives'),
      );
      transport.close();
    },
    timeout: const Timeout(Duration(seconds: 60)),
  );
}
