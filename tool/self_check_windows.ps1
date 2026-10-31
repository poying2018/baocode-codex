$ErrorActionPreference = 'SilentlyContinue'
$app = 'D:\BaoCodeCodex\baocode-codex.exe'
Write-Host '=== BaoCode Codex self-check ==='
if (-not (Test-Path $app)) { Write-Host '[X] app missing'; exit 1 }
Write-Host '[OK] app'
$cli = 'D:\BaoCodeCodex\codex-cli\vendor\x86_64-pc-windows-msvc\bin\codex.exe'
if (Test-Path $cli) {
  $v = & $cli --version 2>$null | Select-Object -First 1
  Write-Host "[OK] carried CLI: $v"
} else { Write-Host '[X] carried CLI missing' }
function Test-Key($path) { Test-Path "Registry::$path" }
if (Test-Key 'HKEY_CURRENT_USER\Software\Google\Chrome\NativeMessagingHosts\dev.baocode-codex.browser') { Write-Host '[OK] Chrome host' } else { Write-Host '[X] Chrome host' }
if (Test-Key 'HKEY_CURRENT_USER\Software\Microsoft\Edge\NativeMessagingHosts\dev.baocode-codex.browser') { Write-Host '[OK] Edge host' } else { Write-Host '[X] Edge host' }
if (Test-Key 'HKEY_CURRENT_USER\Software\Classes\baocode-codex') { Write-Host '[OK] baocode-codex:// scheme' } else { Write-Host '[X] scheme' }
if (Test-Key 'HKEY_CURRENT_USER\Software\Classes\Directory\shell\BaoCodeCodex') { Write-Host '[OK] context menu' } else { Write-Host '[X] context menu' }
if (Test-Key 'HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Uninstall\{3c9e2b14-7f56-4d1a-9b2e-6d5f8a71c40}_is1') { Write-Host '[OK] uninstall entry' } else { Write-Host '[X] uninstall entry (finish the setup wizard to add it)' }
if (Test-Path "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\BaoCode Codex\BaoCode Codex.lnk") { Write-Host '[OK] start menu' } else { Write-Host '[X] start menu shortcut' }
if (Test-Path 'D:\BaoCodeCodex-extend\manifest.json') { Write-Host '[OK] extension folder: D:\BaoCodeCodex-extend' } else { Write-Host '[X] extension folder' }
