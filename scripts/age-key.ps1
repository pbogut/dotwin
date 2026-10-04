[CmdletBinding()]
param(
    [string]$IdentityPath = (Join-Path $HOME '.config\chezmoi\age-key.txt'),
    [string]$EncryptedKeyPath,
    [string]$Recipient = 'age1umq860ffxqdyj7z82rjgljykecan0cnre9yjprglx0a0s35f5efs0rj4yh',
    [switch]$Protect
)

$ErrorActionPreference = 'Stop'
if (-not $EncryptedKeyPath) {
    $EncryptedKeyPath = Join-Path (Split-Path $PSScriptRoot -Parent) 'key.txt.age'
}
$chezmoi = (Get-Command chezmoi -CommandType Application -ErrorAction Stop).Source

function Assert-Identity {
    param([string]$Path)

    $recipients = @(& $chezmoi age-keygen -y $Path)
    if ($LASTEXITCODE -ne 0 -or $Recipient -notin $recipients) {
        throw "The identity at '$Path' does not match this repository's age recipient."
    }
}

if ($Protect) {
    if (-not (Test-Path -LiteralPath $IdentityPath -PathType Leaf)) {
        throw "No Windows identity found at '$IdentityPath'."
    }
    Assert-Identity $IdentityPath
    if (Test-Path -LiteralPath $EncryptedKeyPath) {
        throw "'$EncryptedKeyPath' already exists; refusing to overwrite the encrypted key."
    }
    if (-not (Test-Path -LiteralPath (Split-Path $EncryptedKeyPath -Parent) -PathType Container)) {
        throw 'The encrypted key directory does not exist.'
    }
} elseif (Test-Path -LiteralPath $IdentityPath -PathType Leaf) {
    Assert-Identity $IdentityPath
    return
}

if (-not $Protect -and -not (Test-Path -LiteralPath $EncryptedKeyPath -PathType Leaf)) {
    throw "No password-protected key found at '$EncryptedKeyPath'."
}

$identityDirectory = Split-Path $IdentityPath -Parent
[void][System.IO.Directory]::CreateDirectory($identityDirectory)
$temporaryDirectory = Join-Path $identityDirectory ('.age-key-' + [guid]::NewGuid().ToString('N'))
$userSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
$systemSid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-18')

# Restrict the temporary directory before any plaintext is written into it.
$directoryAcl = [System.Security.AccessControl.DirectorySecurity]::new()
$directoryAcl.SetAccessRuleProtection($true, $false)
foreach ($sid in @($userSid, $systemSid)) {
    $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
        $sid, 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow'
    )
    $directoryAcl.AddAccessRule($rule)
}
[void][System.IO.Directory]::CreateDirectory($temporaryDirectory, $directoryAcl)
$temporaryIdentity = Join-Path $temporaryDirectory 'age-key.txt'

try {
    $encryptedInput = $EncryptedKeyPath
    if ($Protect) {
        $encryptedInput = Join-Path $temporaryDirectory 'key.txt.age'
        Write-Host 'Choose a password for the Windows key (independent of the Linux key).'
        & $chezmoi age encrypt --passphrase --output $encryptedInput $IdentityPath
        if ($LASTEXITCODE -ne 0) {
            throw 'Password-protecting the Windows key failed.'
        }
        Write-Host 'Enter the password again to verify the encrypted Windows key.'
    } else {
        Write-Host 'Unlocking the Windows chezmoi key with its password.'
    }
    & $chezmoi age decrypt --passphrase --output $temporaryIdentity $encryptedInput
    if ($LASTEXITCODE -ne 0) {
        throw 'Unlocking the Windows key failed; no identity was installed.'
    }
    Assert-Identity $temporaryIdentity

    if (-not $Protect) {
        $fileAcl = [System.Security.AccessControl.FileSecurity]::new()
        $fileAcl.SetAccessRuleProtection($true, $false)
        foreach ($sid in @($userSid, $systemSid)) {
            $fileAcl.AddAccessRule([System.Security.AccessControl.FileSystemAccessRule]::new(
                $sid, 'FullControl', 'Allow'
            ))
        }
        [System.IO.File]::SetAccessControl($temporaryIdentity, $fileAcl)
        [System.IO.File]::Move($temporaryIdentity, $IdentityPath)
        Write-Host "Windows key unlocked at '$IdentityPath'."
    } else {
        [System.IO.File]::Move($encryptedInput, $EncryptedKeyPath)
        Write-Host "Password-protected Windows key created and verified at '$EncryptedKeyPath'."
    }
} finally {
    [System.IO.Directory]::Delete($temporaryDirectory, $true)
}
