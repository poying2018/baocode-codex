// Points the site's pages at this repository's own world: the releases and
// the repository, in place of the upstream's site and services, which this
// fork does not run. Run from the repository root; every change is shown by
// git diff.
import 'dart:io';

const replacements = [
  // The pages, longest first so a longer address is not cut short by a
  // shorter one's replacement.
  ['https://baocode.dev/zh/changelog',
      'https://github.com/poying2018/baocode-codex/releases'],
  ['https://baocode.dev/changelog',
      'https://github.com/poying2018/baocode-codex/releases'],
  ['https://baocode.dev/zh/download',
      'https://github.com/poying2018/baocode-codex/releases/latest'],
  ['https://baocode.dev/download',
      'https://github.com/poying2018/baocode-codex/releases/latest'],
  ['https://baocode.dev/zh/upstreams',
      'https://github.com/poying2018/baocode-codex/blob/main/site/upstreams.html'],
  ['https://baocode.dev/upstreams',
      'https://github.com/poying2018/baocode-codex/blob/main/site/upstreams.html'],
  ['https://github.com/baocode-dev/baocode/issues/new',
      'https://github.com/poying2018/baocode-codex/issues/new'],
  ['https://github.com/baocode-dev/baocode',
      'https://github.com/poying2018/baocode-codex'],
  ['https://baocode.dev',
      'https://github.com/poying2018/baocode-codex'],
  // Relative service paths the upstream's worker served (/dl/...), which
  // have no counterpart here: the app's releases are where those files are.
  ['href="/dl/windows"',
      'href="https://github.com/poying2018/baocode-codex/releases/latest"'],
];

void main() {
  var files = 0;
  var changes = 0;
  for (final entry in Directory('site').listSync(recursive: true)) {
    if (entry is! File || !entry.path.endsWith('.html')) continue;
    final text = entry.readAsStringSync();
    var next = text;
    for (final [from, to] in replacements) {
      next = next.replaceAll(from, to);
    }
    if (next != text) {
      entry.writeAsStringSync(next);
      files++;
      changes += [
        for (final [from, _] in replacements)
          if (text.contains(from)) from,
      ].length;
    }
  }
  stdout.writeln('files: $files');
}
