# Runner script for Windows LAN Gamepad Receiver
$ErrorActionPreference = "Stop"

# Ensure 64-bit MinGW toolchain is prioritized over any legacy 32-bit MinGW
$mingw64 = "C:\Users\LENOVO\AppData\Local\Microsoft\WinGet\Packages\BrechtSanders.WinLibs.POSIX.UCRT_Microsoft.Winget.Source_8wekyb3d8bbwe\mingw64\bin"
if (Test-Path $mingw64) {
    $env:PATH = "$mingw64;" + ($env:PATH -replace 'C:\\MinGW\\bin;?', '')
}

Set-Location "$PSScriptRoot\receiver"
cargo run -- @args
