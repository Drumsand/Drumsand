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
    # Theme name without extension, or a built-in theme name
    # If a file "<ThemeName>.omp.json" exists at the chosen path, it will be used.
    PoshThemeName         = 'froczh'

    # Where to look for your theme config file first.
    # $true  => use your PowerShell profile folder (portable, recommended)
    # $false => use LocalAppData OMP themes folder (machine-specific)
    PreferUserProfilePath = $true

    # Optional auto-update behavior (OFF by default; safer for profiles)
    AutoUpdateOhMyPosh    = $false

    # Controls header chatter (Write-Verbose) for troubleshooting
    VerboseBootstrap      = $false

    # Optional: allow creating the profile directory if missing
    EnsureProfileDir      = $true
}

# Splat cofig 4 module Verbose/ErrorAction/...
$DefaultParamConfig = @{
    EnableDefaults = $true

    Defaults = @(
        @{ Pattern = '*-Dba*' ; Params = @{ Verbose = $true } },
        @{ Pattern = 'Get-VM*'; Params = @{ Verbose = $true } }
        # @{ Pattern = 'Invoke-Sqlcmd*'; Params = @{ ErrorAction = 'Stop' } }
    )
}


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



# ------------------------------------------------------------
# From here down: import modules, define functions, etc.
# ------------------------------------------------------------


#functions
function switch-psuser {
    
    Param(
        [Parameter(Position=0)]
        [ValidateSet("adminsystem","administrator")]
        $User = "administrator"
    )

    switch($User)
    {
        # 'adminsystem'   { $username = "EMEA\krpl" ; $pw = "pw"}
        'administrator' { $username = "CHANGadminkryple" ; $pw = "pw" }
    }

    $password = $pw | ConvertTo-SecureString -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential -ArgumentList $username,$password
    New-PSSession -Credential $cred | Enter-PSSession
}

function Save-Cred {
    $da = @{
        'Admin'      = Get-Credential -Message 'Please enter administrative credentials'
        # 'RemoteUser' = Get-Credential -Message 'Please enter remote user credentials'
        'User'       = Get-Credential -Message 'Please enter user credentials'
    }
    # Save credentials for future use
    $da | Export-Clixml -Path "${env:\userprofile}\Hash.Cred"
	
	# permanent credential for automate use with CmdLets using "-Credential"
	$PSDefaultParameterValues.Add('*-Dba*:Credential',(Import-Clixml -Path "${env:\userprofile}\Hash.Cred").Admin)
	$PSDefaultParameterValues.Add('Get-Wmi*:Credential',(Import-Clixml -Path "${env:\userprofile}\Hash.Cred").Admin)
	$PSDefaultParameterValues.Add('Get-VM:Credential',(Import-Clixml -Path "${env:\userprofile}\Hash.Cred").Admin)
}

# sysAdmin/User creds

# Full path of the file
$fileCreds = "${env:\userprofile}\Hash.Cred"
#If the file does not exist, create it.
if (!(Test-Path -Path $fileCreds -PathType Leaf)) {
     try {
        Save-Cred
     }
     catch {
         throw $_.Exception.Message
     }
 }
# If the file already exists, show the message and do nothing.
 else {
     Write-Host "Credential CliXML file [$fileCreds] already exists."
 }

# would you kindly update your credentials
$updateCreds = Read-Host -Prompt "Would you kindly update your credentials?[y/n]"
if ( $updateCreds -match "[yY]" ) { 
    Save-Cred
}

# Use the saved credentials when needed
$aCreds = (Import-Clixml -Path "${env:\userprofile}\Hash.Cred").Admin
# $uCreds = (Import-Clixml -Path "${env:\userprofile}\Hash.Cred").User

# Invoke-Command -ComputerName KBNDBMGT02 -Credential $aCreds -ScriptBlock {$env:username}
# Invoke-Command -ComputerName KBNDBMGT02 -Credential $Hash.RemoteUser -ScriptBlock {whoami}
# Invoke-Command -ComputerName KBNDBMGT02 -Credential $uCreds -ScriptBlock {$env:username}


# environment details
(Get-Host).Version
# "`nEnvironemnt variables - Paths`n"
# $env:Path -split ";" | Sort-Object -Descending