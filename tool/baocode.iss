; The Windows installer for BaoCode, compiled by tool/build_windows.dart.
;
; It is compiled with three /D defines, all required:
;   BundleDir  the Release bundle to pack (the folder holding baocode.exe)
;   AppVersion the version pubspec.yaml carries, as it writes it (1.0.0+1)
;   OutDir     where to write the installer (build/installers)
;
; Output: BaoCode-<version>-setup.exe

#ifndef BundleDir
  #error BundleDir is not defined: pass /DBundleDir=<release bundle folder>
#endif
#ifndef AppVersion
  #error AppVersion is not defined: pass /DAppVersion=<version from pubspec.yaml>
#endif
#ifndef OutDir
  #error OutDir is not defined: pass /DOutDir=<folder for the installer>
#endif

; The channel build's (tool/build_windows.dart --channel): "-channel", after
; the installer's name. The same app either way, installed over the other.
#ifndef Edition
  #define Edition ""
#endif

; The product this installer installs, as tool/build_windows.dart names it by
; its executable (see windows/runner/app_identity.cpp): BaoCode, whose
; executable is baocode.exe, or the codex one, baocode-codex.exe. Each product
; has its own name, its own identity in Windows, its own folder and its own
; Start menu group, so the two install side by side and neither upgrades the
; other. The defaults are BaoCode's: what the app has always been.
#ifndef ProductName
  #define ProductName "BaoCode"
#endif
#ifndef ProductId
  #define ProductId "{{6fdd732b-95c6-4c37-af6f-ff574358deb5}"
#endif
#ifndef ProductExe
  #define ProductExe "baocode.exe"
#endif
#ifndef ProductDir
  #define ProductDir "BaoCode"
#endif
; The key Explorer's context menu entries are under, the URL scheme, and the
; browsers' native messaging host: each product has one of its own, so that
; the two do not take each other's away.
#ifndef ProductKey
  #define ProductKey "BaoCode"
#endif
#ifndef ProductScheme
  #define ProductScheme "baocode"
#endif
#ifndef ProductBrowserHost
  #define ProductBrowserHost "dev.baocode.browser"
#endif
#ifndef ProductBrowserManifest
  #define ProductBrowserManifest "dev.baocode.browser.json"
#endif
; The installer's file name: the product's own, without a space in it (the
; release's assets are named after it, and a space in a file name is a
; nuisance in a command line).
#ifndef ProductFileName
  #define ProductFileName "BaoCode"
#endif

; The part of the version Windows records, without the build number pubspec
; adds after "+".
#define VersionNumber Copy(AppVersion, 1, Pos("+", AppVersion) - 1)
#if Pos("+", AppVersion) == 0
  #undef VersionNumber
  #define VersionNumber AppVersion
#endif

