# user
$global:DefaultUser = [System.Environment]::UserName
# Modules import
Import-Module posh-git
Import-Module oh-my-posh
Import-Module Get-ChildItemColor
Set-PoshPrompt -Theme agnosterplus

# sysAdmin creds
$da = Get-Credential 'DEMANT\a-krpl'
# Save credentials for future use
$da | Export-Clixml -Path c:\a.clixml
# permanent credential for automate use with CmdLets using "-Credential"
$PSDefaultParameterValues.Add("*:Credential",(Import-Clixml -Path C:\a.clixml))
# Use the saved credentials when needed
$savedCreds = Import-Clixml -Path C:\a.clixml

# $Hash = @{
#     'Admin'      = Get-Credential -Message 'Please enter administrative credentials'
#     'RemoteUser' = Get-Credential -Message 'Please enter remote user credentials'
#     'User'       = Get-Credential -Message 'Please enter user credentials'
# }
# $Hash | Export-Clixml -Path "${env:\userprofile}\Hash.Cred"
# # $Hash = Import-CliXml -Path "${env:\userprofile}\Hash.Cred"
# Invoke-Command -ComputerName Server01 -Credential $Hash.Admin -ScriptBlock {whoami}
# Invoke-Command -ComputerName Server01 -Credential $Hash.RemoteUser -ScriptBlock {whoami}
# Invoke-Command -ComputerName Server01 -Credential $Hash.User -ScriptBlock {whoami}

function switch-psuser {
    
    Param(
        [Parameter(Position=0)]
        [ValidateSet("adminsystem","administrator")]
        $User = "adminsystem"
    )

    switch($User)
    {
        'adminsystem'   { $username = "EMEA\krpl" ; $pw = "pw"}
        'administrator' { $username = "DEMANT\a-krpl" ; $pw = "pw" }
    }

    $password = $pw | ConvertTo-SecureString -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential -ArgumentList $username,$password
    New-PSSession -Credential $cred | Enter-PSSession
}

(Get-Host).Version
