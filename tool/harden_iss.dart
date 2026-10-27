// Adds the guards that keep the installer from rolling back when the places
// outside {app} cannot be written: the Start Menu folder and
// Software\Classes. Run once; the script is checked by compiling it.
import 'dart:io';

void main() {
  final file = File('tool/baocode.iss');
  final raw = file.readAsStringSync();
  // The file's own line ending, kept as it is when it is written back.
  final eol = raw.contains('\r\n') ? '\r\n' : '\n';
  final text = raw.replaceAll('\r\n', '\n');
  var out = StringBuffer();
  var section = '';
  var icons = 0;
  var registry = 0;
  final lines = text.split('\n');

  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    final header = RegExp(r'^\[(.+)\]').firstMatch(line);
    if (header != null) section = header.group(1)!;

    if (section == 'Icons' && line.trimLeft().startsWith('Name:') &&
        !line.contains('Check:')) {
      out.writeln('${line.trimRight()}; Check: MenuAllowed');
      icons++;
      i++;
      continue;
    }

    if (section == 'Registry' && line.trimLeft().startsWith('Root:')) {
      // The whole entry, which may go on for lines ending in a backslash.
      final block = <String>[line];
      while (lines[i].trimRight().endsWith('\\') && i + 1 < lines.length) {
        i++;
        block.add(lines[i]);
      }
      final joined = block.join('\n');
      if (joined.contains(r'Software\Classes') && !joined.contains('Check:')) {
        final last = block.length - 1;
        block[last] = '${block[last].trimRight()}; Check: ClassesAllowed';
        registry++;
      }
      for (final b in block) {
        out.writeln(b);
      }
      i++;
      continue;
    }

    out.writeln(line);
    i++;
  }

  var result = out.toString();

  // The two values, and the functions [Check] wants (it takes a name).
  const vars = '''

// Whether the places outside {app} may be written: the Start Menu folder
// (its shortcuts) and Software\\Classes (the context menu, the URL scheme).
//
// A profile that refuses them — a locked-down one, or Setup run without the
// user's own token — loses those and keeps the program, rather than the
// installation rolling back on the first one it cannot write and leaving
// nothing installed at all, which is what it did before this was asked.
var
  MenuWritable: Boolean;
  ClassesWritable: Boolean;

/// Whether [Dir] can be made: made here, as Setup would make it.
function ProbeDir(const Dir: String): Boolean;
begin
  Result := ForceDirectories(Dir);
end;

/// Whether [Subkey] of [Root] can be written: a value put in, then removed.
function ProbeKey(Root: Integer; const Subkey: String): Boolean;
var
  Probe: String;
begin
  Probe := Subkey + '\\__baocode_probe';
  Result := RegWriteStringValue(Root, Probe, '', '1');
  if Result then
    RegDeleteKeyIncludingSubkeys(Root, Probe);
end;

/// Whether the context menu and the URL scheme can be registered, in the
/// hive the install mode writes.
function ProbeClasses: Boolean;
begin
  if IsAdminInstallMode then
    Result := ProbeKey(HKEY_LOCAL_MACHINE, 'Software\\Classes\\*\\shell')
  else
    Result := ProbeKey(HKEY_CURRENT_USER, 'Software\\Classes\\*\\shell');
end;

/// The Start Menu's, as [Check] wants it: a function, not a value.
function MenuAllowed: Boolean;
begin
  Result := MenuWritable;
end;

/// Software\\Classes', as [Check] wants it.
function ClassesAllowed: Boolean;
begin
  Result := ClassesWritable;
end;
''';

  const anchor = 'function CloseHandle(hObject: THandle): BOOL;\n'
      "  external 'CloseHandle@kernel32.dll stdcall';\n";
  if (!result.contains(anchor)) {
    stderr.writeln('the CloseHandle import is not where it was expected');
    exit(2);
  }
  result = result.replaceFirst(anchor, anchor + vars);

  // The values, before anything is written.
  const begin = 'begin\n  Result := True;\n';
  const probe = '''
begin
  Result := True;
  // Asked before anything is written: what cannot be written is skipped
  // rather than aborted on, so that the program itself still goes in.
  MenuWritable := ProbeDir(ExpandConstant('{group}'));
  ClassesWritable := ProbeClasses;
  if not MenuWritable then
    Log('The Start Menu folder cannot be written: its shortcuts are skipped');
  if not ClassesWritable then
    Log('Software\\Classes cannot be written: the context menu and the ' +
        'URL scheme are skipped');
''';
  final occurrences = RegExp(RegExp.escape(begin)).allMatches(result).length;
  if (occurrences != 1) {
    stderr.writeln('expected one InitializeSetup begin, found $occurrences');
    exit(2);
  }
  result = result.replaceFirst(begin, probe);

  file.writeAsStringSync(
    eol == '\r\n' ? result.replaceAll('\n', '\r\n') : result,
  );
  stdout.writeln('icons: $icons, registry entries: $registry');
}
