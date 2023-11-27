# array of modules to install (update) / variables
Clear-Host
$ErrorActionPreference  = "Continue"
# $debugPreference        = "Continue"
$sqlModule              = @("PowershellGet", "dbaTools", "sqlserver") #"PowershellGet", "dbaTools", "sqlserver"

#Splat

# Dynamically check/install/update Package Provider
Get-PackageProvider -Name "nuGet" -ForceBootstrap | 
    Select-Object -Property Name, Version | 
    Format-Table -Autosize

# Force install/update modules from PS Repositry
$sqlModule.ForEach( {if (-not (Get-Module -Name $_) ){
        Install-Module -Name $_ -Confirm:$False -Scope AllUsers -Force # -Verbose
        } else {
            Uninstall-Module -Name $_ -AllVersions -Force # -Verbose
            Install-Module -Name $_ -Confirm:$False -Scope AllUsers -Force # -Verbose
        }
    }
)

# disable "dbtools" notifications
Set-DbatoolsConfig -Name Import.SqlpsCheck -Value $false -PassThru | 
    Register-DbatoolsConfig
Set-DbatoolsConfig -Name Import.EncryptionMessageCheck -Value $false -PassThru |
    Register-DbatoolsConfig

# Import installed modules
$sqlModule.ForEach( {if(Get-Module -Name $_ -ListAvailable){
        Import-Module -Name $_ -Global -Force | Write-Host "Module $_ imported"
        } else {
            Write-Host "Module $_ not imported" -ForegroundColor Red -BackgroundColor White
        }
    }
)

# List modules
Get-Module | Where-Object {$_.Name -match ($sqlModule -join '|')} |
    Select-Object -Property Name, Version |
    Format-Table -AutoSize
