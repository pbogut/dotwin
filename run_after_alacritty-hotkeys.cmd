@echo off
rem Start or reload the managed hotkeys immediately after applying the files.
powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$ErrorActionPreference = 'Stop'; Start-Process -FilePath (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup\alacritty-hotkeys.ahk')"
exit /b %errorlevel%
