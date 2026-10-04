$ErrorActionPreference = 'Stop'

function Test-CppBuildTools {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (-not (Test-Path -LiteralPath $vswhere)) {
        return $false
    }
    $installation = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    return $LASTEXITCODE -eq 0 -and [bool]$installation
}

if (Test-CppBuildTools) {
    'Visual Studio C++ build tools already installed'
    exit 0
}

if (-not (Get-Command winget.exe -CommandType Application -ErrorAction SilentlyContinue)) {
    throw 'WinGet is required to install Visual Studio C++ build tools.'
}

& winget.exe install --id Microsoft.VisualStudio.2022.BuildTools --exact --source winget --force --accept-package-agreements --accept-source-agreements --disable-interactivity --override '--quiet --wait --norestart --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended'
if ($LASTEXITCODE -notin @(0, 3010)) {
    throw "Visual Studio Build Tools installation failed with exit code $LASTEXITCODE"
}
if (-not (Test-CppBuildTools)) {
    throw 'Visual Studio C++ build tools were not found after installation.'
}
'Installed Visual Studio C++ build tools and Windows SDK'
