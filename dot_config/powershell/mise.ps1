# Activate mise before loading the custom prompt, which calls its environment hook.
$mise = Get-Command mise -CommandType Application -ErrorAction SilentlyContinue
if ($mise) {
    if ($PSVersionTable.PSVersion.Major -lt 7) {
        # PowerShell 5.1 refreshes at the prompt instead of on directory changes.
        $env:MISE_PWSH_CHPWD_WARNING = '0'
    }
    & $mise.Source activate pwsh | Out-String | Invoke-Expression
}
