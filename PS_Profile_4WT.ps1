# ====================================
# Profile Configuration Header (Splat)
# ====================================

# Flotation
    #   Centralize settings in one hashtable (easy to tweak, easy to reuse)
    #   Bootstrap Oh My Posh safely:
    #       * no auto-install
    #       * optional auto-update (OFF by default)
    #       * configurable theme/config resolution
    #       * soft-fail (never breaks the shell)
    #   Keep the header readable and portable across machines/users

    #  Usage:
    #  Put this header at the top of your profile (.ps1)
    #  Call Initialize-OhMyPosh @ProfileConfig early (before other functions/modules)

# Splat config 4 OMP
$ProfileConfig = @{
    PoshThemeName         = 'froczh'    
    PreferUserProfilePath = $true   # $true  => use your PowerShell profile folder (portable, recommended)
                                    # $false => use LocalAppData OMP themes folder (machine-specific)
    AutoUpdateOhMyPosh    = $false  # Optional auto-update behavior (OFF by default; safer for profiles)
    VerboseBootstrap      = $false  # Controls header chatter (Write-Verbose) for troubleshooting
    EnsureProfileDir      = $true   # Optional: allow creating the profile directory if missing      

# Splat cofig 4 module Verbose/ErrorAction/...
$DefaultParamConfig = @{
    EnableDefaults = $true

    Defaults = @(
        @{ Pattern = '*-Dba*' ; Params = @{ Verbose = $true } },
        @{ Pattern = 'Get-VM*'; Params = @{ Verbose = $true } }
        # @{ Pattern = 'Invoke-Sqlcmd*'; Params = @{ ErrorAction = 'Stop' } }
    )
}

# Splat config 4 Paths and Aliases
$ProfileConfig = @{
    # Add these folders to PATH (session-scoped; put it in profile = "every session")
    Paths = @(
        'C:\Program Files\Notepad++'
        # 'C:\Tools\bin'
        # 'C:\Program Files\Git\cmd'
    )

    # Create functions that call executables and forward args safely
    Commands = @{
        npp = @{
            Exe = 'C:\Program Files\Notepad++\notepad++.exe'
        }
        # code = @{ Exe = 'C:\Users\YOU\AppData\Local\Programs\Microsoft VS Code\Code.exe' }
        # az   = @{ Exe = 'C:\Program Files\Microsoft SDKs\Azure\CLI2\wbin\az.cmd' }
    }
}

# # Splat config 4 function Secret Config (pass vault)
# $SecretConfig = @{
#     SecretName        = 'Profile.DefaultCredential'
#     VaultName         = 'LocalStore'
#     SetAsDefaultVault = $true
#     PromptForUpdate   = $true
#     UpdatePromptText  = 'Would you kindly update your credentials? [Y/N]'
# }



# ==========================================
# Helper: Verbose output gated by config
# ==========================================
function Write-BootstrapVerbose {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,

        [Parameter(Mandatory)]
        [string]$Message
    )

    if ($Config.VerboseBootstrap) {
        Write-Verbose $Message
    }
}

