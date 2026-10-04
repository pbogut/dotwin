# Windows dotfiles

Managed with [chezmoi](https://www.chezmoi.io/). Apply changes with:

```powershell
chezmoi apply
```

## WinGet packages

`winget-packages.json` is the shared package list, initially containing
AutoHotkey v2 (`AutoHotkey.AutoHotkey`), mise (`jdx.mise`), and Mosquitto
(`EclipseFoundation.Mosquitto`). The list stays in the chezmoi source directory.

`run_before_00-winget.cmd.tmpl` imports the list on every full `chezmoi apply`,
before updating files. Missing apps are installed at the latest available
version; installed apps are skipped with `--no-upgrade`. Package and source
agreements are accepted automatically. Installation failures stop the apply.
WinGet must already be installed; some installers may request Windows elevation.

To add an app, find its ID with `winget search`, add an entry to `Packages`:

```json
{ "PackageIdentifier": "Publisher.PackageName" }
```

Then run `chezmoi apply`. Removing an entry does not uninstall the app.
The HackDeck-specific dependency hook also installs Mosquitto when applying
only the HackDeck directory.

## Alacritty hotkeys

Press **Alt+Esc** to enter Alacritty's vi/selection mode. AutoHotkey intercepts
the shortcut globally and sends F13 internally, which Alacritty binds
to `ToggleViMode`. This replaces Windows' Alt+Esc window-switching shortcut.
In vi mode, `v` starts a selection, movement keys extend it, and `y` copies it.

The managed script is
`%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\alacritty-hotkeys.ahk`,
so it starts at sign-in. `chezmoi apply` also starts or reloads it immediately;
`#SingleInstance Force` ensures only one copy runs. AutoHotkey v2 is installed
through the shared WinGet package list. Use its tray icon to reload or exit it.

## PowerShell prompt

The native PowerShell prompt mirrors the three-line Starship layout from
[`pbogut/dotfiles`](https://github.com/pbogut/dotfiles/blob/master/dot_config/starship.toml.tmpl):

```text
[14:23:08] [t 2.5s] PS
[pbogu@redeye] (…/.local/share/chezmoi) git:master
λ
```

The clock is green; brackets and the lambda are red; the hostname is yellow;
the path is cyan; and the Git branch is blue. Failed commands add a red status
on the first line. Command duration appears after two seconds. Home is shown
as `~`, long paths are shortened to the last three components, and a detached
Git HEAD shows its short commit hash. Git status checks are omitted, matching
the Linux configuration. `LF_LEVEL` and `YAZI_LEVEL` are shown when set.

No prompt package or Nerd Font is required. Both Windows PowerShell 5.1 and
PowerShell 7 profiles load `~/.config/powershell/prompt.ps1`. On first apply,
a script enables locally managed profiles with the current user's
`RemoteSigned` execution policy if it was unset or restricted.

Reopen PowerShell after applying, or reload the profile in an existing session:

```powershell
. $PROFILE.CurrentUserAllHosts
```

## PowerShell commands

`ccd` changes to the chezmoi source directory, as reported by `chezmoi source-path`.
Shared functions live in `dot_config/powershell/functions.ps1` and are loaded by
both PowerShell profiles.

## Mise

Both PowerShell profiles load `~/.config/powershell/mise.ps1` to activate
[mise](https://mise.jdx.dev/) when its executable is on `PATH`. Installed tools
are available immediately, and the custom prompt refreshes mise's environment
so project-specific tool versions follow the current directory. PowerShell 7
also refreshes on directory changes; Windows PowerShell 5.1 refreshes at the
next prompt.

After applying, reopen PowerShell or reload `. $PROFILE.CurrentUserAllHosts`.
Use `mise ls` to check configured tools and `mise doctor` to check activation.

## HackDeck

The Windows configuration preserves the Linux 7 x 4 grid and styling, with
four active buttons (positions are zero-based):

| Position | Button | Action |
| --- | --- | --- |
| Row 0, column 2 | Light | Toggle Tasmota `tasmota_31A3A8`, `Power1`; show ON/OFF |
| Row 0, column 3 | Audio | Toggle default playback mute; show volume and mute state |
| Row 2, column 1 | Steam clip | Send Ctrl+F11 to the currently focused game |
| Row 2, column 4 | Discord | Short-release mute; long-press deafen; show voice state |

HackDeck executes button commands through Windows PowerShell. Discord invokes
the existing `hackdeck-discord.exe`. Audio uses the `AudioDeviceCmdlets`
PowerShell module; the light uses the standard Mosquitto command-line clients.

### Install and apply

The existing `hackdeck` and `hackdeck-discord` installations are used.
`chezmoi apply` checks the audio and MQTT dependencies and installs missing
packages automatically:

- `AudioDeviceCmdlets` 3.1.0.2 from PowerShell Gallery, for the current user.
  The hook also installs the NuGet provider if needed.
- `EclipseFoundation.Mosquitto` through WinGet. Its standard machine-wide
  installer may request Windows elevation.

Existing installations are reused. The light script finds the Mosquitto
clients on `PATH`, through `MOSQUITTO_DIR`, or in the standard installation
directories, including immediately after installation.

Apply the configuration, scripts, and dependency-install hook together:

```powershell
chezmoi apply "$env:APPDATA\hackdeck"
```

Restart HackDeck after applying changes so its status commands are restarted:

```powershell
& "$env:USERPROFILE\go\bin\hackdeck.exe"
```

Use the desktop's address and port `8191` in the Macro Deck client.

### Local credentials

Discord reads the existing `%APPDATA%\hackdeck\hackdeck-discord.toml`. Its
client ID and secret remain local, and first authentication may require
authorization in Discord. Controls and status use that helper's existing
implementation.

The light reads `~/.secrets.json`, using the same structure as Linux:

```json
{
  "homeassistant": {
    "mqtt": {
      "host": "broker.example",
      "user": "your-mqtt-user",
      "pass": "your-mqtt-password"
    }
  }
}
```

An optional `port` field is supported; `host` is a hostname or IP address.
Set `HACKDECK_SECRETS_FILE` before starting HackDeck to use a different local
file. This file contains your local MQTT broker settings and credentials.

The light subscribes to `stat/tasmota_31A3A8/POWER1`, queries current state with
an empty `cmnd/tasmota_31A3A8/Power1` payload, and publishes a non-retained
`TOGGLE` on press. It resubscribes and queries state after reconnecting.

### Steam clips and checks

Steam must already be recording the game, with Ctrl+F11 assigned to save a
clip. The PowerShell script sends the shortcut without changing focus.
**Clip requested** confirms the shortcut was sent, not that Steam saved a clip.
The label returns to **Save clip** after 1.5 seconds. Recording status is omitted.
