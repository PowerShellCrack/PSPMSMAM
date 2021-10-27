<#
.SYNOPSIS
    Grabs duplicate movie folders
.DESCRIPTION
    Grabs duplicate movie folders and prompt for merge.
.NOTES

.LINK

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

##*===============================================
##* CONFIG
##*===============================================
#Get required folder and File paths
[string]$ConfigPath = Join-Path -Path $scriptRoot -ChildPath 'Configs'
[string]$LogDir = Join-Path $scriptRoot -ChildPath 'Logs'

# PARSE RADARR CONFIG FILE
[Xml.XmlDocument]$RadarrConfigFile = (Get-Content "$ConfigPath\Configs-Radarr.xml" -ReadCount 0) -replace "&","&amp;"
[Xml.XmlElement]$RadarrConfigs = $RadarrConfigFile.RadarrAutomation.RadarrConfig
[Xml.XmlElement]$RadarrSettings = $RadarrConfigFile.RadarrAutomation.GlobalSettings
[string]$MoviesDir = $RadarrSettings.MoviesRootPath

$LogfileName = "$($scriptName)_$(Get-Date -Format 'yyyy-MM-dd_Thh-mm-ss-tt').log"
Try{Start-transcript "$LogDir\$LogfileName" -ErrorAction Stop}catch{Start-Transcript "$PSScriptRoot\$LogfileName"}
#=======================================================
# MAIN
#=======================================================
$allfolders = Get-ChildItem $MoviesDir -directory -recurse

$EmptyFolders = $allfolders | Where { (Get-ChildItem $_.fullName).count -eq 0 } | select -expandproperty FullName

#get duplicate directories
#$DuplicateFolders =@()
$DuplicateHashtable = @{}
Foreach ($folder in $allfolders){
    $countfolders = $allfolders | Where{($folder.name -in $_.name)}
    If($countfolders.count -gt 1){
        #$DuplicateFolders += $countfolders.FullName

        $DuplicateHashtable."$($folder.name)" = @() #adds an array
        Foreach($paths in $countfolders){
            $DuplicateHashtable."$($folder.name)" += $paths.FullName
        }

    }
}

$DuplicateHashtable.Keys | % {

    $DestinationPath = $DuplicateHashtable.Item($_) | Out-GridView -PassThru -Title "Select destination to merge: $_"

    foreach($path in $DuplicateHashtable.Item($_) | Where {$_ -ne $DestinationPath}){
        If($DestinationPath){
            Write-host "moving folder [" -NoNewline
            Write-Host $path -ForegroundColor Green -NoNewline
            Write-host "] to [" -NoNewline
            Write-host $DestinationPath -ForegroundColor Green -NoNewline
            Write-host "]"
            Try{
                #$FinalPath = Split-Path $DestinationPath -Parent
                #Move-item $path $FinalPath -Force -ErrorAction Stop
                Get-ChildItem -Path $path -Recurse | Move-Item -Destination $DestinationPath -Force
                Remove-Item $path -Force
            }
            Catch{
                Write-host ("Unable to move [{0}]. {1}" -f $path,$error[0]) -ForegroundColor Red
            }
        }
        Else{
             Write-host "No Destination path selected for: $path" -ForegroundColor Red
        }
    }
}

Stop-Transcript