# =========================================================
# Initialize-OhMyPosh
# - designed for splatting: Initialize-OhMyPosh @ProfileConfig
# =========================================================
function Initialize-OhMyPosh {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PoshThemeName,

        [Parameter(Mandatory)]
        [bool]$PreferUserProfilePath,

        [Parameter(Mandatory)]
        [bool]$AutoUpdateOhMyPosh,

        [Parameter(Mandatory)]
        [bool]$VerboseBootstrap,

        [Parameter(Mandatory)]
        [bool]$EnsureProfileDir
    )

    # Re-hydrate a "config" hashtable inside the function so we can reuse the verbose helper
    $Config = @{
        VerboseBootstrap = $VerboseBootstrap
    }

    # ---------------------------------------------
    # Resolve PowerShell profile directory
    # ---------------------------------------------
    $ProfileDir = Split-Path -Parent $PROFILE.CurrentUserAllHosts

    if ($EnsureProfileDir -and -not (Test-Path $ProfileDir)) {
        try {
            New-Item -Path $ProfileDir -ItemType Directory -Force | Out-Null
            Write-BootstrapVerbose -Config $Config -Message "Created profile directory: $ProfileDir"
        }
        catch {
            Write-BootstrapVerbose -Config $Config -Message "Failed to create profile directory: $ProfileDir"
            # Soft-fail: keep going, we can still initialize OMP using theme name if available
        }
    }

    # ---------------------------------------------
    # Resolve OMP config path preference
    # ---------------------------------------------
    if ($PreferUserProfilePath) {
        # Recommended: store your custom theme config next to your profile scripts
        $PoshConfigPath = Join-Path $ProfileDir "$PoshThemeName.omp.json"
    }
    else {
        # Machine-specific fallback location (works if you keep configs there)
        $PoshConfigPath = Join-Path $env:LOCALAPPDATA "Programs\oh-my-posh\themes\$PoshThemeName.omp.json"
    }

    Write-BootstrapVerbose -Config $Config -Message "Resolved OMP config path: $PoshConfigPath"

    # ---------------------------------------------
    # Check if oh-my-posh is available
    # ---------------------------------------------
    $OmpCmd = Get-Command 'oh-my-posh' -ErrorAction SilentlyContinue
    if (-not $OmpCmd) {
        Write-BootstrapVerbose -Config $Config -Message "oh-my-posh not found in PATH. Skipping initialization."
        return
    }

    # ---------------------------------------------
    # Optional update (OFF by default)
    # ---------------------------------------------
    if ($AutoUpdateOhMyPosh) {
        $Winget = Get-Command 'winget' -ErrorAction SilentlyContinue

        try {
            if ($Winget) {
                Write-BootstrapVerbose -Config $Config -Message "Attempting update via winget..."
                & winget upgrade JanDeDobbeleer.OhMyPosh --source winget | Out-Null
            }
            else {
                Write-BootstrapVerbose -Config $Config -Message "winget not found. Trying: oh-my-posh upgrade"
                & oh-my-posh upgrade | Out-Null
            }
        }
        catch {
            Write-BootstrapVerbose -Config $Config -Message "oh-my-posh update attempt failed (ignored)."
        }
    }

    # ---------------------------------------------
    # Initialize prompt
    #    - If config file exists => use it
    #    - Else => fall back to the theme name directly
    # ---------------------------------------------
    try {
        if (Test-Path $PoshConfigPath) {
            Write-BootstrapVerbose -Config $Config -Message "Initializing oh-my-posh with config file..."
            oh-my-posh init pwsh --config $PoshConfigPath | Invoke-Expression
        }
        else {
            Write-BootstrapVerbose -Config $Config -Message "Config file not found. Initializing oh-my-posh with theme name..."
            oh-my-posh init pwsh --config $PoshThemeName | Invoke-Expression
        }
    }
    catch {
        # Soft-fail: never break the shell because the prompt failed
        Write-BootstrapVerbose -Config $Config -Message "oh-my-posh init failed (ignored)."
    }
}

# =========================
# Helpers (generic + reusable)
# =========================
function Add-PathEntry {
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    if (-not (Test-Path -LiteralPath $Path)) { return }

    $sep = [IO.Path]::PathSeparator  # ';' on Windows
    $current = ($env:PATH -split [Regex]::Escape($sep)) | Where-Object { $_ -ne '' }

    # Avoid duplicates (case-insensitive on Windows)
    if ($current -notcontains $Path) {
        $env:PATH = ($current + $Path) -join $sep
    }
}

function New-ExeCommand {
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $Exe
    )

    if (-not (Test-Path -LiteralPath $Exe)) { return }

    # Create a function in the global scope (so it’s available everywhere)
    $fn = @"
