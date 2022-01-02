<#
.SYNOPSIS
    Monitor and manage a Plex Media Server
.DESCRIPTION
    Monitor services and managed Plex video content

.NOTES

.LINK
    https://github.com/PowerShellCrack/PSPMSMAM
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


Function Resolve-ActualPath{
    [CmdletBinding()]
    param(
        [string]$FileName,
        [string]$WorkingPath,
        [Switch]$Parent
    )
    Write-Verbose ("Attempting to resolve filename: {0}" -f $FileName)
    If(Resolve-Path $FileName -ErrorAction SilentlyContinue){
        $FullPath = Resolve-Path $FileName
    }
    #If unable to resolve the file path try building path from workign path location
    Else{
        $FullPath = Join-Path -Path $WorkingPath -ChildPath $FileName
    }

    Write-Verbose ("Attempting to resolve with full path: {0}" -f $FullPath)
    #Try to resolve the path one more time using the fullpath set
    Try{
        $ResolvedPath = Resolve-Path $FullPath -ErrorAction $ErrorActionPreference
    }
    Catch{
        Write-Verbose ("Unable to resolve path: {0}: {1}" -f $FullPath,$_.Exception.Message)
        Throw ("{0}" -f $_.Exception.Message)
    }
    Finally{
        If($Parent){
            $Return = Split-Path $ResolvedPath -Parent
        }Else{
            $Return = $ResolvedPath
        }
        $Return
    }
}


##*=============================================
##* VARIABLE DECLARATION
##*=============================================
#region VARIABLES: Building paths & values
# Use function to get paths because Powershell ISE & other editors have differnt results
[string]$scriptPath = Get-ScriptPath
[string]$scriptName = [IO.Path]::GetFileNameWithoutExtension($scriptPath)
[string]$scriptRoot = Split-Path -Path $scriptPath -Parent

#Get required folder and File paths
[string]$ExtensionPath = Join-Path -Path $scriptRoot -ChildPath 'Extensions'
[string]$HelpersPath = Join-Path -Path $scriptRoot -ChildPath 'Helpers'
[string]$ConfigPath = Join-Path -Path $scriptRoot -ChildPath 'Configs'
[string]$LogDir = Join-Path $scriptRoot -ChildPath 'Logs'
[string]$StoredDataDir = Join-Path $scriptRoot -ChildPath 'StoredData'

##*===============================================
##* EXTENSIONS
##*===============================================
#Import Script extensions
. "$ExtensionPath\Logging.ps1"

. "$ExtensionPath\VideoParser.ps1"
. "$ExtensionPath\HttpAPI.ps1"
. "$ExtensionPath\INIAPI.ps1"
. "$ExtensionPath\ImdbMovieAPI.ps1"
. "$ExtensionPath\TmdbAPI.ps1"
. "$ExtensionPath\TauTulliAPI.ps1"
. "$ExtensionPath\RadarrAPI.ps1"
. "$ExtensionPath\PlexAPI.ps1"
. "$ExtensionPath\XmlRpc.ps1"

#import helpers
. "$HelpersPath\CleanFolders.ps1"
. "$HelpersPath\MovieSearch.ps1"


$LogfileName = "$($scriptName)_$(Get-Date -Format 'yyyy-MM-dd_Thh-mm-ss-tt').log"
Try{Start-transcript "$LogDir\$LogfileName" -ErrorAction Stop}catch{Start-Transcript "$PSScriptRoot\$LogfileName"}

# PARSE MAIN CONFIG FILE
#=================================================
[string]$AutomationXMLContent = (Get-Content "$ConfigPath\MediaServer.xml" -ReadCount 0) -replace "&","&amp;"
[Xml.XmlDocument]$AutomationConfigFile = $AutomationXMLContent
[Xml.XmlElement]$GlobalSettings = $AutomationConfigFile.AutomationConfig
[Xml.XmlElement]$GlobalSettings = $AutomationConfigFile.AutomationConfig
$ServicesToCheck = $GlobalSettings.ServiceCheck.service
$WebsToCheck = $GlobalSettings.WebCheck.Web
$ProcessesToCheck = $GlobalSettings.ProcessCheck.process

[string]$RadarrConfigFile = $GlobalSettings.SourceConfigs.Config | Where-Object Id -eq 'Radarr' | Select-Object -ExpandProperty ConfigFile

# PARSE PLEX CONFIG FILE
#=================================================
[string]$PlexConfigFile = $GlobalSettings.SourceConfigs.Config | Where-Object Id -eq 'Plex' | Select-Object -ExpandProperty ConfigFile
[Xml.XmlDocument]$PlexXMLContent = (Get-Content "$ConfigPath\$PlexConfigFile" -ReadCount 0) -replace "&","&amp;"

## Variables: Script Info
[string]$PlexScriptName = $PlexXMLContent.PlexConfigs.PlexScriptConfigs.Name
[string]$PlexScriptFriendlyName = $PlexXMLContent.PlexConfigs.PlexScriptConfigs.FriendlyName
[version]$PlexScriptVersion = [version]$PlexXMLContent.PlexConfigs.PlexScriptConfigs.Version

#generate new guid if version change: new-guid
[guid]$PlexScriptGUID = $PlexXMLContent.PlexConfigs.PlexScriptConfigs.GUID
[string]$plexScriptDate = $PlexXMLContent.PlexConfigs.PlexScriptConfigs.Date
[string]$PlexURLType = $PlexXMLContent.PlexConfigs.UseURLType

switch($PlexURLType){
    "External" {$PlexURL = $PlexXMLContent.PlexConfigs.ExternalURL}
    "Internal" {$PlexURL = $PlexXMLContent.PlexConfigs.InternalURL}
}

$PlexCredsFile = Resolve-ActualPath -FileName $PlexXMLContent.PlexConfigs.UserCredentials -WorkingPath $ConfigPath -ErrorAction SilentlyContinue
$PlexCreds = Import-Clixml $PlexCredsFile.Path
$PlexUser = $PlexCreds.UserName
$PlexPassword = $PlexCreds.GetNetworkCredential().Password

