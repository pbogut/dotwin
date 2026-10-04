# Windows dotfiles

Managed with [chezmoi](https://www.chezmoi.io/). Apply changes with:

```powershell
chezmoi apply
```

## Encrypted files

Windows uses its own age identity and password, independent of the Linux
dotfiles. The password-protected identity is stored in Git as `key.txt.age`.
The unlocked identity stays local at `~/.config/chezmoi/age-key.txt`.
Chezmoi's built-in age support handles both file encryption and the
password-protected key; no separate age installation is required.

After cloning this repository, run:

```powershell
chezmoi init
chezmoi apply
```

The `read-source-state.pre` hook in `.chezmoi.toml.tmpl` runs
`scripts/age-key.ps1` before chezmoi reads managed files, including during
`add`, `diff`, and `apply`. If the local identity is missing, it prompts for
the Windows key password, validates the public recipient, and installs the
unlocked key with access limited to the current Windows account and SYSTEM.
Once unlocked, subsequent commands reuse the local key without prompting.
Hooks also run during dry runs, so a first `chezmoi diff` or dry run can unlock
the key. A failed unlock stops the command and removes temporary plaintext.

`key.txt.age` and the helper script are ignored as chezmoi destination files.
`.config/chezmoi/**` is also ignored, and `.gitignore` excludes plaintext key
filenames. Only the password-protected identity belongs in Git.

Add an existing file encrypted, for example:

```powershell
chezmoi add --encrypt "$env:USERPROFILE\.secrets.json"
```

Chezmoi stores an `encrypted_*.age` file in the source directory and decrypts it
when applying. The destination file remains plaintext for applications to use.
To edit the encrypted file and apply the result:

```powershell
chezmoi edit "$env:USERPROFILE\.secrets.json"
chezmoi apply "$env:USERPROFILE\.secrets.json"
```

For a file already managed as plaintext, run `chezmoi chattr +encrypted <path>`.
This encrypts the current source file; any plaintext in earlier Git commits
remains in Git history.

The initial password-protected key is created from the local Windows identity
with this command, run from the source directory (it refuses to overwrite an
existing `key.txt.age`):

```powershell
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File .\scripts\age-key.ps1 -Protect
```

This asks for a password and confirmation, then decrypts a temporary copy to
verify the backup with one more password prompt. Keep the Windows key password
available for new machines; the encrypted key in Git is the portable backup.

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

Press **Win+Enter** to open a new Alacritty window in your home directory,
using the existing Alacritty configuration. The shortcut launches
`C:\Program Files\Alacritty\alacritty.exe`.

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

The global configuration at `~/.config/mise/config.toml` is managed by
`dot_config/mise/config.toml`. It requests the latest Go, Herdr, OpenCode, and
Rust toolchains/apps. Edit its `[tools]` table to add or pin tools.

On every full `chezmoi apply`, installation runs in this order:

1. The existing WinGet hook installs mise if missing.
2. `run_before_10-rust-build-tools.cmd.tmpl` installs Visual Studio 2022 Build
   Tools with the C++ workload and recommended Windows SDK if C++ tools are missing.
   Existing Visual Studio C++ installations are reused. Installation may request
   elevation.
3. Chezmoi writes the managed configuration files.
4. `run_after_10-mise.cmd.tmpl` runs `mise upgrade --yes`, installing missing
   tools and upgrading configured tools within their requested versions.
5. `run_after_20-go-apps.cmd.tmpl` installs the Go applications listed below.
6. `run_after_30-cargo-apps.cmd.tmpl` installs the Cargo applications listed below.

These hooks run from your home directory to use the global mise configuration.
They refresh the inherited `PATH` from Windows' user and machine settings so a
newly installed mise is available in the same apply. Application installs use
`mise exec`, so they use mise's Go and Cargo without reopening the shell.
An installation failure stops the apply.

Both PowerShell profiles load `~/.config/powershell/mise.ps1` to activate
[mise](https://mise.jdx.dev/) when its executable is on `PATH`. Installed tools
are available immediately, and the custom prompt refreshes mise's environment
so project-specific tool versions follow the current directory. PowerShell 7
also refreshes on directory changes; Windows PowerShell 5.1 refreshes at the
next prompt.

After applying, reopen PowerShell or reload `. $PROFILE.CurrentUserAllHosts`.
Use `mise ls` to check configured tools and `mise doctor` to check activation.

## Go applications

`go-packages.json` is the shared list of Go package paths with version suffixes:

```json
[
  "github.com/pbogut/hackdeck@latest",
  "github.com/pbogut/hackdeck-discord@latest"
]
```

The Go hook runs `go install` for each entry on every full apply, after mise has
prepared Go. Add a package path with `@latest` or a pinned version to install
another application. Binaries go to Go's normal install location (`GOBIN`, or
`~/go/bin` by default); the managed mise config disables its version-specific
`GOBIN` override so the apps survive Go upgrades. Removing an entry does not
uninstall its binary.

## Cargo applications

`vban-mini` is a Rust application, installed from your Git repository rather
than through Go. `cargo-packages.json` lists Git URLs and package names:

```json
[
  {
    "Git": "https://github.com/pbogut/vban-mini",
    "Package": "vban-mini",
    "WindowsPortAudio": true
  }
]
```

The Cargo hook runs `cargo install --locked --git` for each entry on every full
apply. Cargo reuses an up-to-date installation and updates it when the Git
revision changes. Binaries go to Cargo's normal install location (`~/.cargo/bin`
by default). Removing an entry does not uninstall its binary. Both application
lists and the PowerShell installation helpers stay in the chezmoi source directory.

`WindowsPortAudio` enables the Windows build settings from vban-mini's Makefile:
the bundled `portaudio.lib`, its required system libraries, and the static MSVC
runtime. The hook keeps a source checkout and generated Cargo config under
`%LOCALAPPDATA%\chezmoi\cargo`, and installs the same Git revision as the library.
Omit this field for Rust applications that do not need these settings.

## Herdr

The configuration at `%APPDATA%\herdr\config.toml` binds these direct shortcuts:

| Shortcut | Tab label |
| --- | --- |
| Alt+J | 1 |
| Alt+K | 2 |
| Alt+L | 3 |
| Alt+; | 4 |
| Alt+M | 5 |
| Alt+, | 6 |
| Alt+. | 7 |
| Alt+/ | 8 |
| Alt+H | 9 |

Each shortcut switches to that numbered tab in the active workspace, creating
and focusing it if missing. The helper matches **tab labels**, so closing another
tab does not change the shortcuts, and jumping directly to 9 creates only tab 9.
Keep these tabs named `1` through `9`; renaming one frees its shortcut to create
a new numbered tab. New tabs use Herdr's configured shell and working-directory
policy. Every shortcut sorts numbered tabs ascending (`1` through `9`) before
other named tabs, preserving those other tabs' relative order. Repeated shortcuts
are serialized to avoid duplicate tabs.

Apply the configuration and PowerShell helper together, then reload Herdr:

```powershell
chezmoi apply "$env:APPDATA\herdr"
herdr server reload-config
```

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

The Go application hook installs `hackdeck` and `hackdeck-discord` on full applies.
The managed Windows Startup launcher starts `%USERPROFILE%\go\bin\hackdeck.exe`
in the background at sign-in. Run a full `chezmoi apply` to install the launcher.
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
