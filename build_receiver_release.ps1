# Build release binary for Windows LAN Gamepad Receiver
$ErrorActionPreference = "Stop"

$mingw64 = "C:\Users\LENOVO\AppData\Local\Microsoft\WinGet\Packages\BrechtSanders.WinLibs.POSIX.UCRT_Microsoft.Winget.Source_8wekyb3d8bbwe\mingw64\bin"
if (Test-Path $mingw64) {
    $env:PATH = "$mingw64;" + ($env:PATH -replace 'C:\\MinGW\\bin;?', '')
}

Set-Location "$PSScriptRoot\receiver"
cargo build --release
Write-Host "`nRelease binary generated at: $PSScriptRoot\receiver\target\release\receiver.exe" -ForegroundColor Green
