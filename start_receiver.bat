@echo off
title LAN Gamepad - PC Receiver
echo ===================================================
echo Starting LAN Gamepad Receiver...
echo ===================================================

powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0run_receiver.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Receiver stopped with error code %ERRORLEVEL%.
    pause
)