$PlexAuthToken = Get-PlexAuthToken -PlexUsername $PlexUser -PlexPassword $PlexPassword

# PARSE RADARR CONFIG FILE
#=================================================
[Xml.XmlDocument]$RadarrXMLContent = (Get-Content "$ConfigPath\$RadarrConfigFile" -ReadCount 0) -replace "&","&amp;"
[Xml.XmlElement]$RadarrConfigs = $RadarrXMLContent.RadarrAutomation.RadarrConfigs
[Xml.XmlElement]$RadarrSettings = $RadarrXMLContent.RadarrAutomation.GlobalSettings
[Xml.XmlElement]$NewMovieConfigs = $RadarrXMLContent.RadarrAutomation.MovieConfigs

#Global variables are used with API
[string]$Global:RadarrURL = $RadarrConfigs.InternalURL
[string]$Global:RadarrPort = $RadarrConfigs.Port
[string]$Global:RadarrAPIkey = $RadarrConfigs.API


[string]$OMDBAPI = $RadarrSettings.OMDBAPI
[string]$TMDBAPI = $RadarrSettings.TMDBAPI
[string[]]$VideoExtensions = $RadarrSettings.VideoExtensions.ext -split ','
[string[]]$VideoSupportFiles = $RadarrSettings.VideoSupportFiles.ext -split ','
[string]$SupportedLanguages = ($RadarrSettings.VideoSupportFiles.languages).split(',') -join '|'
[string]$MoviesDir = $RadarrSettings.MoviesRootPath

# Update Data Configs
[boolean]$ProcessMovies = -Not([boolean]::Parse($RadarrSettings.CheckStatusOnly))


[Boolean]$ProcessRequestedMovies = [Boolean]::Parse($NewMovieConfigs.MovetoGenreFolder)
[string]$MovieRequestsPath = $NewMovieConfigs.MovieRequestedMovePath
[string]$DownloadedMoviePath = $NewMovieConfigs.DownloadedMoviePath

# PARSE TAUTULLI CONFIG FILE - FUTURE USE
#=================================================
[string]$TautulliConfigFile = $GlobalSettings.SourceConfigs.Config | Where-Object Id -eq 'Tautulli' | Select-Object -ExpandProperty ConfigFile
[Xml.XmlDocument]$TautulliXMLContent = (Get-Content "$ConfigPath\$TautulliConfigFile" -ReadCount 0) -replace "&","&amp;"
[Xml.XmlElement]$TautulliConfigs = $TautulliXMLContent.TautulliConfigs
[Xml.XmlElement]$TautulliScriptConfigs = $TautulliXMLContent.TautulliConfigs.TautulliScriptConfigs
[string]$Global:TautulliAPIKey = $TautulliConfigs.TautulliAPI

#Get-TautulliInfo -apiKey $TautulliAPI -command get_activity

## CHECK SERVICES
#=================================================
#TEST $service =  $ServicesToCheck | Where Name -eq Tomcat9
Foreach($service in $ServicesToCheck)
{
    Write-Host ("Checking service [{0}] status..." -f $service.FriendlyName) -NoNewline
    $SystemService = Get-Service -Name $service.Name -ErrorAction SilentlyContinue

    If($SystemService)
    {
        If($SystemService.Status -eq $service.state){
            Write-Host ("exists and is currently running. [{0}]" -f $service.Name) -ForegroundColor Green
        }
        Else{
            Write-Host ("exists but is not running. [{0}]" -f $service.Name) -ForegroundColor Yellow
            Try{
                Write-Host ("  Attempting to start service [{0}]..." -f $service.Name) -NoNewline
                Start-Service $SystemService -ErrorAction Stop
            }
            Catch{
                Write-Host ("failed: [{0}]" -f $_.Exception.Message) -ForegroundColor Red
            }
        }

    }
    Else{
        Write-Host ("does not exist. Ignoring service check for [{0}]" -f $service.Name,$service.FriendlyName) -ForegroundColor Yellow
    }
}

