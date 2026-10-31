# Registers an installed BaoCode Codex with Windows, the way its installer
# would: the browsers' native-messaging hosts, the baocode-codex:// scheme,
# the Explorer context menu, the Start Menu shortcuts and the uninstall entry.
#
# For an install that went down by copy (a setup that could not write the
# user profile), so that the machine does not have to choose between
# "installed with the wizard" and "works".

$ErrorActionPreference = 'Stop'

$app = 'D:\BaoCodeCodex'
$exe = "$app\baocode-codex.exe"
$productKey = 'BaoCodeCodex'
$browserHost = 'dev.baocode-codex.browser'
$scheme = 'baocode-codex'
$name = 'BaoCode Codex'
$version = '1.7.2'
$uninstallKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{3c9e2b14-7f56-4d1a-9b2e-6d5f8a71c40}_is1"

if (-not (Test-Path $exe)) {
    Write-Error "The app is not at $exe - install it first."
    exit 1
}

# --- The browsers' native messaging host (Chrome, Edge, Chromium) -----------
$manifest = "$app\$browserHost.json"
foreach ($hive in @('Software\Google\Chrome\NativeMessagingHosts',
                    'Software\Microsoft\Edge\NativeMessagingHosts',
                    'Software\Chromium\NativeMessagingHosts')) {
    $key = "HKCU:\$hive\$browserHost"
    New-Item -Path $key -Force | Out-Null
    Set-ItemProperty -Path $key -Name '(default)' -Value $manifest
    Write-Host "host:  $key"
}

# --- The baocode-codex:// scheme --------------------------------------------
$schemeKey = "HKCU:\Software\Classes\$scheme"
New-Item -Path $schemeKey -Force | Out-Null
Set-ItemProperty -Path $schemeKey -Name '(default)' -Value "URL:$name"
New-Item -Path "$schemeKey\DefaultIcon" -Force | Out-Null
Set-ItemProperty -Path "$schemeKey\DefaultIcon" -Name '(default)' -Value "`"$exe`",0"
New-Item -Path "$schemeKey\shell\open\command" -Force | Out-Null
Set-ItemProperty -Path "$schemeKey\shell\open\command" -Name '(default)' -Value "`"$exe`" --baocode-link `"%1`""
Write-Host "scheme: $schemeKey"

# --- The Explorer context menu: Open with BaoCode Codex / Fast Ide ----------
foreach ($area in @('*', 'Directory', 'Directory\Background')) {
    foreach ($menu in @($productKey, "${productKey}FastIde")) {
        $key = "HKCU:\Software\Classes\$area\shell\$menu"
        New-Item -Path "$key\command" -Force | Out-Null
        $label = if ($menu -eq $productKey) { "Open with $name" } else { 'Open with Fast Ide' }
        Set-ItemProperty -Path $key -Name '(default)' -Value $label
        Set-ItemProperty -Path $key -Name 'Icon' -Value "$exe,0"
        if ($menu -eq $productKey) {
            $command = "`"$exe`" --baocode-agent `"%V`""
        } else {
            $command = "`"$exe`" --baocode-cli `"%V`" -n `"%V`""
        }
        Set-ItemProperty -Path "$key\command" -Name '(default)' -Value $command
        Write-Host "menu:  $key"
    }
}

# --- The Start Menu shortcuts ------------------------------------------------
$group = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\$name"
New-Item -ItemType Directory -Force -Path $group | Out-Null
$shell = New-Object -ComObject WScript.Shell
$lnk = $shell.CreateShortcut("$group\$name.lnk")
$lnk.TargetPath = $exe
$lnk.WorkingDirectory = $app
$lnk.Save()
$un = $shell.CreateShortcut("$group\Uninstall $name.lnk")
$un.TargetPath = "$app\unins000.exe"
if (Test-Path "$app\unins000.exe") { $un.Save() }
Write-Host "menu:  $group"

# --- The uninstall entry ------------------------------------------------------
New-Item -Path $uninstallKey -Force | Out-Null
Set-ItemProperty -Path $uninstallKey -Name 'DisplayName' -Value $name
Set-ItemProperty -Path $uninstallKey -Name 'DisplayVersion' -Value $version
Set-ItemProperty -Path $uninstallKey -Name 'DisplayIcon' -Value "$exe,0"
Set-ItemProperty -Path $uninstallKey -Name 'InstallLocation' -Value $app
Set-ItemProperty -Path $uninstallKey -Name 'UninstallString' -Value "`"$app\unins000.exe`""
Set-ItemProperty -Path $uninstallKey -Name 'NoModify' -Value 1 -Type DWord
Set-ItemProperty -Path $uninstallKey -Name 'NoRepair' -Value 1 -Type DWord
Set-ItemProperty -Path $uninstallKey -Name 'Publisher' -Value 'BaoCode'
Write-Host "uninstall: $uninstallKey"

Write-Host ''
Write-Host 'Registered. BaoCode Codex 1.7.2 is in Control Panel now.'
