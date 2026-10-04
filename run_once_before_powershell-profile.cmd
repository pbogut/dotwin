@echo off
rem Use an inline command so this also works when .ps1 scripts are restricted.
powershell.exe -NoLogo -NoProfile -NonInteractive -Command "$ErrorActionPreference = 'Stop'; $policy = Get-ExecutionPolicy -Scope CurrentUser; if ($policy -in @('Undefined', 'Restricted')) { Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force }"
exit /b %errorlevel%