## CHECK URLS
#=================================================
#TEST $Web =  $WebsToCheck | Where Name -eq "Local Resilio"
#TEST $Web =  $WebsToCheck | Where Name -eq "Remote Resilio"
#TEST $Web =  $WebsToCheck | Where Name -eq Organizr
#TEST $Web =  $WebsToCheck | Where Name -eq rTorrent
#TEST $Web =  $WebsToCheck | Where Name -eq Tautulli
Foreach($Web in $WebsToCheck)
{
    switch($Web.ConnectType)
    {

        'xmlRpc' {
            #$responselist = Invoke-RPCMethod -Uri "$SeedboxUrl/rutorrent/plugins/httprpc/action.php" -RequestBody $request -Credential $credentials
            $Cmdlet = 'Invoke-RPCMethod'
            If($Web.Config){

                If($WebConfig = Resolve-ActualPath -FileName $Web.config -WorkingPath $scriptRoot -ErrorAction SilentlyContinue){
                    [Xml.XmlDocument]$WebXMLConfigs = (Get-Content $WebConfig.Path -ReadCount 0) -replace "&","&amp;"
                    [Xml.XmlElement]$WebConfigs = $WebXMLConfigs.($Web.Name + 'Configs')
                    $WebParams = @{Uri = ($WebConfigs.ExternalURL + '/' + $WebConfigs.RPCPath)}

                    #Get request body
                    $bytes = [System.Text.Encoding]::Unicode.GetBytes($WebConfigs.RequestBody.'#cdata-section')
                    $request = [System.Text.Encoding]::ASCII.GetString($bytes)
                    $WebParams['Body'] = $request


                    If($WebConfigs.Credentials){

                        If($CredFile = Resolve-ActualPath -FileName $WebConfigs.Credentials -WorkingPath $scriptRoot -ErrorAction SilentlyContinue){
                            [System.Management.Automation.PSCredential]$Creds = Import-Clixml $CredFile.path
                            if ($Creds -ne [System.Management.Automation.PSCredential]::Empty) {
                                $WebParams['Credential'] = $Creds
                            }
                        }
                    }
                }
            }
        }

        'API'    {
            $Cmdlet = 'Invoke-WebRequest'
            If($Web.Config){

                If($WebConfig = Resolve-ActualPath -FileName $Web.config -WorkingPath $scriptRoot -ErrorAction SilentlyContinue){
                    [Xml.XmlDocument]$WebXMLConfigs = (Get-Content $WebConfig.Path -ReadCount 0) -replace "&","&amp;"
                    [Xml.XmlElement]$WebConfigs = $WebXMLConfigs.($Web.Name + 'Configs')
                    $WebParams = @{Uri = $WebConfigs.ExternalURL}

                    If($WebConfigs.Credentials){

                        If($CredFile = Resolve-ActualPath -FileName $WebConfigs.Credentials -WorkingPath $scriptRoot -ErrorAction SilentlyContinue){
                            [System.Management.Automation.PSCredential]$Creds = Import-Clixml $CredFile.Path
                            if ($Creds -ne [System.Management.Automation.PSCredential]::Empty) {
                                $WebParams['Credential'] = $Creds
                            }
                        }
                    }
                }
            }
        }

        default  {
            $Cmdlet = 'Invoke-WebRequest'
            $WebParams = @{Uri = $Web.uri}
            If($Web.Credentials){

                If($CredFile = Resolve-ActualPath -FileName $Web.Credentials -WorkingPath $scriptRoot -ErrorAction SilentlyContinue){
                    [System.Management.Automation.PSCredential]$Creds = Import-Clixml $CredFile.Path
                    if ($Creds -ne [System.Management.Automation.PSCredential]::Empty) {
                        $WebParams['Credential'] = $Creds
                    }
                }
            }

        }


    }

    $ignoredCodes = @()
    If($Web.IgnoreCodes){
        $ignoredCodes += ($Web.IgnoreCodes).split(',')
    }

    $Response = $False
    Try
    {
        Write-Host ("Testing [{0}] web url [{1}]..." -f $Web.Name, $WebParams.URI) -NoNewline
        If($Cmdlet -eq 'Invoke-RPCMethod'){
            $Response = Invoke-RPCMethod @WebParams -ErrorAction Stop -TimeoutSec 30
        }
        Else{
            $Response = Invoke-WebRequest @WebParams -ErrorAction Stop -TimeoutSec 30
        }
    }
    Catch [System.Net.WebException]
    {
        #Write-Host ("{0}" -f $_.Exception.Message) -ForegroundColor Red
    }
    Finally
    {
        If($Response.StatusCode -eq '200'){
            Write-Host ("is currently available." -f $Web.Name, $WebParams.URI) -ForegroundColor Green
        }
        ElseIf($Response.StatusCode -in $ignoredCodes){
            Write-Host ("is currently available." -f $Web.Name, $WebParams.URI) -ForegroundColor Yellow
        }
        Else{
            Write-Host ("isn't currently available." -f $Web.Name, $WebParams.URI) -ForegroundColor Red
        }
        #clear incase differnet attributes are used in next iteration
        $WebParams = $null
    }
}

## BUILD GENRE MAPPINGS
##---------------------
#add folder paths to each genre tag
$MoviesGenreMappings = @{}
[PSCustomObject]$MoviesGenreMappings = $NewMovieConfigs.GenreMappings.Map
Foreach($genre in $MoviesGenreMappings){
    #$FolderPath = Get-ChildItem $MoviesDir | Where Name -eq $genre.BindingFolder | Select -First 1
    $FolderPath = Join-Path -Path $MoviesDir -ChildPath $genre.BindingFolder
    If($FolderPath){
        $MoviesGenreMappings | Where-Object Tag -eq $genre.Tag | Add-Member -MemberType NoteProperty -Name 'FolderPath' -Value $FolderPath -Force
    }
}


## CHECK DOWNLOAD FOLDER FOR VIDEOS
##---------------------------------
#TEST $DownloadedMoviePath = 'D:\Data\Downloads\sync'
#get all download files that are videos
$DownloadedFiles = Get-ChildItem -Path $DownloadedMoviePath -Recurse | Where {$_.PSIsContainer -eq $false -and $_.Extension -in $VideoExtensions}
#$DownloadedFiles.Fullname

#determine which ones are movies (regex example: movie.name.1999....)
$DownloadedMovies = $DownloadedFiles | Where {$_.name -match "([ .\w']+?)(\W\d{4}\W?.*)" -and $_.name -notmatch "^.*S\d\dE\d\d"}
#$DownloadedMovies.Fullname

#determine which ones are tv shows
$DownloadedTvShows = $DownloadedFiles | Where {$_.name -match "^.*S\d\dE\d\d"}
#$DownloadedTvShows.Fullname

#$RequestedMovies = Get-ChildItem -Path $MovieRequestsPath -Directory
$RequestedMovies = Get-ChildItem -LiteralPath $MovieRequestsPath -Recurse | Where {$_.PSIsContainer -eq $false -and $_.Extension -in $VideoExtensions}
#$RequestedMovies.Fullname

If($DownloadedMovies.Count -gt 0 -or $RequestedMovies.Count -gt 0){
    # Get all movies in Radarr (this is required for additonal details)
    $ExistingRadarrMovies = Get-RadarrMovies
}

$NewMovies = $DownloadedMovies + $RequestedMovies


$NewMovieInfoMappings = @()

