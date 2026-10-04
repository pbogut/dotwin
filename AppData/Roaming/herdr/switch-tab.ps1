param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 9)]
    [int]$Number
)

$ErrorActionPreference = 'Stop'
$herdr = if ($env:HERDR_BIN_PATH) { $env:HERDR_BIN_PATH } else { 'herdr.exe' }
$workspace = if ($env:HERDR_ACTIVE_WORKSPACE_ID) {
    $env:HERDR_ACTIVE_WORKSPACE_ID
} else {
    $env:HERDR_WORKSPACE_ID
}
if (-not $workspace) {
    throw 'No Herdr workspace context is available.'
}

function Invoke-Herdr {
    param([string[]]$Arguments)

    $output = & $herdr @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Herdr command failed: $($Arguments -join ' ')"
    }
    $response = ($output -join "`n") | ConvertFrom-Json
    if ($response.error) {
        throw $response.error.message
    }
    return $response.result
}

function Move-HerdrTab {
    param([string]$TabId, [int]$Index)

    # tab.move is a public socket method without a CLI wrapper in Herdr 0.9.3.
    $socket = $env:HERDR_SOCKET_PATH
    if (-not $socket) {
        $directory = if ($env:HERDR_CONFIG_PATH) {
            Split-Path -Parent $env:HERDR_CONFIG_PATH
        } else {
            Join-Path $env:APPDATA 'herdr'
        }
        if ($env:HERDR_SESSION -and $env:HERDR_SESSION -ne 'default') {
            $directory = Join-Path $directory "sessions\$env:HERDR_SESSION"
        }
        $socket = Join-Path $directory 'herdr.sock'
    }

    $pipe = [System.IO.Pipes.NamedPipeClientStream]::new(
        '.', $socket, [System.IO.Pipes.PipeDirection]::InOut,
        [System.IO.Pipes.PipeOptions]::Asynchronous
    )
    $reader = $null
    $writer = $null
    try {
        $pipe.Connect(3000)
        $writer = [System.IO.StreamWriter]::new($pipe, [System.Text.UTF8Encoding]::new($false))
        $writer.AutoFlush = $true
        $reader = [System.IO.StreamReader]::new($pipe)
        $request = @{
            id = [Guid]::NewGuid().ToString('N')
            method = 'tab.move'
            params = @{ tab_id = $TabId; insert_index = $Index }
        }
        $writer.WriteLine(($request | ConvertTo-Json -Depth 3 -Compress))
        $pending = $reader.ReadLineAsync()
        if (-not $pending.Wait(5000)) {
            throw 'Timed out reordering Herdr tabs.'
        }
        if (-not $pending.Result) {
            throw 'Herdr closed the connection while reordering tabs.'
        }
        $response = $pending.Result | ConvertFrom-Json
        if ($response.error) {
            throw $response.error.message
        }
        return $response.result
    } finally {
        if ($writer) { $writer.Dispose() }
        if ($reader) { $reader.Dispose() }
        $pipe.Dispose()
    }
}

# Serialize key repeats so two commands cannot create the same numbered tab.
$sha = [System.Security.Cryptography.SHA256]::Create()
try {
    $context = "$env:HERDR_SOCKET_PATH|$env:HERDR_SESSION|$workspace"
    $hash = [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($context))).Replace('-', '')
} finally {
    $sha.Dispose()
}
$mutex = New-Object System.Threading.Mutex($false, "Local\HerdrNumberedTab-$hash")
$locked = $false
try {
    try {
        $locked = $mutex.WaitOne(10000)
    } catch [System.Threading.AbandonedMutexException] {
        $locked = $true
    }
    if (-not $locked) {
        throw 'Timed out waiting for another tab shortcut.'
    }

    $tabs = (Invoke-Herdr -Arguments @('tab', 'list', '--workspace', $workspace)).tabs
    $tab = $tabs | Where-Object { $_.label -ceq "$Number" } | Select-Object -First 1
    if (-not $tab) {
        $tab = (Invoke-Herdr -Arguments @('tab', 'create', '--workspace', $workspace, '--label', "$Number", '--no-focus')).tab
    }

    # Put numbered tabs first, ascending; retain other tabs' relative order.
    $tabs = @((Invoke-Herdr -Arguments @('tab', 'list', '--workspace', $workspace)).tabs)
    $ordered = @($tabs | Where-Object { $_.label -cmatch '^[1-9]$' } | Sort-Object { [int]$_.label })
    $ordered += @($tabs | Where-Object { $_.label -cnotmatch '^[1-9]$' })
    for ($index = 0; $index -lt $ordered.Count; $index++) {
        if ($tabs[$index].tab_id -ne $ordered[$index].tab_id) {
            $tabs = @((Move-HerdrTab -TabId $ordered[$index].tab_id -Index $index).tabs)
        }
    }
    $null = Invoke-Herdr -Arguments @('tab', 'focus', $tab.tab_id)
} finally {
    if ($locked) { $mutex.ReleaseMutex() }
    $mutex.Dispose()
}
