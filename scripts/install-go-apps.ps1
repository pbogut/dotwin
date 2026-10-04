$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'mise.ps1')

$packagesFile = Join-Path (Split-Path $PSScriptRoot -Parent) 'go-packages.json'
$packages = Get-Content -LiteralPath $packagesFile -Raw | ConvertFrom-Json
foreach ($package in $packages) {
    "Installing Go application: $package"
    & $mise -C $env:USERPROFILE --yes exec -- go install $package
    if ($LASTEXITCODE -ne 0) {
        throw "go install $package failed with exit code $LASTEXITCODE"
    }
}