## CHECK FOR NEW MOVIES
##---------------------
#$NewMovie = $NewMovies[0]
Foreach($NewMovie in $NewMovies)
{
    $FileInfo = "" | Select SourcePath,Size,SourceFileName,SourceFilePath
    $FileInfo.SourcePath = (Split-Path $NewMovie.FullName -Parent)
    $FileInfo.SourceFilePath = $NewMovie.FullName
    $FileInfo.SourceFileName = $NewMovie.Name
    $FileInfo.Size = $NewMovie.Length
    Write-Host ("---------------------------------------------------------") -ForegroundColor Cyan
    Write-Host ("Parsing movie from file name [{0}]... " -f $NewMovie.name) -ForegroundColor Cyan
    $MovieInfo = ConvertTo-MovieData -Value $NewMovie.Name

    <#
    If($NewMovie.movieFile.path){
        Write-Host ("existing file path [{0}]... " -f $NewMovie.movieFile.path)
        $MovieInfo = ConvertTo-MovieData -Value (Split-Path $NewMovie.movieFile.path -Leaf)
        $FileInfo
    }
    Elseif($NewMovie.Title){
        Write-Host ("existing data object [{0}]... " -f $NewMovie.title)
        $MovieInfo = ConvertTo-MovieData -Value $NewMovie.Title
    }
    Else{
        Write-Host ("file name [{0}]... " -f $NewMovie.name)
        $MovieInfo = ConvertTo-MovieData -Value $NewMovie.Name
        $CurrentLocation
    }
    #>

    $MultipleObjectsParams = @{
        Object1 = $MovieInfo
        Object2 = $FileInfo
    }

    #$MovieInfo = ConvertTo-MovieData -Value ($NewMovies | Where name -like "*die.another.day*").Name
    #$MovieInfo = ConvertTo-MovieData -Value ($NewMovies | Where name -like "*Venom.Let.There.Be.Carnage*").Name
    $OnlineMovie = Search-MovieTitle -Title $MovieInfo.Title -Year $MovieInfo.Year -IMDBApiKey $OMDBAPI -TMDBApiKey $TMDBAPI

    #grab movie details

    If($OnlineMovie){

        $MovieDetails = "" | Select OnlineimdbID,OnlinetmdbID,OnlinePoster
        $MovieDetails.OnlineimdbID = $OnlineMovie.imdbID
        $MovieDetails.OnlinetmdbID = $OnlineMovie.tmdbID
        $MovieDetails.OnlinePoster = $OnlineMovie.Poster
        #Add detial to params
        $MultipleObjectsParams += @{Object3 = $MovieDetails}

        #Update movie title and year based on online find (its more accurate)
        $MovieInfo.Title = $OnlineMovie.Title
        $MovieInfo.Year = $OnlineMovie.Year
    }

    [array]$genres = $NewMovie.genres -split ','

    If($genres.count -eq 0){[array]$genres = ($OnlineMovie.Genres -split ',').Trim() | Select -Unique}

    $MatchedMapping = $null
    #$Map = $MoviesGenreMappings[0]
    Foreach($Map in $MoviesGenreMappings)
    {
        If($null -eq $MatchedMapping)
        {
            $Property = $Map.Property
            $CompareValue = $Map.Tag
            $PropertyValue = $null

            If($Property -eq 'name')
            {
                $UseObject = $NewMovie
                If($UseObject.movieFile.path){
                    $PropertyValue = (Split-Path $UseObject.movieFile.path -leaf)
                }
            }
            ElseIf($Property -eq 'format')
            {
                $UseObject = $MovieInfo
                $PropertyValue = $UseObject.Format
            }
            ElseIf($Property -eq 'genre')
            {
                $Property = 'genres'
                If($NewMovie.genres){
                    $UseObject = $NewMovie
                }
                Else{
                    $UseObject = $OnlineMovie
                }
                $PropertyValue = $UseObject.genres -join '|'
            }
            Else{
                $UseObject = $NewMovie
                $PropertyValue = $UseObject.$Property
            }

            If($null -eq $PropertyValue){
                Write-Host ("    Movie property [{0}] does not exist, question skipped... " -f $Property) -ForegroundColor Yellow
            }
            ElseIf( [string]::IsNullOrEmpty($UseObject.$Property) ){
                Write-Host ("    Movie property [{0}] does not have a value, question skipped... " -f $Property) -ForegroundColor Yellow
            }
            ElseIf($PropertyValue -match '\|'){
                Write-Host ("    Does movie property [{0}] with value of [{1}] match [{2}]? " -f $Property,($PropertyValue | Trim-Length 125 -Traildots), $CompareValue) -NoNewline
                If($Map.Tag -match $PropertyValue){
                    Write-Host 'Yes' -ForegroundColor Green
                    $MatchedMapping = $Map
                    $MultipleObjectsParams += @{Object4 = $Map}
                }
                Else{
                    Write-Host 'No' -ForegroundColor Red
                }
            }
            ElseIf($Map.Tag -match '\*'){
                Write-Host ("    Does movie property [{0}] with value of [{1}] like [{2}]? " -f $Property,($PropertyValue | Trim-Length 125 -Traildots), $CompareValue) -NoNewline
                If($PropertyValue -like $CompareValue){
                    Write-Host 'Yes' -ForegroundColor Green
                    $MatchedMapping = $Map
                    $MultipleObjectsParams += @{Object4 = $Map}
                }
                Else{
                    Write-Host 'No' -ForegroundColor Red
                }

            }
            Else{
                Write-Host ("    Does movie property [{0}] with value of [{1}] equal [{2}]? " -f $Property,($PropertyValue | Trim-Length 125 -Traildots), $CompareValue) -NoNewline
                If($PropertyValue -eq $CompareValue){
                    Write-Host 'Yes' -ForegroundColor Green
                    $MatchedMapping = $Map
                    $MultipleObjectsParams += @{Object4 = $Map}
                }
                Else{
                    Write-Host 'No' -ForegroundColor Red
                }
            }
        }


    }#end genre mapping loop

    #If Mapping does not exist, build default mapping to request folder.
    If($MatchedMapping)
    {
        Write-Host ("[{0}] will be mapped to [{1}]" -f $UseObject.title,$MatchedMapping.FolderPath) -ForegroundColor Green
    }
    Else{
        Write-Host ("Unable to map [{0}] to a folder location" -f $UseObject.title) -ForegroundColor White -BackgroundColor Red
        $MatchedMapping = "" | Select FolderPath
        $MatchedMapping.FolderPath = $MatchedMapping
    }
    #$MultipleObjectsParams += @{Object4 = $MatchedMapping}

    $NewMovieInfoMappings += Merge-MultipleObjects @MultipleObjectsParams
}#end movie loop


