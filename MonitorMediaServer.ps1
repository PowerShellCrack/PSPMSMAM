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


$LogfileName = "$($scriptName)_$(Get-Date -Format 'yyyy-MM-dd_Thh-mm-ss-tt').log"
Try{Start-transcript "$LogDir\$LogfileName" -ErrorAction Stop}catch{Start-Transcript "$PSScriptRoot\$LogfileName"}
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

#import helpers
. "$HelpersPath\CleanFolders.ps1"
. "$HelpersPath\MovieSearch.ps1"


##*===============================================
##* MAIN
##*===============================================
# PARSE CONFIG FILE
[string]$AutomationConfigFileContent = (Get-Content "$ConfigPath\MediaServer.xml" -ReadCount 0) -replace "&","&amp;"
[Xml.XmlDocument]$AutomationConfigFile = $AutomationConfigFileContent
[Xml.XmlElement]$GlobalSettings = $AutomationConfigFile.AutomationConfig
[Xml.XmlElement]$GlobalSettings = $AutomationConfigFile.AutomationConfig
$ServicesToCheck = $GlobalSettings.ServiceCheck.service
$ProcessesToCheck = $GlobalSettings.ProcessCheck.process

[string]$RadarrConfigFile = $GlobalSettings.SourceConfigs.Config | Where Id -eq 'Radarr' | Select -ExpandProperty ConfigFile

# PARSE RADARR CONFIG FILE
[Xml.XmlDocument]$RadarrConfigContent = (Get-Content "$ConfigPath\$RadarrConfigFile" -ReadCount 0) -replace "&","&amp;"
[Xml.XmlElement]$RadarrConfigs = $RadarrConfigContent.RadarrAutomation.RadarrConfig
[Xml.XmlElement]$RadarrSettings = $RadarrConfigContent.RadarrAutomation.GlobalSettings
[Xml.XmlElement]$RadarrMovieConfigs = $RadarrConfigContent.RadarrAutomation.MovieConfigs

[string]$Global:RadarrURL = $RadarrConfigs.InternalURL
[string]$Global:RadarrPort = $RadarrConfigs.Port
[string]$Global:RadarrAPIkey = $RadarrConfigs.API
[string]$OMDBAPI = $RadarrSettings.OMDBAPI
[string]$TMDBAPI = $RadarrSettings.TMDBAPI
[string[]]$VideoExtension = $RadarrSettings.VideoExtensions.ext -split ','
[string]$MoviesDir = $RadarrSettings.MoviesRootPath

[Boolean]$ProcessRequestedMovies = [Boolean]::Parse($RadarrMovieConfigs.MovetoGenreFolder)
[string]$MovieRequestsPath = $RadarrMovieConfigs.MovieRequestedMovePath
[string]$DownloadedMoviePath = $RadarrMovieConfigs.DownloadedMoviePath

#add folder paths to each genre tag
$MoviesGenreMappings = @{}
[PSCustomObject]$MoviesGenreMappings = $RadarrMovieConfigs.GenreBinder.Genre
Foreach($genre in $MoviesGenreMappings){
    #$FolderPath = Get-ChildItem $MoviesDir | Where Name -eq $genre.BindingFolder | Select -First 1
    $FolderPath = Join-Path -Path $MoviesDir -ChildPath $genre.BindingFolder
    If($FolderPath){
        $MoviesGenreMappings | Where Tag -eq $genre.Tag | Add-Member -MemberType NoteProperty -Name 'FolderPath' -Value $FolderPath -Force
    }
}


## CHECK SERVICES
##---------------
#Check each service and start them if possible
#TEST
# $service =  $ServicesToCheck | Where Name -eq Tomcat9
Foreach($service in $ServicesToCheck){
    $SystemService = Get-Service -Name $service.Name -ErrorAction SilentlyContinue
    If($SystemService){
        If($SystemService.Status -eq $service.state){
            Write-Host ("[{1}] exists and is currently running. Checked service [{0}]" -f $service.Name,$service.FriendlyName) -ForegroundColor Green
        }
        Else{
            Write-Host ("[{1}] exists but is not running. Starting service [{0}]" -f $service.Name,$service.FriendlyName) -ForegroundColor Yellow
            Try{
                Start-Service $SystemService -ErrorAction Stop
            }
            Catch{
                Write-Host ("[{1}] exist but failed to start. [{0}]" -f $service.Name,$_.Exception.Message) -ForegroundColor Red
            }
        }

    }Else{
        Write-Host ("[{1}] does not exist. Ignoring service [{0}]" -f $service.Name,$service.FriendlyName) -ForegroundColor Yellow
    }
}




#CHECK BITSYNC FOLDER FOR VIDEOS
##------------------------------
#get all download files that are videos
$DownloadedFiles = Get-ChildItem -Path $DownloadedMoviePath -Recurse -Depth 1 | Where {$_.PSIsContainer -eq $false -and $_.Extension -in $VideoExtension}

#determine which ones are movies
$DownloadedMovies = $DownloadedFiles | Where {$_.name -match "([ .\w']+?)(\W\d{4}\W?.*)" -and $_.name -notmatch "^.*S\d\dE\d\d"}

