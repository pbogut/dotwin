#Requires AutoHotkey v2.0
#SingleInstance Force

; Windows reserves Win+L for locking unless manual workstation locking is disabled.
; This current-user policy persists after the script exits.
lockPolicyKey := "HKCU\Software\Microsoft\Windows\CurrentVersion\Policies\System"
if RegRead(lockPolicyKey, "DisableLockWorkstation", 0) != 1 {
    try RegWrite 1, "REG_DWORD", lockPolicyKey, "DisableLockWorkstation"
    catch OSError {
        ; Elevate only the registry command, not the hotkeys or apps they launch.
        RunWait('*RunAs "' A_WinDir '\System32\reg.exe" add "' lockPolicyKey
            '" /v DisableLockWorkstation /t REG_DWORD /d 1 /f',, "Hide")
    }
    if RegRead(lockPolicyKey, "DisableLockWorkstation", 0) != 1
        throw Error("Could not disable workstation locking; approve the registry command's UAC prompt and reload.")
}

; Win+Enter opens a new Alacritty window in the home directory.
#Enter::Run "C:\Program Files\Alacritty\alacritty.exe", EnvGet("USERPROFILE")

; Replace Windows' Alt+Esc window switching globally. Alacritty binds the
; internally sent F13 to ToggleViMode; physically press Alt+Esc.
; $ forces the keyboard hook and prevents synthetic keystrokes re-triggering it.
; SendEvent releases Alt for F13 and lets the app process modifier changes.
$!Esc::SendEvent "{F13}"