param([Parameter(ValueFromRemainingArguments=`$true)][object[]]`$Args)
& "$Exe" @Args
"@
    Set-Item -Path "Function:\global:$Name" -Value ([ScriptBlock]::Create($fn))
}


# # =========================================================
# # Ensure SecretManagement Module is installed
# #   designed for splatting: Initialize-OhMyPosh @ProfileConfig
# # =========================================================
# function Ensure-SecretModules {
#     [CmdletBinding()]
#     param(
#         [Parameter(Mandatory)]
#         [hashtable]$Config
#     )

#     foreach ($mod in 'Microsoft.PowerShell.SecretManagement','Microsoft.PowerShell.SecretStore') {
#         if (-not (Get-Module -ListAvailable -Name $mod)) {
#             Write-Warning "$mod not installed. Install it from PSGallery if you want secure credential storage."
#             return
#         }
#     }

#     Import-Module Microsoft.PowerShell.SecretManagement -ErrorAction SilentlyContinue
#     Import-Module Microsoft.PowerShell.SecretStore      -ErrorAction SilentlyContinue
# }

# # Ensure Vault registration
# function Ensure-SecretVault {
#     [CmdletBinding()]
#     param(
#         [Parameter(Mandatory)]
#         [hashtable]$Config
#     )

#     if (-not (Get-Command Get-SecretVault -ErrorAction SilentlyContinue)) { return }

#     $vault = Get-SecretVault -Name $Config.VaultName -ErrorAction SilentlyContinue

#     if (-not $vault) {
#         $registerSplat = @{
#             Name         = $Config.VaultName
#             ModuleName   = 'Microsoft.PowerShell.SecretStore'
#             DefaultVault = $Config.SetAsDefaultVault
#         }
#         Register-SecretVault @registerSplat | Out-Null
#     }
#     elseif ($Config.SetAsDefaultVault -and -not $vault.IsDefault) {
#         Set-SecretVaultDefault -Name $Config.VaultName
#     }
# }

# =============================
# Call bootstrap early
# =============================

# Call OMP ($ProfileConfig)
Initialize-OhMyPosh @ProfileConfig

# Call Verbose ($DefaultParamConfig)
function Set-ProfileDefaultParameters {
    [CmdletBinding()] 
        # [CmdletBinding()]: function behaves like a compiled cmdlet. It automatically supports common parameters.
    param([Parameter(Mandatory)][hashtable]$Config)

    if (-not $Config.EnableDefaults) { return }

    foreach ($rule in $Config.Defaults) {
        $pattern = $rule.Pattern
        foreach ($kvp in $rule.Params.GetEnumerator()) {
            $PSDefaultParameterValues["$pattern`:$($kvp.Key)"] = $kvp.Value
        }
    }
}

Set-ProfileDefaultParameters -Config $DefaultParamConfig

# Call Path and Aliases
foreach ($p in $ProfileConfig.Paths) {
    Add-PathEntry -Path $p
}

foreach ($name in $ProfileConfig.Commands.Keys) {
    $cmd = $ProfileConfig.Commands[$name]
    New-ExeCommand -Name $name -Exe $cmd.Exe
}

# # Call Credentials (secretManagement)
# function Read-YesNoOrSkip {
#     [CmdletBinding()]
#     param(
#         [Parameter(Mandatory)]
#         [string]$Prompt
#     )

#     $answer = Read-Host -Prompt $Prompt

#     if ([string]::IsNullOrWhiteSpace($answer)) {
#         return $null   # ENTER = skip
#     }

#     return ($answer -match '^[yY]')
# }

# # Call to update credentials (secretManagement)
# function Get-ProfileCredential {
#     [CmdletBinding()]
#     param(
#         [Parameter(Mandatory)]
#         [hashtable]$Config
#     )

#     if (-not (Get-Command Get-Secret -ErrorAction SilentlyContinue)) {
#         return $null
#     }

#     $existing = Get-Secret -Name $Config.SecretName -ErrorAction SilentlyContinue

#     if ($existing -and $Config.PromptForUpdate) {

#         $shouldUpdate = Read-YesNoOrSkip -Prompt $Config.UpdatePromptText

#         if ($null -eq $shouldUpdate) { return $existing }   # ENTER
#         if (-not $shouldUpdate)      { return $existing }   # N
#     }

#     if (-not $existing -or $shouldUpdate) {

#         $newCred = Get-Credential -Message 'Enter credentials to store securely in vault.'

#         if ($null -eq $newCred) {
#             return $existing
#         }

#         $setSplat = @{
#             Name        = $Config.SecretName
#             Secret      = $newCred
#             Vault       = $Config.VaultName
#             ErrorAction = 'Stop'
#         }

#         Set-Secret @setSplat
#         return $newCred
#     }

#     return $existing
# }




# ------------------------------------------------------------
# From here down: import modules, define functions, etc.
# ------------------------------------------------------------


# ------------------------------------------------------------
# environment details
# ------------------------------------------------------------
Write-Host "PS $($PSVersionTable.PSVersion) [$($PSVersionTable.PSEdition)] in $($Host.Name)" -ForegroundColor Cyan
# $env:Path -split ";" | Sort-Object -Descending