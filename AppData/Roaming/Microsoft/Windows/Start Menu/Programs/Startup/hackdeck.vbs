Set shell = CreateObject("WScript.Shell")
shell.Run """" & shell.ExpandEnvironmentStrings("%USERPROFILE%\go\bin\hackdeck.exe") & """", 0, False
