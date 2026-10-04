$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.SendKeys]::SendWait('^{F11}')
'{"label":"Clip requested","label_size":25}'
Start-Sleep -Milliseconds 1500
'{"label":"Save clip","label_size":30}'
