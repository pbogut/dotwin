# Windows dotfiles

Managed with [chezmoi](https://www.chezmoi.io/). Apply changes with:

```powershell
chezmoi apply
```

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
