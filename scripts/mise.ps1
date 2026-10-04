# Preserve the current process PATH and pick up tools installed earlier in this apply.
$paths = @(
    $env:PATH
    [Environment]::GetEnvironmentVariable('PATH', 'User')
    [Environment]::GetEnvironmentVariable('PATH', 'Machine')
)
$env:PATH = ($paths | Where-Object { $_ }) -join ';'

$mise = Get-Command mise.exe -CommandType Application -ErrorAction SilentlyContinue
if (-not $mise) {
    throw 'mise is required; install jdx.mise through the shared WinGet package list.'
}
$mise = $mise.Source