#$NewMovieInfoMappings

## GET RADARR ACTIONS
##---------------------
If($NewMovieInfoMappings.Count -gt 0)
{
    $NewRadarrMovieActions = @()

    #TEST $NewRadarrMovie = $NewMovieInfoMappings[0]
    #TEST $NewRadarrMovie = $NewMovieInfoMappings[1]
    #TEST $NewRadarrMovie = $NewMovieInfoMappings[2]
    #TEST $NewRadarrMovie = $NewMovieInfoMappings[-1]
    Foreach($NewRadarrMovie in $NewMovieInfoMappings)
    {
        #create radarr object
        $MovieJob = "" | Select RadarrMovieStatus,FileAction,RadarrAction,RadarrFilePath,RadarrFileStatus,RadarrNewFolderPath,SupportFileAction,SupportFilesPath

        Write-Host ("----------------------------------------------------------") -ForegroundColor Cyan
        Write-Host ("Determining actions for new movie [{0}]... " -f $NewRadarrMovie.Title) -ForegroundColor Cyan

        #Assume if on srt file exists; its engligh unless it named otherwise
        $SupportFiles = @()
        $SupportFiles = Get-ChildItem -LiteralPath $NewRadarrMovie.SourcePath | Where-Object {$_.PSIsContainer -eq $false -and $_.Extension -in $VideoSupportFiles}
        If($SupportFiles.count -gt 1){
            $SupportFiles = $SupportFiles | Where-Object $_.BaseName -match $SupportedLanguages
            $MovieJob.SupportFileAction = 'Move'
        }
        $MovieJob.SupportFilesPath = $SupportFiles.FullName

        #Remove any other files that are not video related
        Get-childitem -LiteralPath $workingpath -Recurse |
        Where-Object {$_.PSIsContainer -eq $false -and $_.BaseName -notin $SupportFiles.BaseName -and $_.Extension -notin $VideoExtensions -and `
                                                    ($_.Extension -notin $VideoSupportFiles -or $_.BaseName -notmatch $SupportedLanguages)} |
                                                    Remove-Item -Force -ErrorAction SilentlyContinue -WhatIf

        #TEST $ExistingRadarrMovies | Where {($_.title -like '*Shang*')}
        Write-Host ("    Does movie entry [{0}] already exist in Radarr? " -f $NewRadarrMovie.Title) -NoNewline
        $MovieInRadarr = $ExistingRadarrMovies | Where {($_.title -eq $NewRadarrMovie.Title -or $_.sortTitle -eq $NewRadarrMovie.Title) -and $_.year -eq $NewRadarrMovie.Year}
        If($MovieInRadarr){
            Write-Host 'Yes' -ForegroundColor Green
            $MovieJob.RadarrMovieStatus = 'Exist'
        }
        Else{
            Write-Host 'No' -ForegroundColor Red
            $MovieJob.RadarrMovieStatus = 'NotExist'
        }

        If($MovieJob.RadarrMovieStatus -eq 'Exist'){
            Write-Host ("    Is there a movie file that exist with Radarr entry [{0}]? " -f $NewRadarrMovie.Title) -NoNewline
            If($MovieInRadarr.movieFile.Path){
                $MovieJob.RadarrFilePath = $MovieInRadarr.movieFile.Path

                If(Test-Path $MovieInRadarr.movieFile.Path){
                   Write-Host 'Yes' -ForegroundColor Green
                }
                Else{
                    Write-Host 'Missing' -ForegroundColor Red
                    $MovieJob.FileAction = 'Move'
                    $MovieJob.RadarrAction = 'Update'
                    $MovieJob.RadarrFileStatus = 'Missing'
                }
            }
            Else{
                Write-Host 'No' -ForegroundColor Red
                $MovieJob.FileAction = 'Move'
                $MovieJob.RadarrAction = 'Update'
                $MovieJob.RadarrFileStatus = 'Missing'
            }

            If($MovieJob.RadarrFileStatus -ne 'Missing')
            {
                Write-Host ("    Is the movie file path in the right location? [{0}]? " -f $NewRadarrMovie.FolderPath) -NoNewline
                If( (Split-Path $MovieInRadarr.movieFile.Path -Parent) -eq $NewRadarrMovie.FolderPath  ){
                    Write-Host 'Yes' -ForegroundColor Green
                }
                Else{
                    Write-Host 'No' -ForegroundColor Red
                    $MovieJob.FileAction = 'Move'
                    $MovieJob.RadarrAction = 'Update'
                    $MovieJob.RadarrFilePath = (Join-path $NewRadarrMovie.FolderPath -ChildPath $NewRadarrMovie.FileName)
                }

                Write-Host ("    Is there a language file that exist with Radarr entry [{0}]? " -f $NewRadarrMovie.Title) -NoNewline
                $RadarrSupportFile = Get-ChildItem -LiteralPath $MovieInRadarr.movieFile.Path | Where-Object {$_.PSIsContainer -eq $false -and $_.Extension -in $VideoSupportFiles}
                If($RadarrSupportFile.count -gt 0){
                    Write-Host 'Yes' -ForegroundColor Green
                    $MovieJob.SupportFilesPath = $RadarrSupportFile.FullName
                    $MovieJob.SupportFileAction = 'Move'
                }
                Else{
                    Write-Host 'No' -ForegroundColor Red
                    $MovieJob.SupportFileAction = 'Move'
                }


                Write-Host ("    Is the movie file that exist in Radarr the same [{0}]? " -f $MovieInRadarr.movieFile.relativePath) -NoNewline
                If($MovieInRadarr.movieFile.size -eq $NewRadarrMovie.FileSize){
                    Write-Host ('size is the same [{0}]. Will delete new movie file' -f $MovieInRadarr.movieFile.size) -ForegroundColor Red
                    $MovieJob.FileAction = 'Delete'
                    $MovieJob.RadarrAction = 'None'
                }
                ElseIf($MovieInRadarr.movieFile.size -gt $NewRadarrMovie.FileSize){
                    Write-Host ('size is larger [{0}]. Will delete new movie file' -f $MovieInRadarr.movieFile.size) -ForegroundColor Red
                    $MovieJob.FileAction = 'Delete'
                    $MovieJob.RadarrAction = 'None'
                }
                Else{
                    Write-Host ('size is smaller. Updating Radarr file with new movie [{0}]' -f $NewRadarrMovie.FileName) -ForegroundColor Yellow
                    $MovieJob.FileAction = 'Move'
                    $MovieJob.RadarrAction = 'Update'
                    $MovieJob.RadarrNewFolderPath = Join-path $NewRadarrMovie.FolderPath -ChildPath $NewRadarrMovie.SimpleTitle
                }
            }
            Else{
                Write-Host ('No movie file exists. updating Radarr file with new movie [{0}]' -f $NewRadarrMovie.FileName) -ForegroundColor Yellow
                $MovieJob.FileAction = 'Move'
                $MovieJob.RadarrAction = 'Update'
                $MovieJob.RadarrNewFolderPath = Join-path $NewRadarrMovie.FolderPath -ChildPath $NewRadarrMovie.SimpleTitle
            }
        }
        Else{
            Write-Host ('No movie exists in Radarr. Adding new movie to Radarr [{0}]' -f $NewRadarrMovie.FileName) -ForegroundColor Green
            $MovieJob.FileAction = 'Move'
            $MovieJob.RadarrAction = 'New'
            $MovieJob.RadarrNewFolderPath = Join-path $NewRadarrMovie.FolderPath -ChildPath $NewRadarrMovie.SimpleTitle
        }


        #build new object that combines mappings and Radarr actions
        $NewRadarrMovieActions += Merge-MultipleObjects $NewRadarrMovie $MovieJob
        } #End loop
}

#$NewRadarrMovieActions




## UPDATE RADARR
##---------------------
If($ProcessRequestedMovies -and $NewRadarrMovieActions.Count -gt 0)
{
    $Syncing = Get-ChildItem  -Path "$DownloadedMoviePath\.sync" | Where {$_.Extension -in '.!sync'}
    If($Syncing.count -gt 0){
        Write-Host ("Syncing is still in progress...unable to process downloaded movies folder") -ForegroundColor Yellow
        Break
    }

    $PlexActivity = Get-PlexActivity -PlexToken $PlexAuthToken -Details
    If($PlexActivity.title -in $NewRadarrMovieActions.title){
        Write-Host ("Movie in Plex is currently streaming...unable to continue with updating movies folder") -ForegroundColor Yellow
        Break
    }


    #$NewMovie = $NewRadarrMovieActions[3]
    #$NewMovie = $NewRadarrMovieActions[1]
    Foreach($NewMovie in $NewRadarrMovieActions)
    {

        Write-Host ("----------------------------------------------------------") -ForegroundColor Cyan
        Write-Host ("Processing new movie [{0}]... " -f $NewMovie.Title) -ForegroundColor Cyan

        $DestinationPath = (Join-Path $NewMovie.RadarrNewFolderPath -ChildPath $NewMovie.FileName)
        $MovieInRadarr = $ExistingRadarrMovies | Where {($_.title -eq $NewMovie.Title -or $_.sortTitle -eq $NewMovie.Title) -and $_.year -eq $NewMovie.Year}


        If($NewMovie.RadarrAction -eq 'Update' -and $NewMovie.RadarrFileStatus -ne 'Missing'){
            New-Item $NewMovie.RadarrFilePath -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
        }

        If($NewMovie.RadarrFilePath){
            If( (Split-Path $NewMovie.RadarrFilePath -Parent) -ne $NewMovie.RadarrNewFolderPath){
                #delete the entire folder?
                If(Test-Path $NewMovie.RadarrFilePath){
                    Get-Item (Split-Path $NewMovie.RadarrFilePath -Parent) | Remove-Item -Recurse -Force -Confirm
                }

            }
        }

        Switch($NewMovie.FileAction){
            'Move'   {
                        Write-Host ("Moving movie file [{0}] to [{1}]..." -f $NewMovie.SourceFileName, $NewMovie.RadarrNewFolderPath) -NoNewline
                        Try{
                            New-Item $NewMovie.RadarrNewFolderPath -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
                            Move-Item -LiteralPath $NewMovie.SourceFilePath -Destination $DestinationPath -Force | Out-Null
                            Write-Host ('Done. Renamed file to [{0}]' -f $NewMovie.FileName) -ForegroundColor Green
                        }Catch{
                            write-host ("Failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
                            Continue
                        }
            }

            'Delete' {
                        Get-Item -LiteralPath $NewMovie.SourcePath | Remove-Item -Recurse -Force -Confirm
            }

        } #end file actions


        Switch($NewMovie.SupportFilesAction){
            'New'   {
                        #TODO: Develop API to pull language file
            }

            'Move' {
                        #$SupportFile = $NewMovie.SupportFilesPath[0]
                        If($NewMovie.SupportFilesPath.count -eq 1){

                            $FileName = Split-Path $NewMovie.SupportFilesPath -Leaf
                            Write-Host ("Moving support file [{0}] to [{1}]..." -f $FileName, $NewMovie.RadarrNewFolderPath) -NoNewline
                            $ext = [System.IO.Path]::GetExtension($FileName)
                            If($FileName -match $SupportedLanguages){
                                $SupportDestinationPath = $DestinationPath.replace($NewMovie.FileExtension,'') + '.' + $matches[0] + $ext
                            }Else{
                                $SupportDestinationPath = $DestinationPath.replace($NewMovie.FileExtension,$ext)
                            }
                            $NewFilename = Split-Path $SupportDestinationPath -Leaf
                            Try{
                                Move-Item -LiteralPath $NewMovie.SupportFilesPath -Destination $SupportDestinationPath -Force | Out-Null
                                Write-Host ('Done. Renamed file to [{0}]' -f $NewFilename) -ForegroundColor Green
                            }Catch{
                                write-host ("Failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
                                Continue
                            }
                        }
                        Else{
                            Foreach($SupportFile in $NewMovie.SupportFilesPath){
                                $FileName = Split-Path $SupportFile -Leaf
                                Write-Host ("Moving support file [{0}] to [{1}]..." -f $FileName, $NewMovie.RadarrNewFolderPath) -NoNewline
                                $ext = [System.IO.Path]::GetExtension($FileName)

                                If($FileName -match $SupportedLanguages){
                                    $SupportDestinationPath = $DestinationPath.replace($NewMovie.FileExtension,'') + '.' + $matches[0] + $ext
                                }Else{
                                    $SupportDestinationPath = $DestinationPath.replace($NewMovie.FileExtension,$ext)
                                }
                                $NewFilename = Split-Path $SupportDestinationPath -Leaf
                                Try{
                                    Move-Item -LiteralPath $NewMovie.SupportFilesPath -Destination $SupportDestinationPath -Force | Out-Null
                                    Write-Host ('Done. Renamed file to [{0}]' -f $NewFilename) -ForegroundColor Green
                                }Catch{
                                    write-host ("Failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
                                    Continue
                                }
                            }
                        }
            }

        } #end support file actions

        Switch($NewMovie.RadarrAction){
            'New'   {
                        Try{
                            #$NewMovie = Get-RadarrMovie -MovieTitle $NewMovie.Title -Year $NewMovie.Year -AsObject
                            $MovieFromDB = New-RadarrMovie -Title $NewMovie.Title -Year $NewMovie.Year `
                                                    -imdbID $NewMovie.OnlineImdbID -tmdbID $NewMovie.OnlineTmdbID `
                                                    -Path $DestinationPath -PosterImage $NewMovie.OnlinePoster `
                                                    -SearchAfterImport
                        }
                        Catch{
                            write-host ("Failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
                            Continue
                        }

            }

            'Update' {
                        Try{
                            Write-host ("Updating Radarr's Movie path for [{1}] to [{0}]..." -f $NewMovie.RadarrNewFolderPath,$NewMovie.title) -NoNewline
                            $Null = Update-RadarrMoviePath -InputObject $MovieInRadarr -DestinationPath $NewMovie.RadarrNewFolderPath -ErrorAction Stop
                            Write-host ("Done") -ForegroundColor Green
                        }
                        Catch{
                            write-host ("Failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
                            Continue
                        }
            }

            'Remove' {}

        } #end radarr actions

    } #end loop

    #delete all empty folders:
    Get-ChildItem $DownloadedMoviePath -Recurse |
            Where-Object -FilterScript {$_.PSIsContainer -eq $True} |
            Where-Object -FilterScript {($_.GetFiles().Count -eq 0) -and $_.GetDirectories().Count -eq 0} | Remove-Item -Confirm


    <#
    Send-PlexRecentlyAddedEMail -PlexToken $PlexAuthToken `
        -Credentials (Import-Clixml D:\Data\Automation\Configs\GmailAuth.xml) `
        -BccAllPlexUsers -OmdbApi $OMDBAPI `
        -PlexName $PlexName `
        -Salutation "Enjoy the free things from Tricky"
    #>
}








