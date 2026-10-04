# Native stderr is diagnostic output, so keep logging rather than stopping on it.
$ErrorActionPreference = 'Continue'

$cargoHome = if ($env:CARGO_HOME) { $env:CARGO_HOME } else { Join-Path $env:USERPROFILE '.cargo' }
$executable = Join-Path $cargoHome 'bin\vban-mini.exe'
$log = Join-Path $env:USERPROFILE 'vban-mini.log'
Set-Content -LiteralPath $log -Value '' -Encoding UTF8

& $executable --stream-name Stream1 --diagnostics 2>&1 | ForEach-Object {
    $_.ToString() | Out-File -LiteralPath $log -Append -Encoding UTF8
}
exit $LASTEXITCODE
