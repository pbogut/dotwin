# Native adaptation of pbogut/dotfiles' Starship prompt.
# Keep this script ASCII-only so Windows PowerShell 5.1 reads it correctly.

function global:Get-DotwinPromptPath {
    param([string] $Path)

    $displayPath = $Path.Replace('\', '/')
    $homePath = $HOME.Replace('\', '/').TrimEnd('/')
    if ($displayPath.Equals($homePath, [StringComparison]::OrdinalIgnoreCase)) {
        return '~'
    }
    if ($displayPath.StartsWith($homePath + '/', [StringComparison]::OrdinalIgnoreCase)) {
        $displayPath = '~' + $displayPath.Substring($homePath.Length)
    }

    $parts = $displayPath -split '/'
    if ($parts.Count -gt 3) {
        return ([string][char]0x2026 + '/' + ($parts[-3..-1] -join '/'))
    }
    return $displayPath
}

function global:prompt {
    # Capture status before running any commands, including Git.
    $lastCommandSucceeded = $?
    $lastExitCode = $global:LASTEXITCODE
    # The custom prompt replaces mise's prompt wrapper; keep its PATH refresh.
    if (Test-Path Function:\_mise_hook) {
        _mise_hook
    }
    $location = Get-Location
    $lastCommand = Get-History -Count 1

    Write-Host ('[{0:HH:mm:ss}] ' -f (Get-Date)) -ForegroundColor Green -NoNewline
    if (-not $lastCommandSucceeded) {
        Write-Host '[error] ' -ForegroundColor Red -NoNewline
    }
    if ($lastCommand) {
        $duration = $lastCommand.EndExecutionTime - $lastCommand.StartExecutionTime
        if ($duration.TotalSeconds -ge 2) {
            $seconds = $duration.TotalSeconds.ToString('0.0', [cultureinfo]::InvariantCulture)
            Write-Host "[t ${seconds}s] " -ForegroundColor Yellow -NoNewline
        }
    }
    if ($env:LF_LEVEL) {
        Write-Host "lf[$env:LF_LEVEL] " -ForegroundColor Blue -NoNewline
    }
    if ($env:YAZI_LEVEL) {
        Write-Host "ya[$env:YAZI_LEVEL] " -ForegroundColor Magenta -NoNewline
    }
    Write-Host 'PS' -ForegroundColor White

    Write-Host '[' -ForegroundColor Red -NoNewline
    Write-Host ([Environment]::UserName) -ForegroundColor Gray -NoNewline
    Write-Host '@' -ForegroundColor Red -NoNewline
    Write-Host ([Environment]::MachineName.ToLowerInvariant()) -ForegroundColor Yellow -NoNewline
    Write-Host '] (' -ForegroundColor Red -NoNewline
    Write-Host (Get-DotwinPromptPath $location.Path) -ForegroundColor Cyan -NoNewline
    Write-Host ') ' -ForegroundColor Red -NoNewline

    $git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue
    if ($git -and $location.Provider.Name -eq 'FileSystem') {
        try {
            $branch = & $git.Source --no-optional-locks -C $location.Path branch --show-current 2>$null
            if ($global:LASTEXITCODE -eq 0) {
                if (-not $branch) {
                    # Detached HEAD: show the short commit hash instead.
                    $branch = & $git.Source --no-optional-locks -C $location.Path rev-parse --short HEAD 2>$null
                }
                if ($branch) {
                    Write-Host "git:$branch" -ForegroundColor Blue -NoNewline
                }
            }
        } catch {
            # An unavailable repository should not prevent drawing the prompt.
        } finally {
            $global:LASTEXITCODE = $lastExitCode
        }
    }

    Write-Host ''
    Write-Host ([string][char]0x03BB) -ForegroundColor Red -NoNewline
    return ' '
}