## CHECK MOVIE VALIDITY
##---------------------

#get all folders and count moview in each folder, find folder with more than one file
$AllMovieFiles = Get-ChildItem -LiteralPath $MoviesDir -Recurse | Where {$_.Extension -in $VideoExtensions}
$AllMovieCountPerFolder = Get-ChildItem -LiteralPath $MoviesDir -Recurse -Directory |
        Select-Object FullName, @{Name="FileCount";Expression={(Get-ChildItem $_.FullName -File | Where {$_.Extension -in $VideoExtensions} | Measure-Object).Count }}
$MultipleMovieserFolder = $AllMovieCountPerFolder | Where-Object {$_.FullName -notmatch '' -and $_.FileCount -gt 1}

#get title that does not have a movie file
$missingMovieFiles = $ExistingRadarrMovies | Where {$_.hasFile -eq $false } | Select id,Title,Year,path,@{n="exists";e={[bool](Test-Path $_.path)}}

<#TODO
    Look to see if missing movies exist somewhere else.
    If so,compare folder genre with movie genre and update/move movie to right path
#>


#find movies without year in path or year does not match path
$MovieYearDoesNotMatchPath = $ExistingRadarrMovies | Select id,Title,Year,path,@{n="exists";e={[bool](Test-Path $_.path)}},
                                                @{n="PathYear";e={[regex]::match($_.path,'(19|20)[0-9][0-9]').value}},
                                                @{n="YearMatchPath";e={If($_.Year -ne [regex]::match($_.path,'(19|20)[0-9][0-9]').value){$False}Else{$True}}} | Where {$_.YearMatchPath -eq $false}




