Set shell = CreateObject("WScript.Shell")
shell.Run "powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File """ & shell.ExpandEnvironmentStrings("%APPDATA%\vban-mini\start.ps1") & """", 0, False
