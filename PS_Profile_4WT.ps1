# user
$global:DefaultUser = [System.Environment]::UserName
# PoSh theme
$poShTh = "froczh" # "clean-detailed"
#paths
$env:Path += "
	;C:\Users\kryple\AppData\Local\Programs\oh-my-posh\;
	C:\Users\kryple\AppData\Local\Programs\oh-my-posh\themes\;
"
## Modules import
oh-my-posh init pwsh | Invoke-Expression
oh-my-posh init pwsh --config "C:\Users\kryple\AppData\Local\Programs\oh-my-posh\themes\$($poShTh).omp.json" | Invoke-Expression
Import-Module Get-ChildItemColor

#Add Verbose to specific commands
# set credentials usage for specific cmdlets
$PSDefaultParameterValues['*-Dba*:Verbose'] = $True
# $PSDefaultParameterValues['Get-WmiObject-*:Verbose'] = $True
$PSDefaultParameterValues['Get-VM:Verbose'] = $True

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