#find duplicate movies by imdb
$duplicateImdbMovies = $ExistingRadarrMovies | Group-Object -Property imdbId | Where-Object Count -GT 1

<#TODO
    Look to see why there are duplicate tmdb movies.
    If multiple video files; determine the highest resoltion and delete all others and remove entry from radarr
#>

#TEST $dupMovieIMDB = $duplicateImdbMovies[-1]
foreach($dupMovieIMDB in $duplicateImdbMovies)
{
    #Since both moviews ar ehte same we can build the proper title of movie from first instance
    $movieTitle = $dupMovieIMDB.Group.Title[0] + ' (' + $dupMovieIMDB.Group.Year[0] + ')' -replace "[^{\p{L}\p{Nd}\'}]+", " "

    $FilesToMove = $dupMovieIMDB.Group.moviefile
    Switch -regex ($FilesToMove.relativePath){
       '1080p' {$UseRes = '1080p';break}
       '720p' {$UseRes = '720p';break}
    }

    $KeepMovie = $null
    #Determine whic movie is more properly named
    If($FilesToMove.relativePath -match $UseRes){
        $KeepMovie = $FilesToMove | Where {$_.relativePath -like "$movieTitle*"}
    }

    If($KeepMovie){
        #TEST $dupmovie = $dupMovieIMDB.Group[-1]
        Foreach($dupmovie in $dupMovieIMDB.Group | Where {$_.moviefile.id -ne $KeepMovie.id}){
            Remove-Item $dupmovie.moviefile.Path -Force -ErrorAction SilentlyContinue | Out-Null
        }

        #first remove all instances of movie in Radarr (due to duplicate entries)
        Remove-RadarrMovie -Id $dupMovieIMDB.Group.id[0]

        #re-add the movie to radarr as single instance
        New-RadarrMovie -Title $dupMovieIMDB.Group.Title[0] `
                    -Year $dupMovieIMDB.Group.Year[0] `
                    -imdbID $dupMovieIMDB.Group.imdbId[0] `
                    -tmdbID $dupMovieIMDB.Group.tmdbId[0] `
                    -PosterImage ($dupMovieIMDB.Group.images[0] | Where coverType -eq 'poster' | select -ExpandProperty remoteurl) `
                    -Path (Split-Path $KeepMovie.path -Parent) -SearchAfterImport
    }Else{
        Write-host ("Imdb Movie paths do not match title: {0}" -f $movieTitle) -ForegroundColor Red
    }


}

#find duplicate movies by tmdb
$duplicateTmdbMovies = $ExistingRadarrMovies | Group-Object -Property tmdbId | Where-Object Count -GT 1

<#
    Look to see why there are duplicate tmdb movies.
    If multiple video files; determine the highest resolution and delete all others and remove entry from radarr
#>
#TEST $dupMovieTMDB = $duplicateTmdbMovies[-1]
#TEST $dupMovieTMDB = $duplicateTmdbMovies[1]
foreach($dupMovieTMDB in $duplicateTmdbMovies)
{
    #Since both moviews ar ehte same we can build the proper title of movie from first instance
    $movieTitle = $dupMovieTMDB.Group.Title[0] + ' (' + $dupMovieTMDB.Group.Year[0] + ')' -replace "[^{\p{L}\p{Nd}\'}]+", " "

    $FilesToMove = $dupMovieTMDB.Group.moviefile
    Switch -regex ($FilesToMove.relativePath){
       '1080p' {$UseRes = '1080p';break}
       '720p' {$UseRes = '720p';break}
    }

    $KeepMovie = $null
    #Determine which movie is more properly named
    If($FilesToMove.relativePath -match $UseRes){
        $KeepMovie = $FilesToMove | Where {$_.relativePath -like "$movieTitle*"}
    }

    If($KeepMovie){
        #TEST $dupmovie = $dupMovieTMDB.Group[-1]
        Foreach($dupmovie in $dupMovieTMDB.Group | Where {$_.moviefile.id -ne $KeepMovie.id}){
            Remove-Item $dupmovie.moviefile.Path -Force -ErrorAction SilentlyContinue | Out-Null
        }

        #first remove all instances of movie in Radarr (due to duplicate entries)
        Remove-RadarrMovie -Id $dupMovieTMDB.Group.id[0]

        #re-add the movie to radarr as single instance
        New-RadarrMovie -Title $dupMovieTMDB.Group.Title[0] `
                    -Year $dupMovieTMDB.Group.Year[0] `
                    -imdbID $dupMovieTMDB.Group.imdbId[0] `
                    -tmdbID $dupMovieTMDB.Group.tmdbId[0] `
                    -PosterImage ($dupMovieTMDB.Group.images[0] | Where coverType -eq 'poster' | select -ExpandProperty remoteurl) `
                    -Path (Split-Path $KeepMovie.path -Parent) -SearchAfterImport
    }
    Else{
        Write-host ("Tmdb Movie paths do not match title: {0}" -f $movieTitle) -ForegroundColor Red
    }


}


