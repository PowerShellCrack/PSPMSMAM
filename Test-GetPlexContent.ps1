<#
.SYNOPSIS
    Plex API to get information and automate processes
.DESCRIPTION
    This script uses Plex API to get information
.LINK
    https://github.com/Arcanemagus/plex-api/wiki/Plex.tv
    https://github.com/pkkid/python-plexapi/blob/master/plexapi/library.py
#>
#*=============================================
##* Runtime Function - REQUIRED
##*=============================================

#region FUNCTION: Check if running in ISE
Function Test-IsISE {
    # try...catch accounts for:
    # Set-StrictMode -Version latest
    try {
        return ($null -ne $psISE);
    }
    catch {
        return $false;
    }
}
#endregion

#region FUNCTION: Check if running in Visual Studio Code
Function Test-VSCode{
    if($env:TERM_PROGRAM -eq 'vscode') {
        return $true;
    }
    Else{
        return $false;
    }
}
#endregion

#region FUNCTION: Find script path for either ISE or console
Function Get-ScriptPath {
    <#
        .SYNOPSIS
            Finds the current script path even in ISE or VSC
        .LINK
            Test-VSCode
            Test-IsISE
    #>
    param(
        [switch]$Parent
    )

    Begin{}
    Process{
        if ($PSScriptRoot -eq "")
        {
            if (Test-IsISE)
            {
                $ScriptPath = $psISE.CurrentFile.FullPath
            }
            elseif(Test-VSCode){
                $context = $psEditor.GetEditorContext()
                $ScriptPath = $context.CurrentFile.Path
            }Else{
                $ScriptPath = (Get-location).Path
            }
        }
        else
        {
            $ScriptPath = $PSCommandPath
        }
    }
    End{

        If($Parent){
            Split-Path $ScriptPath -Parent
        }Else{
            $ScriptPath
        }
    }

}
#endregion
##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VARIABLES: Building paths & values
# Use function to get paths because Powershell ISE & other editors have different results
[string]$scriptPath = Get-ScriptPath
[string]$scriptName = [IO.Path]::GetFileNameWithoutExtension($scriptPath)
[string]$scriptRoot = Split-Path -Path $scriptPath -Parent

#Get paths
#Get required folder and File paths
[string]$ExtensionPath = Join-Path -Path $scriptRoot -ChildPath 'Extensions'
[string]$ConfigDir = Join-Path -Path $scriptRoot -ChildPath 'Configs'
[string]$LogDir = Join-Path $scriptRoot -ChildPath 'Logs'

#generate log file
$LogfileName = "$($scriptName)_$(Get-Date -Format 'yyyy-MM-dd_Thh-mm-ss-tt').log"
Try{Start-transcript "$LogDir\$LogfileName" -ErrorAction Stop}catch{Start-Transcript "$PSScriptRoot\$LogfileName"}
##*===============================================
##* FUNCTIONS
##*===============================================

#Import Script extensions
. "$ExtensionPath\HttpAPI.ps1"
. "$ExtensionPath\PlexAPI.ps1"

#===============================================
# CONFIGS
#===============================================
$Configs = [xml](Get-Content "$ConfigDir\Plex.xml")

## Variables: Toolkit Name
[string]$Global:PlexScriptName = $Configs.PlexConfigs.PlexScriptConfigs.Name
[string]$Global:PlexScriptFriendlyName = $Configs.PlexConfigs.PlexScriptConfigs.FriendlyName

## Variables: Script Info
[version]$Global:PlexScriptVersion = [version]$Configs.PlexConfigs.PlexScriptConfigs.Version
#generate new guid if version change: new-guid
[guid]$Global:PlexScriptGUID = $Configs.PlexConfigs.PlexScriptConfigs.GUID
[string]$PlexURLType = $Configs.PlexConfigs.UseURLType

switch($PlexURLType){
    "External" {$PlexURL = $Configs.PlexConfigs.ExternalURL}
    "Internal" {$PlexURL = $Configs.PlexConfigs.InternalURL}
}

$PlexCreds = Import-Clixml "$ConfigDir\PlexAuth.xml"
$PlexUser = $PlexCreds.UserName
$PlexPassword = $PlexCreds.GetNetworkCredential().Password
#===============================================
# MAIN
#===============================================
$PlexAuthToken = Get-PlexAuthToken -PlexUsername $PlexUser -PlexPassword $PlexPassword

#get all libraries
$tvArchivedShows = Get-PlexContentInLibrary -URI $PlexURL -PlexToken $PlexAuthToken -Filter '*Archives*' -Type Show
$tvArchivedShows | Select-Object title, studio, viewcount | Sort-Object @{e={$_.viewcount -as [int]}} -Descending

$tvkids = Get-PlexContentInLibrary -URI $PlexURL -PlexToken $PlexAuthToken -Filter '*Kids*' -Type Show
$tvkids | Select-Object title, studio, viewcount | Sort-Object @{e={$_.viewcount -as [int]}} -Descending

$tvshows = Get-PlexContentInLibrary -URI $PlexURL -PlexToken $PlexAuthToken -Filter '*All*' -Type Show
$tvshows | Select-Object title, studio, viewcount | Sort-Object @{e={$_.viewcount -as [int]}} -Descending

$tvpremium = Get-PlexContentInLibrary -URI $PlexURL -PlexToken $PlexAuthToken -Filter '*Premium*' -Type Show
$tvpremium | Select-Object title, studio, viewcount | Sort-Object @{e={$_.viewcount -as [int]}} -Descending

$RecentlyAdded = Get-PlexLibraries -URI $PlexURL -PlexToken $PlexAuthToken -Section New
$RecentlyAdded | Select-Object title, studio, viewcount | Sort-Object @{e={$_.viewcount -as [int]}} -Descending

#$PlexAdmin = Invoke-WebRequest "$PlexExternalURL/users/account" -Headers @{'accept'='application/json';'X-Plex-Token'=$PlexAuthToken}

$AllMovies = Get-PlexContentInLibrary -URI $PlexURL -PlexToken $PlexAuthToken -Filter '*Collection*' -Type Movie
$AllMovies | Select-Object title, studio, viewcount | Sort-Object @{e={$_.viewcount -as [int]}} -Descending

Stop-Transcript
