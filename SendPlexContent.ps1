<#
.SYNOPSIS
    Plex API to get information and auotmate processes
.DESCRIPTION
    This script uses Plex API to get information
.LINK
    https://github.com/PowerShellCrack/PSPMSMAM
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
# Use function to get paths because Powershell ISE & other editors have differnt results
[string]$scriptPath = Get-ScriptPath
[string]$scriptName = [IO.Path]::GetFileNameWithoutExtension($scriptPath)
[string]$scriptRoot = Split-Path -Path $scriptPath -Parent

#Get paths
[string]$ExtensionPath = Join-Path -Path $scriptRoot -ChildPath 'Extensions'
[string]$ConfigPath = Join-Path -Path $scriptRoot -ChildPath 'Configs'
[string]$LogDir = Join-Path $scriptRoot -ChildPath 'Logs'
[string]$StoredDataDir = Join-Path $scriptRoot -ChildPath 'StoredData'

#generate log file
$LogfileName = "$($scriptName)_$(Get-Date -Format 'yyyy-MM-dd_Thh-mm-ss-tt').log"
Try{Start-transcript "$LogDir\$LogfileName" -ErrorAction Stop}catch{Start-Transcript "$PSScriptRoot\$LogfileName"}
##*===============================================
##* FUNCTIONS
##*===============================================

#Import Script extensions
. "$ExtensionPath\PlexAPI.ps1"

#===============================================
# DECLARE VARIABLES
#===============================================
[string]$GmailUser='<yourgmail>@gmail.com'
[string]$GmailPassword='<gmail app password>'
[string]$GmailServer='smtp.gmail.com'
[int32]$GmailPort=587
[bool]$GmailUseSSL=$True


$IgnoreEmailDNS = '<INGNORED EMAILS>'

#===============================================
# CONFIGS
#===============================================
$Configs = [xml](Get-Content "$ConfigDir\Configs-Plex.xml")

## Variables: Toolkit Name
[string]$Name = $Configs.PlexConfigs.PlexName
[string]$SupportURL = $Configs.PlexConfigs.PlexSupportURL

[string]$Global:PlexScriptName = $Configs.PlexConfigs.PlexScriptConfigs.Name
[string]$Global:PlexScriptFriendlyName = $Configs.PlexConfigs.PlexScriptConfigs.FriendlyName

## Variables: Script Info
[version]$Global:PlexScriptVersion = [version]$Configs.PlexConfigs.PlexScriptConfigs.Version
#generate new guid if version change: new-guid
[guid]$Global:PlexScriptGUID = $Configs.PlexConfigs.PlexScriptConfigs.GUID
[string]$plexScriptDate = $Configs.PlexConfigs.PlexScriptConfigs.Date
[hashtable]$plexScriptParameters = $PSBoundParameters
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

$sections = Get-PlexLibraries -localPlexAddr $PlexInternalURL -PlexToken $PlexAuthToken

$tvarchives = Get-PlexLibraries -localPlexAddr $PlexInternalURL -PlexToken $PlexAuthToken -CustomAddr 'library/sections/59/all'
$tvarchives | select title, studio, viewcount | Sort-Object @{e={$_.viewcount -as [int]}} -Descending

$tvkids = Get-PlexLibraries -localPlexAddr $PlexInternalURL -PlexToken $PlexAuthToken -CustomAddr 'library/sections/62/all'
$tvkids | select title, studio, viewcount | Sort-Object @{e={$_.viewcount -as [int]}} -Descending

$tvshows = Get-PlexLibraries -localPlexAddr $PlexInternalURL -PlexToken $PlexAuthToken -CustomAddr 'library/sections/47/all'
$tvshows | select title, studio, viewcount | Sort-Object @{e={$_.viewcount -as [int]}} -Descending

$tvpremium = Get-PlexLibraries -localPlexAddr $PlexInternalURL -PlexToken $PlexAuthToken -CustomAddr 'library/sections/30/all'
$tvpremium | select title, studio, viewcount | Sort-Object @{e={$_.viewcount -as [int]}} -Descending

$RecentlyAdded = Get-PlexLibraries -localPlexAddr $PlexInternalURL -PlexToken $PlexAuthToken -Section New

$PlexAdmin = Invoke-WebRequest "$PlexExternalURL/users/account" -Headers @{'accept'='application/json';'X-Plex-Token'=$PlexAuthToken}

$PlexFriends = Invoke-WebRequest "$PlexExternalURL/pms/friends/all" -Headers @{'accept'='application/json';'X-Plex-Token'=$PlexAuthToken}
$PlexFriendsContent = [xml]$PlexFriends.Content
[array]$PlexUsersArray = $PlexFriendsContent.MediaContainer.User

#build email list
#filter emails that are empty or in ignored dns list
$EmailList = @()
ForEach ($User in $PlexUsersArray){
    If($User.email -and ($User.email -notmatch $IgnoreEmailDNS)){
        Write-Host $User.email
        $EmailList += $User.username + " <" + $User.email + ">"

    }
}
#build authentication credentials
$secstr = convertto-securestring -String $GmailPassword -AsPlainText -Force
$GmailAuthCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $GmailUser, $secstr

<#build html body
$body = "Dear Plex Users,<br /><br />"
$body += "<p>Recently <i>Plex on Demand</i> lost its TV content due to hardware malfunction. Movie content may also be affected.</p>"
$body += "<p>Technicians are working hard to resolve the issue. Please be patient.</p>"
$body += "<p>Sorry for any inconvience.</p><br />"
$body += "<hr/>"
$body += "<p>This is an automated message from <a href="$SupportURL">$Name</a></p>"
#>
#build html body example
$body = "To my Plex customers,<br /><br />"
$body += "<p>A few days ago, My Plex server lost the hard drive for TV content due to a device malfunction. Movie's are available but with limited functionality.</p>"
$body += "<p>My new hard drive should be in today and I will begin to recover what I can. This can take some time.</p>"
$body += "<p>Dick</p><br />"
$body += "I will send an email once services has been restored. Sorry for any inconvenience."

Send-MailMessage -To $EmailList -From $Gmailuser -Subject "ATTENTION: Users of [$Name]" -Body $body -BodyAsHtml -SmtpServer $GmailServer -Port $GmailPort -UseSsl -Credential $GmailAuthCreds

Stop-Transcript