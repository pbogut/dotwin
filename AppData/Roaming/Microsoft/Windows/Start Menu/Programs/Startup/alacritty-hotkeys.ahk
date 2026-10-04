#Requires AutoHotkey v2.0
#SingleInstance Force

; Win+Enter opens a new Alacritty window in the home directory.
#Enter::Run "C:\Program Files\Alacritty\alacritty.exe", EnvGet("USERPROFILE")

; Replace Windows' Alt+Esc window switching globally. Alacritty binds the
; internally sent F13 to ToggleViMode; physically press Alt+Esc.
; $ forces the keyboard hook and prevents synthetic keystrokes re-triggering it.
; SendEvent releases Alt for F13 and lets the app process modifier changes.
$!Esc::SendEvent "{F13}"