#find duplicate movies by title
$duplicateMovieTitles = $ExistingRadarrMovies | Group-Object -Property Title | Where-Object Count -GT 1
#Find if movies with same title are just reboots (with different year)
$MovieTitleNonReboot = @()
#TEST $dupMovieTitle = $duplicateMovieTitles[0]
#TEST $dupMovieTitle = $duplicateMovieTitles[1]
#TEST $dupMovieTitle = $duplicateMovieTitles[-2]
foreach($dupMovieTitle in $duplicateMovieTitles)
{
    $years = ($dupMovieTitle.Group | Select -ExpandProperty Year)

    #determine if each movie title is a different year to account for reboots
    #assume movies with no year are the same
    If( ($dupMovieTitle.Group | Select -ExpandProperty id) -match ($MovieYearDoesNotMatchPath.id -join '|') )
    {

    }
    ElseIf(0 -in $years -or $null -in $years)
    {
        $MovieTitleNonReboot += $dupMovieTitle.Group | Select id,Title, Year, path, @{n="pathexists";e={[bool](Test-Path $_.path)}}
    }
    Elseif($years | Group-Object | Where-Object Count -GT 1)
    {
        $MovieTitleNonReboot += $dupMovieTitle.Group | Select id,Title, Year, path, @{n="pathexists";e={[bool](Test-Path $_.path)}}
    }
    Else{
        ("Movie [{0}] are reboots and has different years [{1}]" -f ($dupMovieTitle.Name),($Years -join ','))
    }
}



## CLEANUP
##---------------------
#remove logs older than 30 days
Remove-AgedItems -Path $LogDir -Age 30 -Force

Stop-Transcript