#determine which ones are tv shows
$DownloadedTvShows = $DownloadedFiles | Where {$_.name -match "^.*S\d\dE\d\d"}

#$movie = $DownloadedMovies[0]
Foreach($SyncdMovie in $DownloadedMovies)
{

    $VideoRootFolder = (Split-path $SyncdMovie.FullName -Parent)
    #remove files that aren't video files.
    If($VideoRootFolder -ne $DownloadedMoviePath){
        $SourceFolder = $VideoRootFolder
        Get-ChildItem -LiteralPath $SourceFolder -Recurse | Where {$_.PSIsContainer -eq $false -and $_.Extension -notin $VideoExtension} | Remove-Item -Force
    }Else{
        $SourceFolder = $SyncdMovie.FullName
    }

    Try{

        Move-Item -LiteralPath $SourceFolder -Destination $MovieRequestsPath -Force
    }Catch{
        $_.exception.message
    }
}


##first get all movies (this is required for additonal details)
$RadarrMovies = Get-RadarrMovies

## CHECK MOVIE REQUESTS
##---------------------
If($ProcessRequestedMovies)
{
    #movies request and have moved already
    $RequestedMovies = Get-ChildItem -Path $MovieRequestsPath -Directory

    #Loop throuh moview that have been movied into request folder
    #TEST $Movie = $RequestedMovies[0]
    Foreach($Movie in $RequestedMovies)
    {
        $MovieName = $movie.BaseName
        #find the year in movie name
        $MatchNameParts = "\bWEBRip\b|\bBluRay\b|\b1080p\b|\b720p\b|\bH264\b|\bAAC\b|\bx264\b"
        Do {
            If($MovieName -match $MatchNameParts){$MovieName = $MovieName -replace $matches.Values,'' }
        }Until($MovieName -notmatch $MatchNameParts)

        <#
        #does the movie have a year incapsulated in parenthesis
        If($MovieName -match ".?\((.*?)\).*"){
            $MovieYear = $matches[1]
            $MovieName = ($MovieName).replace("($MovieYear)","").Trim()
        }
        #>

        #assume a four digit number starting with 19 or 20 is a year
        if($MovieName -match "(19|20)[0-9][0-9]"){
            $MovieYear = $matches[0]
            $MovieName = ($MovieName -split $MovieYear)[0]
        }

        #remove an leading special characters
        If($MovieName -match "\.$|\-$|_$|\[$|\($"){
            $MovieName = ($MovieName -replace "\$($matches.Values)$",' ').Trim()
        }


        $MovieYear = $MovieYear.Trim()
        $MovieTitle = $MovieName.replace('.',' ').replace('-',' ').Trim() -replace '\s+',' '

        $RadarrMovie = Get-RadarrMovie -MovieTitle $MovieTitle -Year $MovieYear -AsObject
        #If($RadarrMovie.count -gt 1){$RadarrMovie = $RadarrMovie | where year -eq $MovieYear | Select -First 1}

        $OnlineMovie = Search-MovieTitle -Title $MovieTitle -Year $MovieYear -IMDBApiKey $OMDBAPI -TMDBApiKey $TMDBAPI

        If($OnlineMovie -or $RadarrMovie)
        {
            #force all disney movies to its folder no matter the genre
            If($RadarrMovie.studio -like '*Disney*' -or $OnlineMovie.Production -like '*Disney*'){
                $MatchedMapping = $MoviesGenreMappings | Where Tag -eq 'Disney'
            }
            #force all barbie movies to its folder no matter the genre
            ElseIf($RadarrMovie.Title -like '*Barbie*' -or $OnlineMovie.Title -like '*Barbie*'){
                $MatchedMapping = $MoviesGenreMappings | Where Tag -eq 'Barbie'
            }
            #force all marvel or DC comics movies to its folder no matter the genre
            ElseIf($RadarrMovie.studio -like '*Marvel*' -or $OnlineMovie.Production -like '*Marvel*' -or $RadarrMovie.studio -like '*DC Comics*'){
                $MatchedMapping = $MoviesGenreMappings | Where Tag -eq 'Superhero'
            }

            #force all holiday movies to its folder no matter the genre
            ElseIf($RadarrMovie.Title -like '*Holiday*' -or $OnlineMovie.Title -like '*Holiday*' -or $RadarrMovie.Title -like '*Christmas*' -or $RadarrMovie.Title -like '*Santa*'){
                $MatchedMapping = $MoviesGenreMappings | Where Tag -eq 'Holiday'
            }

            Else{
                [array]$genres = $RadarrMovie.genres -split ','

                If($genres.count -eq 0){[array]$genres = ($OnlineMovie.Genres -split ',').Trim()}

                Foreach($genre in $genres){
                    If($genre -in $MoviesGenreMappings.Tag){
                        $MatchedMapping = $MoviesGenreMappings | Where Tag -eq $genre

                        #force horror films with horror genre
                        If($genre -eq 'Horror'){
                            $MatchedMapping = $MoviesGenreMappings | Where Tag -eq 'Horror'
                            Break
                        }

                        #force scifi films to sci-fi
                        If($genre -eq 'Science Fiction' -or $genre -eq 'Sci-Fi'){
                            $MatchedMapping = $MoviesGenreMappings | Where Tag -eq 'Sci-Fi'
                            Break
                        }
                   }
                }#end genre loop
            }

            #get supported files in request folders for each movie
            $files = Get-ChildItem -LiteralPath $Movie.FullName -Recurse | Where{$_.Extension -in $VideoExtension}

            If($files.count -gt 0)
            {
                If($MatchedMapping.FolderPath)
                {
                    $DestinationPath = Join-Path $MatchedMapping.FolderPath -ChildPath "$MovieTitle ($MovieYear)"

                    $MovieFromDB = $radarrmovies | Where {$_.tmdbid -eq $RadarrMovie.tmdbId}
                    If(!$MovieFromDB -and $OnlineMovie){$MovieFromDB = New-RadarrMovie -Title $MovieTitle -Year $MovieYear -imdbID $OnlineMovie.imdbID -tmdbID $OnlineMovie.tmdbID -Path $DestinationPath -PosterImage $OnlineMovie.Poster}
                    $MovieObject = Get-RadarrMovie -MovieId $MovieFromDB.id -AsObject

                    If($MovieObject){

                        #update radarr, then move file (incase it fails?)
                        Try{
                            Update-RadarrMoviePath -InputObject $MovieObject -DestinationPath $DestinationPath -ErrorAction Stop
                            #create folder
                            New-Item -Path $DestinationPath -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
                                write-host ("Movie [{0}] will move to [{1}]" -f $Movie.FullName,$DestinationPath)

                            Foreach($file in $files) {
                                Move-Item -LiteralPath $file.FullName $DestinationPath -Force -ErrorAction Stop | Out-Null
                                write-host ("  Moved [{0}]" -f $file.FullName)
                            }
                        }
                        Catch{

                            write-host ("Unable to process movie {0}. {1}" -f $MovieName,$_.Exception.Message) -ForegroundColor Red


                            <#
                            #move movie back if failed to update radarr
                            If(Test-Path $DestinationPath){
                                Foreach($file in $files) {
                                    $movedfile = Join-path $DestinationPath $file.Name
                                    Move-Item -LiteralPath $movedfile -Destination (Get-Item -LiteralPath $Movie.FullName).FullName -Force -ErrorAction SilentlyContinue | Out-Null
                                }
                                Remove-item $DestinationPath -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
                            }
                            #>
                        }
                        Finally{
                            $ResidualFolder = Get-ChildItem -LiteralPath $Movie.FullName -Recurse
                            If($ResidualFolder.count -eq 0){
                                Remove-Item -LiteralPath $Movie.FullName -Force | Out-Null
                            }
                        }
                    }
                    Else{
                         write-host ("No movie with name [{0}] was found in radarr unable to update" -f "$MovieTitle ($MovieYear)") -ForegroundColor Yellow
                    }
                }
                Else{
                    write-host ("No destination path using genres [{0}] was determined for movie [{1}]" -f $genre,"$MovieTitle ($MovieYear)") -ForegroundColor Yellow
                }
            }Else{
                write-host ("No files with extensions [{0}] was found in folder [{1}\]" -f ($VideoExtension -join ','),$Movie.FullName) -ForegroundColor Yellow
                Remove-Item -LiteralPath $Movie.FullName -Recurse -Force | Out-Null
            }

        }
        Else{
            write-host ("No movie with name [{0}] was found in radarr or online" -f "$MovieTitle ($MovieYear)") -ForegroundColor Red
        }

        Write-Host "-----------------------------------------------"
        start-sleep 5

    } #end of movies folder loop
}


## CHECK MOVIE VALIDITY
##---------------------
#get title that does not have a movie file
$missingMovieFiles = $RadarrMovies | Where {$_.hasFile -eq $false } | Select id,Title,Year,path,@{n="exists";e={[bool](Test-Path $_.path)}}

#find movies without year in path or yesr does not match path
$MovieYearDoesNotMatchPath = $RadarrMovies | Select id,Title,Year,path,@{n="exists";e={[bool](Test-Path $_.path)}},
                                                @{n="PathYear";e={[regex]::match($_.path,'(19|20)[0-9][0-9]').value}},
                                                @{n="YearMatchPath";e={If($_.Year -ne [regex]::match($_.path,'(19|20)[0-9][0-9]').value){$False}Else{$True}}} | Where {$_.YearMatchPath -eq $false}

#find duplicate movies by title, imdb or tmdb
$duplicateMovieTitles = $RadarrMovies | Group-Object -Property Title | Where-Object Count -GT 1
$duplicateImdbMovies = $RadarrMovies | Group-Object -Property imdbId | Where-Object Count -GT 1
$duplicateTmdbMovies = $RadarrMovies | Group-Object -Property tmdbId | Where-Object Count -GT 1

#Find if moviews with same title are just reboots (with different year)
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