param([ValidateSet('Watch', 'Toggle')] [string] $Action = 'Watch')

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)

function Find-Mosquitto([string] $name) {
    $command = Get-Command $name -CommandType Application -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }
    $directories = @(
        $env:MOSQUITTO_DIR
        [Environment]::GetEnvironmentVariable('MOSQUITTO_DIR', 'Machine')
        (Join-Path $env:ProgramFiles 'Mosquitto')
    )
    if (${env:ProgramFiles(x86)}) {
        $directories += Join-Path ${env:ProgramFiles(x86)} 'Mosquitto'
    }
    foreach ($directory in $directories) {
        if (-not $directory) { continue }
        $path = Join-Path $directory $name
        if (Test-Path -LiteralPath $path) { return $path }
    }
    throw 'Mosquitto client tool was not found'
}

try {
    $pub = Find-Mosquitto 'mosquitto_pub.exe'
    $sub = Find-Mosquitto 'mosquitto_sub.exe'
} catch {
    '{"label":"MQTT tools missing","label_size":25}'
    exit 1
}

$path = Join-Path $env:USERPROFILE '.secrets.json'
if ($env:HACKDECK_SECRETS_FILE) { $path = $env:HACKDECK_SECRETS_FILE }
$last = ''
while ($true) {
    try {
        $mqtt = (Get-Content -LiteralPath $path -Raw | ConvertFrom-Json).homeassistant.mqtt
        if (-not $mqtt.host -or $mqtt.host -eq 'broker.example.invalid') {
            throw 'MQTT settings are placeholders'
        }
        $arguments = @('-h', [string] $mqtt.host)
        if ($mqtt.port) { $arguments += @('-p', [string] $mqtt.port) }
        if ($mqtt.user) { $arguments += @('-u', [string] $mqtt.user, '-P', [string] $mqtt.pass) }
        if ($Action -eq 'Toggle') {
            & $pub @arguments -t 'cmnd/tasmota_31A3A8/Power1' -m TOGGLE
            exit $LASTEXITCODE
        }

        # Subscribe first, then query without changing the light. The short-lived
        # publisher job allows the normal mosquitto_sub pipeline to stream state.
        $query = Start-Job -ArgumentList $pub, $arguments -ScriptBlock {
            param($executable, $mqttArguments)
            Start-Sleep -Seconds 1
            & $executable @mqttArguments -t 'cmnd/tasmota_31A3A8/Power1' -n
        }
        try {
            & $sub @arguments -t 'stat/tasmota_31A3A8/POWER1' 2>$null | ForEach-Object {
                $state = $_.Trim().ToUpperInvariant()
                if ($state -in @('ON', 'OFF')) {
                    $icon = $(if ($state -eq 'ON') { 0xF0335 } else { 0xF0336 })
                    @{ label = $state; label_size = 40; icon_text = [char]::ConvertFromUtf32($icon) } |
                        ConvertTo-Json -Compress
                }
            }
        } finally {
            Stop-Job $query -ErrorAction SilentlyContinue
            Remove-Job $query -Force -ErrorAction SilentlyContinue
        }
        $label = 'Offline'
    } catch {
        $label = 'MQTT settings needed'
    }
    $json = @{ label = $label; label_size = 25 } | ConvertTo-Json -Compress
    if ($json -ne $last) { $json; $last = $json }
    if ($Action -eq 'Toggle') { exit 1 }
    Start-Sleep -Seconds 5
}
