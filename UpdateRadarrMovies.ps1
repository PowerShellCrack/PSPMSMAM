<#
.Synopsis
    Update Radarr content

.NOTES
    Author: Richard Tracy
    My original intentions was to write a script I could run regularly to
    add movie series collections into Radarr, since Radarr can't see deeper than
    the root movie folder where my movie series are a subfolder of the root
    movies in folders called " Collection" and " Anthology". These folders
    were auto created when I ran TinyMediaManger (https://www.tinymediamanager.org/)
    on my movies collections...I soson found out this broke Radarr's inventory
    and had to remove over 100+ movies. It was a pain. I then decided to write this
    script to add them back but in the proper folder.

.LINK
    https://api.themoviedb.org/3/movie/550?api_key=798cb1c0648d68fc43ab0c94dac906e9
.LINK
    https://developers.themoviedb.org/3/getting-started/introduction
.LINK
    https://github.com/Radarr/Radarr/wiki/API:Movie
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
##*===============================================
##* VARIABLE DECLARATION
##*===============================================
# Use function to get paths because Powershell ISE and other editors have differnt results
$scriptPath = Get-ScriptPath
[string]$scriptDirectory = Split-Path $scriptPath -Parent
[string]$scriptName = Split-Path $scriptPath -Leaf
[string]$scriptBaseName = [System.IO.Path]::GetFileNameWithoutExtension($scriptName)

#Get required folder and File paths
[string]$ExtensionPath = Join-Path -Path $scriptRoot -ChildPath 'Extensions'
[string]$HelpersPath = Join-Path -Path $scriptRoot -ChildPath 'Helpers'
[string]$ConfigPath = Join-Path -Path $scriptDirectory -ChildPath 'Configs'
[string]$LogDir = Join-Path $scriptDirectory -ChildPath 'Logs'
[string]$StoredDataDir = Join-Path $scriptDirectory -ChildPath 'StoredData'
##*===============================================
##* EXTENSIONS
##*===============================================
#Import Script extensions
. "$ExtensionPath\SupportFunctions.ps1"
. "$ExtensionPath\Logging.ps1"
. "$ExtensionPath\ImdbMovieAPI.ps1"
. "$ExtensionPath\TmdbAPI.ps1"
. "$ExtensionPath\RadarrAPI.ps1"
. "$ExtensionPath\VideoParser.ps1"
#. "$ExtensionPath\TauTulliAPI.ps1"

#import helpers
. "$HelpersPath\CleanFolders.ps1"
. "$HelpersPath\MovieSearch.ps1"


## Variables: Datetime and Culture
[datetime]$currentDateTime = Get-Date
[string]$currentTime = Get-Date -Date $currentDateTime -UFormat '%T'
[string]$currentDate = Get-Date -Date $currentDateTime -UFormat '%d-%m-%Y'
[timespan]$currentTimeZoneBias = [timezone]::CurrentTimeZone.GetUtcOffset([datetime]::Now)

##*===============================================
##* CONFIG
##*===============================================
# PARSE CONFIG FILE
[Xml.XmlDocument]$RadarrConfigFile = (Get-Content "$ConfigPath\Configs-Radarr.xml" -ReadCount 0) -replace "&","&amp;"
[Xml.XmlElement]$RadarrConfigs = $RadarrConfigFile.RadarrAutomation.RadarrConfig
[Xml.XmlElement]$RadarrSettings = $RadarrConfigFile.RadarrAutomation.GlobalSettings
[string]$Global:RadarrURL = $RadarrConfigs.InternalURL
[string]$Global:RadarrPort = $RadarrConfigs.Port
[string]$Global:RadarrAPIkey = $RadarrConfigs.API
[string]$OMDBAPI = $RadarrSettings.OMDBAPI
[string]$TMDBAPI = $RadarrSettings.TMDBAPI
[string]$MoviesDir = $RadarrSettings.MoviesRootPath

[string]$FilterSeriesFolders = ($RadarrSettings.MovieSeriesFolders.Folder) -join "|"
[string]$FilterOtherFolders = ($RadarrSettings.FilterMovieSubFolders.Folder) -join "|"

# Update Data Configs
[boolean]$StatsOnly = [boolean]::Parse($RadarrSettings.CheckStatusOnly)
[boolean]$FindMissingOnly = [boolean]::Parse($RadarrSettings.FindMissingOnly)
[boolean]$UpdateNfoData = [boolean]::Parse($RadarrSettings.UpdateNfoData)
[boolean]$UpdateJustMovieSeries = [boolean]::Parse($RadarrSettings.UpdateMovieSeriesOnly)
[int32]$UseRecentStoredDataDays = $RadarrSettings.UseRecentStoredDataDays


[datetime]$StoreData = $currentDateTime.AddDays(-$UseRecentStoredData)
If($UseRecentStoredDataDays -gt 0){$UseLocalizedStoredData = $true}Else{$UseLocalizedStoredData = $false}

#Reset variables
$Global:UnmatchedMovieReport = @()
$Global:ExistingMovieReport = @()
$Global:WrongMovieReport = @()
$Global:NoMovieInfoReport = @()
$Global:FailedMovieReport = @()

$Global:UpdatedMovieReport = @()
$Global:RemovedMovieReport = @()
$Global:AddedMovieReport = @()

#=======================================================
# MAIN
#=======================================================
#generate log file
If($scriptName){
    $FinalLogFileName = ($ScriptName.Trim(" ") + "_" + $currentDate + "_" + $currentTime.replace(':',''))
    [string]$global:LogFilePath = Join-Path $LogDir -ChildPath "$FinalLogFileName.log"
    Write-Log -Message ("Starting Log") -Source ${CmdletName} -Severity 4 -WriteHost -MsgPrefix (Pad-PrefixOutput -Prefix "Starting" -UpperCase)
}


#Basically this part check to see if the $Global:AllMoviesGenres has data already
# good for testings instead of processing folders each time
If( ($Global:RadarrMovies.count -eq 0)  ){
    #build radarr list
    Write-Host "Grabbing all movies in Radarr..." -NoNewline
    $Global:RadarrMovies = Get-RadarrMovies -Api $radarrAPIkey
}


If( ($Global:AllMoviesGenres.count -eq 0) ){
    Write-Host "Grabbing all movie folders..." -NoNewline
    #get all folders that exist in directory
    $AllFolders = Get-ChildItem $MoviesDir -Recurse -ErrorAction SilentlyContinue | Where-Object { ($_.PSIsContainer -eq $true)}
}

# Grab the movie folders only (no matter the directory depth)
# This is done by comparing like folders
# and filtering out folders
$AllMovieFolders = New-Object System.Collections.ArrayList
foreach ($folder in $AllFolders){
    #grab root folder
    $Parent = Split-Path $folder.FullName -Parent
    #$last = ($folder.FullName).Split('\')[-1]

    #does current folder match an identifed filtered folders
    If($folder.FullName -notmatch $FilterOtherFolders){

        #does current folder already exist in array
        #remove the parent, but add the folder
        If ($AllMovieFolders -notcontains $Parent){
            $AllMovieFolders.add($folder.FullName) | Out-Null
        }

        Else{
            $AllMovieFolders.remove($Parent) | Out-Null
            $AllMovieFolders.add($folder.FullName) | Out-Null
        }

    }

}


#update just the series section?
If($UpdateJustMovieSeries){
    Write-Host "Comparing all movie series on disk to what is in Radarr" -NoNewline
    #only get the movie sets located in collection folders
    $movieFilter = $AllMovieFolders | Where-Object {$_ -match $FilterSeriesFolders}

    Write-Host ("Movie was Filter to: {0}" -f $movieFilter.Count) -ForegroundColor Cyan
}
Else{
    Write-Host "Comparing all movies on disk to what is in Radarr" -NoNewline
    #get list of all movie folders including any sub folders (series)
    # but do not include collection folders themselves
    $movieFilter = $AllMovieFolders

    Write-Host ("Movies Found: {0}" -f $AllMovieFolders.Count)
}


Write-Host "============================================="


#test movie
#$movie = $movieFilter[1364]

foreach ($Movie in $movieFilter)
{
    #clear values after each loop
    $MovieInfo = @()
    $SearchForMovie = $true
    $AddMovietoRadarr = $false
    $UpdateMovieinRadarr = $false
    $UpdateMoviePathinRadarr = $false
    $UpdateMovieTitleinRadarr = $false

    $MovieName = Split-Path $Movie -Leaf
    $MoviePath = $Movie

    Write-Host "---------------------------------------" -ForegroundColor Gray
    Write-Host ("Processing Movie [{0}]" -f $MovieName ) -ForegroundColor Cyan

    # BUILD SEARCHABLE TITLES
    # ==============================
    If($MovieName  -match ".?\((.*?)\).*"){
        #is the year numeric?
        If($matches[1] -match "^[\d\.]+$"){
            $year = $matches[0]
            #remvoe the year to get the name
            $MovieTitle = ($MovieName ).replace("($year)","").Trim()
            $yearfound = $true
        }
        Else{
            $MovieTitle = $MovieName
            $yearfound = $false
        }
    }
    Else{
        $MovieTitle = $MovieName
        $yearfound = $false
    }

    #remove unsupported characters for easier search results
    #replace the Ã© with e (pokemon titles)
    $MovieTitleCleaned = $MovieTitle.replace('Ã©','e')

    #normailze any special characters such as: å,ä,ö,Ã,Å,Ä,Ö,é
    $MovieTitleCleaned = $MovieTitleCleaned.Normalize("FormD") -replace '\p{M}'

    #remove double spaces
    $MovieTitleCleaned = $MovieTitleCleaned -replace'\s+', ' '

    #replace & with and
    $MovieTitleCleaned = $MovieTitleCleaned.replace('&','and')

    #remove any special characters but keep apostraphe
    $MovieTitleNoSpecialChar = $MovieTitleCleaned -replace "[^{\p{L}\p{Nd}\'}]+", " "

    #remove all special characters even apostraphe
    $MovieTitleAllSpecialChar = $MovieTitleNoSpecialChar -replace "'", ""

    #remove all special characters and spaces
    $MovieTitleNoSpecialSpaces = $MovieTitleCleaned -replace '[^\p{L}\p{Nd}]', ''

    #does the title have a number in it like: Daddy's Home 2
    $MovieTitleConvertedToNum = Convert-WordToNumber $MovieTitleCleaned

    #does the title have a number in it like: Two men
    $MovieTitleConvertedToChar = Convert-NumberToWord $MovieTitleCleaned

    If($yearfound){
        $SearchYear = $Year
        $ParamHash = @{Year = $Year}
    }

    #Does the movie already exist in Radarr?
    $FoundRadarrMovieByTitle = $Global:RadarrMovies | Where {($_.title -eq $MovieTitle)}

    #or is ther a movie path in Radarr with that name
    $FoundRadarrMovieByPath = $Global:RadarrMovies | Where {$_.path -eq $MoviePath}

    # DETERMINE ONLINE SEARCH NEEDED
    # ==============================
    # If set to true, validate the movie exists in radar and that everything is valid
    # If set to false, search IMDB / TMDB and compare it to Radarr's movie
    If($UpdateNfoData){

        $NFOfileExist = Get-ChildItem $MoviePath -Filter *.nfo -Force -Recurse
        $yearfound = $MovieName -match ".?\((.*?)\).*"
        $year = $matches[1]
        $MovieTitle = ($MovieName).replace("($year)","").Trim()
        If($NFOfileExist.Count -gt 1){
            Write-Host ("Found multiple Movie NFO files [{0}] for: {1}" -f $NFOfileExist.Count,$MovieName) -ForegroundColor Gray
        }
        ElseIf($NFOfileExist){
            Write-Host ("Movie NFO file exists for: {0}" -f $MovieName) -ForegroundColor Green
            [xml]$NFOxml = Get-Content $NFOfileExist.FullName
            If( !($NFOxml.movie.title -match $MovieTitle) -and !($NFOxml.movie.year -match $year) ){
                Write-Host ("Movie NFO file exists for: {0} but is invalid: {1} ({2})" -f $MovieName,$NFOxml.movie.title,$NFOxml.movie.year) -ForegroundColor Red
            }
        }
        Else{
            Write-Host ("No Movie NFO file exists for: {0}" -f $MovieName) -ForegroundColor Yellow
            #If StatsOnly boolean in config is set to true don't process new nfo file
            If(!$StatsOnly){Set-VideoNFO -MovieFolder $MoviePath -imdbAPI $OMDBAPI}
        }

    }

    #If movie was found but incorrct data
    # try fixing it instead of searhing online
    If($FindMissingOnly){

        #If title AND path doesn't exist; do a search and add to Radarr
        If(!$FoundRadarrMovieByTitle -and !$FoundRadarrMovieByPath){
            Write-Host ("No Movie title and path [{0}] was found in Radarr..." -f $MovieName ) -ForegroundColor Gray
            $SearchForMovie = $true
            $AddMovietoRadarr = $true
        }

        #If title OR path not found; do a search and update radarr
        ElseIf(!$FoundRadarrMovieByTitle -or !$FoundRadarrMovieByPath){
            Write-Host ("No Movie title or path [{0}] was found in Radarr..." -f $MovieName ) -ForegroundColor Gray
            $SearchForMovie = $true
            $UpdateMovieTitleinRadarr = $true

        }

        #or if Title results are not equal; do a search and update radarr
        ElseIf($FoundRadarrMovieByTitle.title -ne $FoundRadarrMovieByPath.title){
            Write-Host ("Movie TITLE when search by title [{0}] does not match movie TITLE when searched by path [{1}] was found in Radarr..." -f $FoundRadarrMovieByTitle.title,$FoundRadarrMovieByPath.title) -ForegroundColor Gray
            $SearchForMovie = $true
            $UpdateMovieTitleinRadarr = $true
        }

        #or if path results are not equal; do a search and update radarr
        ElseIf($FoundRadarrMovieByTitle.Path -ne $FoundRadarrMovieByPath.Path){
            Write-Host ("Movie PATH when search by title [{0}] does not match movie PATH when searched by path [{1}] was found in Radarr..." -f $FoundRadarrMovieByTitle.Path,$FoundRadarrMovieByPath.Path) -ForegroundColor Gray
            $SearchForMovie = $true
            $UpdateMoviePathinRadarr = $true
        }

        # After all checks, title and path are the same then there is no need to search online (or use up an OMDB api request)
        Else{
            $SearchForMovie = $false
        }
    }
    Else{
        #since we are forcing a search for all before
        $SearchForMovie = $true
    }

    # DO SEARCH IF REQUIRED
    # =====================
    # if we need to search for a movie online
    If($SearchForMovie){
        #search for movie on imdb and tmdb
        $MovieInfo = Search-MovieTitle -Title $MovieTitle -AlternateTitles ($MovieTitleCleaned,$MovieTitleNoSpecialChar,$MovieTitleAllSpecialChar,$MovieTitleNoSpecialSpaces,$MovieTitleConvertedToNum,$MovieTitleConvertedToChar) @ParamHash -IMDBApiKey $OMDBAPI -TMDBApiKey $TMDBAPI

        #did we fins a movie online that matches the title
        If($MovieInfo){
            # Now search Radarr for a matching movie based on IMDB and TMDB
            $FoundRadarrMovieByIMDB = $Global:RadarrMovies | Where {($_.imdbId -eq $MovieInfo.imdbID) -and ($_.tmdbId -eq $MovieInfo.tmdbID)}

            #If IMDB title and radarr title found, determine a match
            If($FoundRadarrMovieByIMDB -and $FoundRadarrMovieByTitle){

                # if both titles don'y match, update radarr
                If($MovieInfo.Title -notmatch $FoundRadarrMovieByIMDB.Title){
                    $UpdateMovieinRadarr = $true
                }
                Else{
                    $AddMovietoRadarr = $false
                }
            }
        }
        Else{
            Write-Host ("Movie title [{0}] was not found online unable to add to Radarr..." -f $MovieTitle) -ForegroundColor Yellow
            $AddMovietoRadarr = $false
        }
    }
    Else{
        Write-Host ("No search is required for movie title [{0}], skipping..." -f $MovieTitle) -ForegroundColor Yellow
        $AddMovietoRadarr = $false
    }



    # ADD TO RADAAR IF SET
    # =====================
    If($UpdateMoviePathinRadarr){
        $Global:UpdatedMovieReport += $FoundRadarrMovieByTitle | Update-RadarrMoviePath -DestinationPath $MoviePath -Report -verbose -WhatIf:$StatsOnly

    }

    If($UpdateMovieTitleinRadarr){
        $Global:RemovedMovieReport += $FoundRadarrMovieByTitle | Remove-RadarrMovie -Report -WhatIf:$StatsOnly
        $Global:RemovedMovieReport += $FoundRadarrMovieByPath | Remove-RadarrMovie -Report -WhatIf:$StatsOnly
        $AddMovietoRadarr = $true
    }

    If($UpdateMovieinRadarr){
        $Global:RemovedMovieReport += $FoundRadarrMovieByTitle | Remove-RadarrMovie -Report -WhatIf:$StatsOnly
        $AddMovietoRadarr = $true
    }

    If($MovieInfo -and $AddMovietoRadarr){
        $Global:AddedMovieReport += $MovieInfo | New-RadarrMovie -Path $MoviePath -SearchAfterImport -Report -WhatIf:$StatsOnly
    }
    start-sleep 3

} #End loop

<#build radarr list
Write-Host "Grabbing all movies in Radarr again..."
$RadarrGetArgs = @{Headers = @{"X-Api-Key" = $radarrAPIkey}
                URI = "http://${radarrURL}:${radarrPort}/api/movie"
                Method = "Get"
            }
$radarrWebRequest = Invoke-WebRequest @RadarrGetArgs
$Global:RadarrMovies = $radarrWebRequest.Content | ConvertFrom-Json
#>
Write-Host ("Updated Movies   :") -ForegroundColor Gray -NoNewline
    Write-Host (" {0}" -f $Global:UpdatedMovieReport.Count)
Write-Host ("Removed Movies   :") -ForegroundColor Gray -NoNewline
    Write-Host (" {0}" -f $Global:RemovedMovieReport.Count)
Write-Host ("Added Movies      :") -ForegroundColor Gray -NoNewline
            Write-Host (" {0}" -f $Global:AddedMovieReport.Count)

