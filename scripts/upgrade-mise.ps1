$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'mise.ps1')

# Run from home so a project's mise.toml cannot override the global tool requests.
& $mise -C $env:USERPROFILE --yes upgrade
if ($LASTEXITCODE -ne 0) {
    throw "mise upgrade failed with exit code $LASTEXITCODE"
}