[Setup]
; Base of the identity Windows uses for the installed app. It must not change
; between versions, or an upgrade installs beside the old one instead of over
; it; and it must differ between the products, or one would install over the
; other.
AppId={#ProductId}
AppName={#ProductName}
AppVersion={#VersionNumber}
AppPublisher={#ProductName}
AppVerName={#ProductName} {#VersionNumber}
DefaultDirName={autopf}\{#ProductDir}
DefaultGroupName={#ProductName}
UninstallDisplayName={#ProductName}
UninstallDisplayIcon={app}\{#ProductExe}
OutputBaseFilename={#ProductFileName}-{#VersionNumber}-setup{#Edition}
OutputDir={#OutDir}
; What Explorer shows for the installer itself. Windows wants four numbers,
; where pubspec's version has three.
VersionInfoVersion={#VersionNumber}.0
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; The app is 64-bit only (flutter build windows is x64 here).
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
; Per user by default ({autopf} is then %LOCALAPPDATA%\Programs): neither
; the install nor the app's updates ask for elevation, which a machine may
; not grant (no admin; UAC set to elevate signed programs only, and Setup is
; not signed) or show behind other windows. For all users (Program Files,
; elevated) is the dialog's other choice; an update keeps the install mode
; there is (UsePreviousPrivileges, and lib/update/installer_io.dart passes
; it).
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
DisableProgramGroupPage=yes
; A running BaoCode is asked to close (it quits on WM_ENDSESSION, see
; windows/runner/flutter_window.cpp), and ended if it does not: a version
; from before that, or one stuck, would otherwise hold Setup at "Closing
; applications..." for good.
CloseApplications=force
; Always a log (%TEMP%\Setup Log <date> #<n>.txt, or where /LOG= says, as
; an update the app runs does): a silent install that fails says why only
; there.
SetupLogging=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; \
  GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "addtopath"; Description: "Add {#ProductName} to the PATH"; \
  GroupDescription: "Other:"; Flags: unchecked
Name: "contextmenu"; \
  Description: "Add ""Open with {#ProductName}"" and ""Open with Fast Ide"" to Explorer's context menu"; \
  GroupDescription: "Other:"

[Files]
; The whole bundle: baocode-codex.exe, the engine and plugin DLLs, data\
; (the AOT app.so and flutter_assets) which sit beside the executable, and
; remote\ (VERSION and servers.json: which baocode-codex-server remote
; projects run on their host, and where the app downloads it;
; tool/build_windows.dart puts them there), openssh\ (OpenSSH for Windows,
; for remote projects where the system's ssh is too old to ask for a
; password), and codex-cli\ (the Codex CLI itself, so that a machine with
; none of its own needs no install and no download; tool/build_windows.dart
; puts it there).
Source: "{#BundleDir}\*"; DestDir: "{app}"; \
  Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#ProductName}"; Filename: "{app}\{#ProductExe}"; Check: MenuAllowed
Name: "{group}\{cm:UninstallProgram,{#ProductName}}"; Filename: "{uninstallexe}"; Check: MenuAllowed
Name: "{autodesktop}\{#ProductName}"; Filename: "{app}\{#ProductExe}"; Tasks: desktopicon; Check: MenuAllowed

[Registry]
; Only when asked for. Which hive follows the install mode: a per-machine
; install writes the machine's PATH (HKLM), a per-user one the user's (HKCU).
; Writing HKCU while installing as admin would put the entry in whichever
; account elevated, which is not necessarily the one that runs the app.
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; \
  ValueType: expandsz; ValueName: "Path"; ValueData: "{olddata};{app}"; \
  Tasks: addtopath; Check: IsAdminInstallMode and NeedsAddPath(ExpandConstant('{app}'), True)
Root: HKCU; Subkey: "Environment"; ValueType: expandsz; ValueName: "Path"; \
  ValueData: "{olddata};{app}"; Tasks: addtopath; \
  Check: (not IsAdminInstallMode) and NeedsAddPath(ExpandConstant('{app}'), False)

; Explorer's context menu, on a file, a folder and a folder's background,
; each in a new window: Open with BaoCode, a new agent in a narrow window of
; its own (a file in its composer; see AppWindows.openAgent), and Open with
; Fast Ide, as `code -n` opens it (the path its own working folder: it is
; absolute). HKA is the install mode's hive (HKLM per machine, HKCU per
; user). Windows 11 lists them under "Show more options". Unticked on a
; reinstall, they go. Settings → General writes the same keys under HKCU
; (lib/platform/context_menu_io.dart), for the user alone.
Root: HKA; Subkey: "Software\Classes\*\shell\{#ProductKey}"; ValueType: string; \
  ValueName: ""; ValueData: "{code:MenuLabel|{#ProductName}}"; Tasks: contextmenu; \
  Flags: uninsdeletekey; Check: ClassesAllowed
Root: HKA; Subkey: "Software\Classes\*\shell\{#ProductKey}"; ValueType: string; \
  ValueName: "Icon"; ValueData: """{app}\{#ProductExe}"""; Tasks: contextmenu; Check: ClassesAllowed
Root: HKA; Subkey: "Software\Classes\*\shell\{#ProductKey}\command"; \
  ValueType: string; ValueName: ""; \
  ValueData: """{app}\{#ProductExe}"" --baocode-agent ""%1"""; Tasks: contextmenu; Check: ClassesAllowed
Root: HKA; Subkey: "Software\Classes\Directory\shell\{#ProductKey}"; \
  ValueType: string; ValueName: ""; ValueData: "{code:MenuLabel|{#ProductName}}"; \
  Tasks: contextmenu; Flags: uninsdeletekey; Check: ClassesAllowed
Root: HKA; Subkey: "Software\Classes\Directory\shell\{#ProductKey}"; \
  ValueType: string; ValueName: "Icon"; ValueData: """{app}\{#ProductExe}"""; \
  Tasks: contextmenu; Check: ClassesAllowed
Root: HKA; Subkey: "Software\Classes\Directory\shell\{#ProductKey}\command"; \
  ValueType: string; ValueName: ""; \
  ValueData: """{app}\{#ProductExe}"" --baocode-agent ""%V"""; Tasks: contextmenu; Check: ClassesAllowed
Root: HKA; Subkey: "Software\Classes\Directory\Background\shell\{#ProductKey}"; \
  ValueType: string; ValueName: ""; ValueData: "{code:MenuLabel|{#ProductName}}"; \
  Tasks: contextmenu; Flags: uninsdeletekey; Check: ClassesAllowed
Root: HKA; Subkey: "Software\Classes\Directory\Background\shell\{#ProductKey}"; \
  ValueType: string; ValueName: "Icon"; ValueData: """{app}\{#ProductExe}"""; \
  Tasks: contextmenu; Check: ClassesAllowed
Root: HKA; Subkey: "Software\Classes\Directory\Background\shell\{#ProductKey}\command"; \
  ValueType: string; ValueName: ""; \
  ValueData: """{app}\{#ProductExe}"" --baocode-agent ""%V"""; Tasks: contextmenu; Check: ClassesAllowed
Root: HKA; Subkey: "Software\Classes\*\shell\{#ProductKey}FastIde"; \
  ValueType: string; ValueName: ""; ValueData: "{code:MenuLabel|Fast Ide}"; \
  Tasks: contextmenu; Flags: uninsdeletekey; Check: ClassesAllowed
Root: HKA; Subkey: "Software\Classes\*\shell\{#ProductKey}FastIde"; \
  ValueType: string; ValueName: "Icon"; ValueData: """{app}\{#ProductExe}"""; \
  Tasks: contextmenu; Check: ClassesAllowed
Root: HKA; Subkey: "Software\Classes\*\shell\{#ProductKey}FastIde\command"; \
  ValueType: string; ValueName: ""; \
  ValueData: """{app}\{#ProductExe}"" --baocode-cli ""%1"" -n ""%1"""; \
  Tasks: contextmenu; Check: ClassesAllowed
Root: HKA; Subkey: "Software\Classes\Directory\shell\{#ProductKey}FastIde"; \
  ValueType: string; ValueName: ""; ValueData: "{code:MenuLabel|Fast Ide}"; \
  Tasks: contextmenu; Flags: uninsdeletekey; Check: ClassesAllowed
Root: HKA; Subkey: "Software\Classes\Directory\shell\{#ProductKey}FastIde"; \
  ValueType: string; ValueName: "Icon"; ValueData: """{app}\{#ProductExe}"""; \
  Tasks: contextmenu; Check: ClassesAllowed
Root: HKA; Subkey: "Software\Classes\Directory\shell\{#ProductKey}FastIde\command"; \
  ValueType: string; ValueName: ""; \
  ValueData: """{app}\{#ProductExe}"" --baocode-cli ""%V"" -n ""%V"""; \
  Tasks: contextmenu; Check: ClassesAllowed
Root: HKA; Subkey: "Software\Classes\Directory\Background\shell\{#ProductKey}FastIde"; \
  ValueType: string; ValueName: ""; ValueData: "{code:MenuLabel|Fast Ide}"; \
  Tasks: contextmenu; Flags: uninsdeletekey; Check: ClassesAllowed
Root: HKA; Subkey: "Software\Classes\Directory\Background\shell\{#ProductKey}FastIde"; \
  ValueType: string; ValueName: "Icon"; ValueData: """{app}\{#ProductExe}"""; \
  Tasks: contextmenu; Check: ClassesAllowed
Root: HKA; Subkey: "Software\Classes\Directory\Background\shell\{#ProductKey}FastIde\command"; \
  ValueType: string; ValueName: ""; \
  ValueData: """{app}\{#ProductExe}"" --baocode-cli ""%V"" -n ""%V"""; \
  Tasks: contextmenu; Check: ClassesAllowed
; The URL scheme, always: a site's one-click import of an upstream
; (baocode.dev/import opens baocode://provider/import?…; see
; docs/upstream-import.md), and the channel build's setup (baocode.dev/activate
; opens baocode://activate?…). The link comes after --baocode-link, which the
; runner hands Flutter as a request (windows/runner/open_requests.cpp).
; Each product has one of its own (ProductScheme), so that one does not take
; the other's scheme away.
Root: HKA; Subkey: "Software\Classes\{#ProductScheme}"; ValueType: string; \
  ValueName: ""; ValueData: "URL:{#ProductName}"; Flags: uninsdeletekey; Check: ClassesAllowed
Root: HKA; Subkey: "Software\Classes\{#ProductScheme}"; ValueType: string; \
  ValueName: "URL Protocol"; ValueData: ""; Check: ClassesAllowed
Root: HKA; Subkey: "Software\Classes\{#ProductScheme}\DefaultIcon"; ValueType: string; \
  ValueName: ""; ValueData: """{app}\{#ProductExe}"",0"; Check: ClassesAllowed
Root: HKA; Subkey: "Software\Classes\{#ProductScheme}\shell\open\command"; \
  ValueType: string; ValueName: ""; \
  ValueData: """{app}\{#ProductExe}"" --baocode-link ""%1"""; Check: ClassesAllowed
; The browsers' native messaging host for the extension, always
; (windows/BrowserBridge): a browser finds the manifest, beside the
; executable, by its key, and the manifest names the host beside it.
; Chrome's key is also the one Brave, Vivaldi and other Chromium browsers
; read; Edge and Chromium read their own. The keys above go at uninstall
; too when nothing else is left in them (the browser is not installed).
; Each product has a key of its own (ProductBrowserHost), so that the
; extension of one does not talk to the other.
Root: HKA; Subkey: "Software\Google"; ValueType: none; \
  Flags: uninsdeletekeyifempty
Root: HKA; Subkey: "Software\Google\Chrome"; ValueType: none; \
  Flags: uninsdeletekeyifempty
Root: HKA; Subkey: "Software\Google\Chrome\NativeMessagingHosts"; \
  ValueType: none; Flags: uninsdeletekeyifempty
Root: HKA; Subkey: "Software\Google\Chrome\NativeMessagingHosts\{#ProductBrowserHost}"; \
  ValueType: string; ValueName: ""; \
  ValueData: "{app}\{#ProductBrowserManifest}"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Microsoft\Edge"; ValueType: none; \
  Flags: uninsdeletekeyifempty
Root: HKA; Subkey: "Software\Microsoft\Edge\NativeMessagingHosts"; \
  ValueType: none; Flags: uninsdeletekeyifempty
Root: HKA; Subkey: "Software\Microsoft\Edge\NativeMessagingHosts\{#ProductBrowserHost}"; \
  ValueType: string; ValueName: ""; \
  ValueData: "{app}\{#ProductBrowserManifest}"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Chromium"; ValueType: none; \
  Flags: uninsdeletekeyifempty
Root: HKA; Subkey: "Software\Chromium\NativeMessagingHosts"; \
  ValueType: none; Flags: uninsdeletekeyifempty
Root: HKA; Subkey: "Software\Chromium\NativeMessagingHosts\{#ProductBrowserHost}"; \
  ValueType: string; ValueName: ""; \
  ValueData: "{app}\{#ProductBrowserManifest}"; Flags: uninsdeletekey
; Unticked: what an earlier install added goes.
Root: HKA; Subkey: "Software\Classes\*\shell\{#ProductKey}"; ValueType: none; \
  Tasks: not contextmenu; Flags: deletekey; Check: ClassesAllowed
Root: HKA; Subkey: "Software\Classes\Directory\shell\{#ProductKey}"; ValueType: none; \
  Tasks: not contextmenu; Flags: deletekey; Check: ClassesAllowed
Root: HKA; Subkey: "Software\Classes\Directory\Background\shell\{#ProductKey}"; \
  ValueType: none; Tasks: not contextmenu; Flags: deletekey; Check: ClassesAllowed
Root: HKA; Subkey: "Software\Classes\*\shell\{#ProductKey}FastIde"; ValueType: none; \
  Tasks: not contextmenu; Flags: deletekey; Check: ClassesAllowed
Root: HKA; Subkey: "Software\Classes\Directory\shell\{#ProductKey}FastIde"; \
  ValueType: none; Tasks: not contextmenu; Flags: deletekey; Check: ClassesAllowed
Root: HKA; Subkey: "Software\Classes\Directory\Background\shell\{#ProductKey}FastIde"; \
  ValueType: none; Tasks: not contextmenu; Flags: deletekey; Check: ClassesAllowed

[Run]
Filename: "{app}\{#ProductExe}"; Description: "{cm:LaunchProgram,{#ProductName}}"; \
  Flags: nowait postinstall skipifsilent
; An update the app ran (lib/update/installer_io.dart) is silent, which
; skips the entry above: /RELAUNCH opens the app again once it is in place,
; as the user who ran it rather than the administrator Setup elevated to.
Filename: "{app}\{#ProductExe}"; Flags: nowait runasoriginaluser; \
  Check: RelaunchRequested

[Code]
const
  SYNCHRONIZE = $00100000;
  WaitPidTimeout = 120000;

function OpenProcess(dwDesiredAccess: DWORD; bInheritHandle: BOOL;
  dwProcessId: DWORD): THandle;
  external 'OpenProcess@kernel32.dll stdcall';
function WaitForSingleObject(hHandle: THandle; dwMilliseconds: DWORD): DWORD;
  external 'WaitForSingleObject@kernel32.dll stdcall';
function CloseHandle(hObject: THandle): BOOL;
  external 'CloseHandle@kernel32.dll stdcall';

// Whether the places outside {app} may be written: the Start Menu folder
// (its shortcuts) and Software\Classes (the context menu, the URL scheme).
//
// A profile that refuses them — a locked-down one, or Setup run without the
// user's own token — loses those and keeps the program, rather than the
// installation rolling back on the first one it cannot write and leaving
// nothing installed at all, which is what it did before this was asked.
//
// Asked lazily, the first time a [Check] wants an answer, and cached: Setup
// calls a check function for every entry that names it, several times over.
// Not in InitializeSetup, which the uninstaller never runs, and the same
// checks gate the uninstall's deletions: an answer taken from a variable the
// uninstall never set would say no and leave the menu and the scheme behind.
var
  MenuAsked: Boolean;
  MenuWritable: Boolean;
  ClassesAsked: Boolean;
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
  Probe := Subkey + '\__baocode_probe';
  Result := RegWriteStringValue(Root, Probe, '', '1');
  if Result then
    RegDeleteKeyIncludingSubkeys(Root, Probe);
end;

/// Whether the context menu and the URL scheme can be registered, in the
/// hive the install mode writes.
function ProbeClasses: Boolean;
begin
  if IsAdminInstallMode then
    Result := ProbeKey(HKEY_LOCAL_MACHINE, 'Software\Classes\*\shell')
  else
    Result := ProbeKey(HKEY_CURRENT_USER, 'Software\Classes\*\shell');
end;

/// The Start Menu's, as [Check] wants it: a function, not a value.
///
/// The uninstall answers yes without probing: what the install wrote is the
/// uninstall's to take away, whether or not the place can still be written.
function MenuAllowed: Boolean;
begin
  if IsUninstaller then
    Result := True
  else
  begin
    if not MenuAsked then
    begin
      MenuWritable := ProbeDir(ExpandConstant('{group}'));
      MenuAsked := True;
      if not MenuWritable then
        Log('The Start Menu folder cannot be written: its shortcuts are ' +
            'skipped');
    end;
    Result := MenuWritable;
  end;
end;

/// Software\Classes, as [Check] wants it, asked the same way.
function ClassesAllowed: Boolean;
begin
  if IsUninstaller then
    Result := True
  else
  begin
    if not ClassesAsked then
    begin
      ClassesWritable := ProbeClasses;
      ClassesAsked := True;
      if not ClassesWritable then
        Log('Software\Classes cannot be written: the context menu and the ' +
            'URL scheme are skipped');
    end;
    Result := ClassesWritable;
  end;
end;

// An update the app runs (lib/update/installer_io.dart) starts Setup as the
// app quits, with /WAITPID=<the app's process>, so the elevation it asks
// for comes up in front of the app: it waits here (two minutes at most) for
// the app to be gone before installing over it. One that does not go is
// closed by CloseApplications=force.
function InitializeSetup: Boolean;
var
  Pid: Integer;
  App: THandle;
begin
  Result := True;
  Pid := StrToIntDef(ExpandConstant('{param:WAITPID|0}'), 0);
  if Pid <= 0 then
    Exit;
  App := OpenProcess(SYNCHRONIZE, False, Pid);
  if App = 0 then
  begin
    Log(Format('Process %d is gone already', [Pid]));
    Exit;
  end;
  Log(Format('Waiting for process %d to quit', [Pid]));
  if WaitForSingleObject(App, WaitPidTimeout) <> 0 then
    Log(Format('Process %d is still running', [Pid]));
  CloseHandle(App);
end;

// Whether the command line asks for the app to be opened after a silent
// install (/RELAUNCH, an update's; see [Run]). Not silent, the finish
// page's checkbox opens it.
function RelaunchRequested: Boolean;
var
  I: Integer;
begin
  Result := False;
  if not WizardSilent then
    Exit;
  for I := 1 to ParamCount do
    if CompareText(ParamStr(I), '/RELAUNCH') = 0 then
    begin
      Result := True;
      Exit;
    end;
end;

// The context menu's labels (see [Registry]): "Open with BaoCode", in
// Chinese where Windows is. Written as code points, so the script's encoding
// does not matter.
function MenuLabel(Param: String): String;
begin
  if (GetUILanguage and $3FF) = $04 then
    Result := #$7528 + ' ' + Param + ' ' + #$6253#$5F00
  else
    Result := 'Open with ' + Param;
end;

// Whether {app} is already on the PATH the install will write, so a reinstall
// does not append it a second time. Machine reads the machine's PATH, user the
// user's, matching [Registry] above.
function NeedsAddPath(Param: string; Machine: Boolean): Boolean;
var
  Path: String;
  Subkey: String;
  RootKey: Integer;
begin
  if Machine then
  begin
    RootKey := HKEY_LOCAL_MACHINE;
    Subkey := 'SYSTEM\CurrentControlSet\Control\Session Manager\Environment';
  end
  else
  begin
    RootKey := HKEY_CURRENT_USER;
    Subkey := 'Environment';
  end;

  if not RegQueryStringValue(RootKey, Subkey, 'Path', Path) then
  begin
    Result := True;
    Exit;
  end;
  Result := Pos(';' + Uppercase(Param) + ';', ';' + Uppercase(Path) + ';') = 0;
end;

