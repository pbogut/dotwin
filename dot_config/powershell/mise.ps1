# Use mise's shims without launching mise or installing shell hooks at startup.
$miseDataDir = if ($env:MISE_DATA_DIR) {
    $env:MISE_DATA_DIR
} else {
    Join-Path $env:LOCALAPPDATA 'mise'
}
$miseShims = Join-Path $miseDataDir 'shims'
if (($env:PATH -split ';') -notcontains $miseShims) {
    $env:PATH = "$miseShims;$env:PATH"
}
