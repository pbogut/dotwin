param([ValidateSet('Watch', 'Toggle')] [string] $Action = 'Watch')

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)

if (-not (Get-Module -ListAvailable AudioDeviceCmdlets)) {
    '{"label":"Audio module missing","label_size":25}'
    exit 1
}
Import-Module AudioDeviceCmdlets
if ($Action -eq 'Toggle') { Set-AudioDevice -PlaybackMuteToggle | Out-Null }

$last = ''
do {
    try {
        $muted = Get-AudioDevice -PlaybackMute
        $update = @{
            label = [string] (Get-AudioDevice -PlaybackVolume)
            label_size = 35
            icon_text = [string] [char] $(if ($muted) { 0xEEE8 } else { 0xF028 })
            icon_color = $(if ($muted) { '#ff0000' } else { '#ffffff' })
        }
    } catch {
        $update = @{ label = 'Audio unavailable'; label_size = 25 }
    }
    $json = $update | ConvertTo-Json -Compress
    if ($json -ne $last) { $json; $last = $json }
    if ($Action -eq 'Toggle') { break }
    Start-Sleep -Seconds 1
} while ($true)
