function global:q {
    exit
}

function global:ccd {
    $sourcePath = & chezmoi source-path
    if ($LASTEXITCODE -ne 0 -or -not $sourcePath) {
        throw 'Could not determine the chezmoi source directory.'
    }
    Set-Location -LiteralPath $sourcePath
}
