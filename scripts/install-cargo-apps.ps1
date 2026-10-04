$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'mise.ps1')

$packagesFile = Join-Path (Split-Path $PSScriptRoot -Parent) 'cargo-packages.json'
$packages = Get-Content -LiteralPath $packagesFile -Raw | ConvertFrom-Json
foreach ($package in $packages) {
    "Installing Cargo application: $($package.Package)"
    $arguments = @('install', '--locked', '--git', $package.Git, $package.Package)
    if ($package.WindowsPortAudio) {
        # PortAudio cannot build itself on Windows. Use the repository's bundled
        # static library, with the same Cargo overrides as its Windows Make target.
        $cacheRoot = Join-Path $env:LOCALAPPDATA 'chezmoi\cargo'
        $sourceDir = Join-Path $cacheRoot $package.Package
        New-Item -ItemType Directory -Path $cacheRoot -Force | Out-Null
        if (Test-Path -LiteralPath $sourceDir) {
            & git -C $sourceDir fetch --depth 1 origin HEAD
            if ($LASTEXITCODE -ne 0) { throw 'Failed to fetch the bundled PortAudio library.' }
            & git -C $sourceDir checkout --detach FETCH_HEAD
        } else {
            & git clone --depth 1 -- $package.Git $sourceDir
        }
        if ($LASTEXITCODE -ne 0) { throw 'Failed to check out the bundled PortAudio library.' }
        if (-not (Test-Path -LiteralPath (Join-Path $sourceDir 'portaudio.lib'))) {
            throw "The repository for $($package.Package) does not contain portaudio.lib."
        }

        $configFile = Join-Path $cacheRoot "$($package.Package).toml"
        $libraryDir = $sourceDir.Replace('\', '/')
        $config = @"
[target.x86_64-pc-windows-msvc]
rustflags = ["-C", "target-feature=+crt-static"]

[target.x86_64-pc-windows-msvc.portaudio]
rustc-link-search = ["$libraryDir"]
rustc-link-lib = ["static=portaudio", "winmm", "ole32", "uuid", "setupapi", "dsound"]
"@
        [IO.File]::WriteAllText($configFile, $config, [Text.UTF8Encoding]::new($false))
        # Use the same revision for the Rust sources and their bundled library.
        $revision = & git -C $sourceDir rev-parse HEAD
        if ($LASTEXITCODE -ne 0) { throw 'Failed to resolve the PortAudio source revision.' }
        $arguments += @('--rev', $revision, '--target', 'x86_64-pc-windows-msvc', '--config', $configFile)
    }
    & $mise -C $env:USERPROFILE --yes exec -- cargo @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "cargo install $($package.Package) failed with exit code $LASTEXITCODE"
    }
}
