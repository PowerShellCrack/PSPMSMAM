
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
[string]$ConfigPath = Join-Path -Path $scriptRoot -ChildPath 'Configs'
[string]$LogDir = Join-Path $scriptRoot -ChildPath 'Logs'
[string]$StoredDataDir = Join-Path $scriptRoot -ChildPath 'StoredData'

#generate log file
$LogfileName = "$($scriptName)_$(Get-Date -Format 'yyyy-MM-dd_Thh-mm-ss-tt').log"
Try{Start-transcript "$LogDir\$LogfileName" -ErrorAction Stop}catch{Start-Transcript "$PSScriptRoot\$LogfileName"}

##*===============================================
##* EXTENSIONS
##*===============================================
#Import Script extensions
. "$ExtensionPath\Logging.ps1"
. "$ExtensionPath\ImdbMovieAPI.ps1"
. "$ExtensionPath\TmdbAPI.ps1"
. "$ExtensionPath\VideoParser.ps1"
. "$ExtensionPath\TauTulliAPI.ps1"
. "$ExtensionPath\HttpAPI.ps1"
. "$ExtensionPath\INIAPI.ps1"

##*===============================================
##* CONFIGS
##*===============================================
# get/save external data
[string]$IMDBMovieDataPath = Join-Path $StoredDataDir -ChildPath "IMDBMovieData"
[string]$TMDBMovieDataPath = Join-Path $StoredDataDir -ChildPath "TMDBMovieData"
[string]$RemovedMoviePath = Join-Path $StoredDataDir -ChildPath "RemovedMovieData"
[string]$AddedMoviePath = Join-Path $StoredDataDir -ChildPath "AddedMovieData"
[string]$UpdatedMoviePath = Join-Path $StoredDataDir -ChildPath "UpdatedMovieData"

# PARSE RADARR CONFIG FILE
[Xml.XmlDocument]$RadarrConfigFile = (Get-Content "$ConfigPath\Radarr.xml" -ReadCount 0) -replace "&","&amp;"
[Xml.XmlElement]$RadarrConfigs = $RadarrConfigFile.RadarrAutomation.RadarrConfigs
[Xml.XmlElement]$RadarrSettings = $RadarrConfigFile.RadarrAutomation.GlobalSettings
[string]$RadarrURL = $RadarrConfigs.InternalURL
[string]$RadarrPort = $RadarrConfigs.Port
[string]$RadarrAPIkey = $RadarrConfigs.API
[string]$OMDBAPI = $RadarrSettings.OMDBAPI
[string]$TMDBAPI = $RadarrSettings.TMDBAPI
[string]$MoviesDir = $RadarrSettings.MoviesRootPath

[string]$FilterSeriesFolders = ($RadarrSettings.MovieSeriesFolders.Folder) -join "|"
[string]$FilterOtherFolders = ($RadarrSettings.FilterMovieSubFolders.Folder) -join "|"

# Update Data Configs
[boolean]$UpdateJustMovieSeries = [boolean]::Parse($RadarrSettings.UpdateMovieSeriesOnly)

#Get Todays Date
$RunningDate = Get-Date -Format MMddyyyy

$AddMovietoRadarr = $true
$UnmatchedMovieReport = @()
$ExistingMovieReport = @()
$WrongMovieReport = @()
$AddedMovieReport = @()
$NoMovieInfoReport = @()
$FailedMovieReport = @()

$DoAction = $False



# Get all movies in Radarr (this is required for additonal details)
$ExistingRadarrMovies = Get-RadarrMovies
<#TESTS

$ExistingRadarrMovies | Where Path -like '*Disney*' | Select Studio,genres -unique
$ExistingRadarrMovies | Where Path -like '*Superhero*' | Select Studio,genres
$ExistingRadarrMovies | Where Path -like '*Girls*' | Select Studio,genres
$ExistingRadarrMovies | Where Path -like '*Holidays*' | Select Studio,genres
$ExistingRadarrMovies | Where Path -like '*Mysteries*' | Select Title,genres,Overview
$ExistingRadarrMovies | Where Path -like '*Family*' | Select Studio,genres
$ExistingRadarrMovies | Where Path -like '*Fantasy*' | Select Studio,genres
$ExistingRadarrMovies | Where Path -like '*History*' | Select Title,Studio,year,genres,overview
$ExistingRadarrMovies | Where Path -like '*Thrillers*' | Select Title,Studio,genres
$ExistingRadarrMovies | Where Path -like '*Action*' | Select Title,Studio,genres
$ExistingRadarrMovies | Where Path -like '*Drama*' | Select Title,Studio,genres
$ExistingRadarrMovies | Where Path -like '*Westerns*' | Select Title,genres,overview
$ExistingRadarrMovies | Where Path -like '*Comedies*' | Select Title,genres,year,overview
$ExistingRadarrMovies | Where {$_.Studio -eq 'United Artists' -or $_.Studio -eq 'Eon Productions'} | Select Title,studio,year,genres,overview
$ExistingRadarrMovies | Where {$_.Overview -like '* sports *'} | Select Title,studio,genres,overview


$MovieInRadarr = $ExistingRadarrMovies[0]
$ExistingRadarrMovies | Where title -eq 'Mary Queen of Scots'
 
$ExistingRadarrMovies | Where title -like 'Monster High:*'
#>

## BUILD GENRE MAPPINGS
##---------------------
#add folder paths to each genre tag
$MoviesGenreMappings = @{}
[PSCustomObject]$MoviesGenreMappings = $MovieInRadarrConfigs.GenreMappings.Map
Foreach($genre in $MoviesGenreMappings){
    #$FolderPath = Get-ChildItem $MoviesDir | Where Name -eq $genre.BindingFolder | Select -First 1
    $FolderPath = Join-Path -Path $MoviesDir -ChildPath $genre.BindingFolder
    If($FolderPath){
        $MoviesGenreMappings | Where Tag -eq $genre.Tag | Add-Member -MemberType NoteProperty -Name 'FolderPath' -Value $FolderPath -Force
    }
}


Foreach($MovieInRadarr in $ExistingRadarrMovies){
    If($MovieInRadarr.movieFile.path){
        $MovieInfo = ConvertTo-MovieData -Value (Split-Path $MovieInRadarr.movieFile.path -Leaf)
    }Else{
        $MovieInfo = ConvertTo-MovieData -Value $MovieInRadarr.Title
    }
    
    $OnlineMovie = Search-MovieTitle -Title $MovieInfo.Title -Year $MovieInfo.Year -IMDBApiKey $OMDBAPI -TMDBApiKey $TMDBAPI
    
    [array]$genres = $MovieInRadarr.genres -split ','

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
                $UseObject = $MovieInRadarr
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
                If($MovieInRadarr.genres){
                    $UseObject = $MovieInRadarr
                    $PropertyValue = $UseObject.genres -join '|'
                }
                Else{
                    $UseObject = $OnlineMovie
                    $PropertyValue = $UseObject.genres -replace ',','|'
                }
            }
            Else{
                $UseObject = $MovieInRadarr
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
                }
                Else{
                    Write-Host 'No' -ForegroundColor Red
                }
            }
        }

    }#end genre mapping loop
    
    If($MatchedMapping){
        Write-Host ("[{0}] will be mapped to [{1}]" -f $UseObject.title,$MatchedMapping.FolderPath) -ForegroundColor Green
    }
}#end movie loop



#=======================================================
# MAIN
#=======================================================
If(!$AllMoviesGenres)
{
    #build list of movie genres from folder
    Write-Host "Grabbing all movie Genre folders..."
    $AllMoviesGenres = Get-ChildItem $MoviesDir -ErrorAction SilentlyContinue -Exclude 'Requests','Pre-roll' -Directory

    #get list of movie folders within the genre folders
    Write-Host "Grabbing all movie folders..."
    $MovieDirectoryStructure = $AllMoviesGenres | %{Get-ChildItem $MoviesDir -Recurse -ErrorAction SilentlyContinue -Directory | Select Name, FullName}

    #Get the collection folder names
    $MovieCollectionNames = Split-Path $MovieDirectoryStructure.FullName -Leaf | Where-Object {$_ -match "Collection" -or $_ -match "Anthology"} | Select -Unique

    #only get the movie sets located in collection folders
    Write-Host "Grabbing all movie series..."
    $MovieSeries = $MovieDirectoryStructure | Where-Object {$_.FullName -match "Collection" -or $_.FullName -match "Anthology" -and $_.Name -notin $MovieCollectionNames}

    #Grab all Movies folder only , filtering out other folder strucutre elements
    #Also populated series full directory
    $AllMovieFolders=@()
    $AllMoviesCollectionFolders=@()
    $MovieDirectoryStructure | Where-Object {
        If($_.Name -notin $AllMoviesGenres.Name){
            If($_.Name -notin $MovieCollectionNames){
                $AllMovieFolders += $_
            }Else{
                If($_.Name -notin $AllMoviesCollectionFolders.Name){
                    $AllMoviesCollectionFolders += $_
                }
            }
        }
    }

    #build radarr list
    Write-Host "Grabbing all movies in Radarr..."
    $RadarrGetArgs = @{Headers = @{"X-Api-Key" = $radarrAPIkey}
                    URI = "http://${radarrURL}:${radarrPort}/api/v3/movie"
                    Method = "Get"
                }
    $radarrWebRequest = Invoke-WebRequest @RadarrGetArgs
    $radarrmovies = $radarrWebRequest.Content | ConvertFrom-Json
}

If($UpdateJustMovieSeries){
    $MovieSelection = $MovieSeries
}Else{
    $MovieSelection = $AllMovieFolders
}

Write-Host "Comparing all movies on disk to what is in Radarr..."
foreach ($Movie in $MovieSelection)
{
    #be sure to clear any settings each time
    $IMDBMovieInfo = $null
    $TMDBMovieInfo = $null

    <#
    #tests
    $movieName = '13 Hours The Secret Soldiers of Benghazi'
    $movieName = 'Gone in Sixty Seconds'


    #>
    Write-Host "---------------------------------------" -ForegroundColor Cyan
    Write-Host ("Processing Movie [{0}]" -f $Movie.Name) -ForegroundColor Cyan
    $yearfound = $Movie.Name -match ".?\((.*?)\).*"
    If($yearfound)
    {
        $year = $matches[1]
        $movieName = ($Movie.Name).replace("($year)","").Trim()
    }
    Else{
        $movieName = $Movie.Name
    }

    #remove unsupported characters for easier search results

    #normailze any special characters such as: å,ä,ö,Ã,Å,Ä,Ö,é
    $movieName = $movieName.Normalize("FormD") -replace '\p{M}'

    #replace the Ã© with e (pokemon titles)
    $movieName = $movieName.replace('Ã©','e')

    #remove any special characters but keep apstraphe '
    $Regex = "[^{\p{L}\p{Nd}\'}]+"
    If($movieName -match $Regex)
    {
        $MovieValue = $movieName -replace $Regex, " "
    }
    Else{
        $MovieValue = $movieName
    }

    #remove double spaces
    $MovieValue = $MovieValue -replace'\s+', ' '

    #replace & with and
    $MovieValue = $MovieValue.replace('&','and').Trim()

    #get TMDB and IMDB information
    Write-Host ("Searching for movie [{0}] in local copy of IMDB and TMDB data..." -f $MovieValue) -ForegroundColor Yellow

    #Grab Local Copy of Imdb and TMDB data (Saves on API calls)
    #force the imported data into an array using @()
    $LocalIMDBData = @(Get-ChildItem $IMDBMovieDataPath -filter '*.xml')
    $LocalTMDBData = @(Get-ChildItem $TMDBMovieDataPath -filter '*.xml')

    #import meta if there is an IMDB local file with same name as movie
    If($LocalIMDBFile = $LocalIMDBData | Where BaseName -eq $MovieValue){
        Write-Host ("Movie [{0}] was found in local copy of IMDB" -f $MovieValue) -ForegroundColor Green
        $IMDBMovieInfo = Import-Clixml $LocalIMDBFile.FullName
    }
    Else
    {
        #If meta is not found, call OMDB API
        Write-Host ("Searching for movie [{0}] in OMDB" -f $MovieValue) -ForegroundColor Yellow
        If($yearfound)
        {
            $IMDBMovieInfo = Get-ImdbTitle -Title $MovieValue -Year $year -Api $OMDBAPI -ErrorAction SilentlyContinue
        }
        Else
        {
            $IMDBMovieInfo = Get-ImdbTitle -Title $MovieValue -Api $OMDBAPI -ErrorAction SilentlyContinue
        }

        #if movie is found in OMDB, store meta for later processing
        If($IMDBMovieInfo){
            Write-Host ("   IMDB movie found: [{0}]" -f $IMDBMovieInfo.Title) -ForegroundColor DarkYellow
            #($LocalIMDBData += $IMDBMovieInfo) | Export-Clixml $IMDBDatafile
            #$IMDBMovieInfo | Export-Clixml ($IMDBMovieDataPath +'\'+ $MovieValue + '_' + $IMDBMovieInfo.Year + '_ImdbData.xml')
            $IMDBMovieInfo | Export-Clixml ($IMDBMovieDataPath + '\' + $MovieValue + '.xml')
        }
        Else
        {
            Write-Host "   IMDB movie was not found" -ForegroundColor DarkRed

        }
    }

    #import meta if there is an TMDB local file with same name as movie
    If($LocalTMDBFile = $LocalTMDBData | Where BaseName -eq $MovieValue){
        Write-Host ("Movie [{0}] was found in local copy of TMDB" -f $MovieValue) -ForegroundColor Green
        $TMDBMovieInfo = Import-Clixml $LocalTMDBFile.FullName
    }
    Else
    {
        Write-Host ("Searching for movie [{0}] in TMDB" -f $MovieValue) -ForegroundColor Yellow
        If($yearfound)
        {
            $TMDBMovieInfo = Find-TMDBItem -Type Movie -SearchAction ByType -Title $MovieValue -Year $year -ApiKey $TMDBAPI -SelectFirst -ErrorAction SilentlyContinue
        }
        Else
        {
            $TMDBMovieInfo = Find-TMDBItem -Type Movie -SearchAction ByType -Title $MovieValue -ApiKey $TMDBAPI  -SelectFirst -ErrorAction SilentlyContinue
        }

        #if movie is found in TMDB, store meta for later processing
        If($TMDBMovieInfo){
            Write-Host ("   TMDB movie found: [{0}]" -f $TMDBMovieInfo.Title) -ForegroundColor DarkYellow
            #($LocalTMDBData += $TMDBMovieInfo) | Export-Clixml $TMDBDatafile
            #$TMDBMovieInfo | Export-Clixml ($TMDBMovieDataPath +'\'+ $MovieValue + '_' + $TMDBMovieInfo.Year + '_TmdbData.xml')
            $TMDBMovieInfo | Export-Clixml ($TMDBMovieDataPath + '\' + $MovieValue + '.xml')
        }
        Else
        {
            Write-Host "   TMDB movie was not found" -ForegroundColor DarkRed
        }
    }

    ##===============================
    ## MATCH MOVIE FOR RADAAR
    ##===============================
    #Must continue with both IMDB and TMDB Info
    If($IMDBMovieInfo -and $TMDBMovieInfo)
    {
        #if both IMDB and TMDB has the same title continue, if not stop that one and go to next
        #format the titles so that there are no special characters to spaces to ensure it a good match
        $CleanIMDBTitle = ($IMDBMovieInfo.Title -replace '[\W]', '').ToLower()
        $CleanTMDBTitle = ($TMDBMovieInfo.Title -replace '[\W]', '').ToLower()

        If($CleanIMDBTitle -ne $CleanTMDBTitle){
            Write-Host ("Movie information does not match from TMDB and IMDB. Unable to parse correctly, skipping..." -f $IMDBMovieInfo.Title) -ForegroundColor Red
            $UnmatchedMovie = New-Object System.Object
            $UnmatchedMovie | Add-Member -Type NoteProperty -Name SearchName -Value $MovieValue
            $UnmatchedMovie | Add-Member -Type NoteProperty -Name SearchYear -Value $year
            $UnmatchedMovie | Add-Member -Type NoteProperty -Name ImdbID -Value $IMDBMovieInfo.imdbID
            $UnmatchedMovie | Add-Member -Type NoteProperty -Name ImdbTitle -Value $IMDBMovieInfo.title
            $UnmatchedMovie | Add-Member -Type NoteProperty -Name ImdbYear -Value $IMDBMovieInfo.year
            $UnmatchedMovie | Add-Member -Type NoteProperty -Name TmdbID -Value $TMDBMovieInfo.tmdbID
            $UnmatchedMovie | Add-Member -Type NoteProperty -Name TmdbTitle -Value $TMDBMovieInfo.Title
            #add to another array for reporting
            $UnmatchedMovieReport += $UnmatchedMovie

            $AddMovietoRadarr = $false
            Continue
        }
        Else{
            Write-Host ("Found matching movie information for [{0}] from both TMDB and IMDB." -f $IMDBMovieInfo.Title) -ForegroundColor Green
        }
    }
    Else{
        Write-Host ("Not enough information was found for [{0}]. Unable to add to Radarr." -f $MovieValue) -ForegroundColor Red
        $NoMovieInfo = New-Object System.Object
        $NoMovieInfo | Add-Member -Type NoteProperty -Name SearchName -Value $MovieValue
        $NoMovieInfo | Add-Member -Type NoteProperty -Name SearchYear -Value $year
        $NoMovieInfo | Add-Member -Type NoteProperty -Name ImdbID -Value $IMDBMovieInfo.imdbID
        $NoMovieInfo | Add-Member -Type NoteProperty -Name TmdbID -Value $TMDBMovieInfo.tmdbID
        #add to another array for reporting
        $NoMovieInfoReport += $NoMovieInfo

        $AddMovietoRadarr = $false
        Continue
    }

    #replace movie titles that have a - with :
    #$RealMovieName = $movieName.replace(" -",":")
    $RealMovieName = $MovieValue

    ##===============================
    ## FIND MOVIE IN RADAAR
    ##===============================
    #now determine if radarr has a matching movie based on IMDB and its path
    $ImdbInRadarr = $radarrmovies | Where {($_.imdbId -eq $IMDBMovieInfo.imdbID) -and ($_.tmdbId -eq $TMDBMovieInfo.tmdbID)}
    $PathInRadarr = $radarrmovies | Where {$_.path -eq $Movie.FullName}

    If($ImdbInRadarr -or $PathInRadarr)
    {
        #set this frist
        $AddMovietoRadarr = $false

        #Populate movie info
        $MovieInRadarr = New-Object System.Object
        $MovieInRadarr | Add-Member -Type NoteProperty -Name RadarrTitle -Value $ImdbInRadarr.title
        $MovieInRadarr | Add-Member -Type NoteProperty -Name RadarrYear -Value $ImdbInRadarr.year
        $MovieInRadarr | Add-Member -Type NoteProperty -Name RadarrfolderName -Value $ImdbInRadarr.folderName
        $MovieInRadarr | Add-Member -Type NoteProperty -Name RadarrID -Value $ImdbInRadarr.ID
        $MovieInRadarr | Add-Member -Type NoteProperty -Name RadarrURL -Value ('http://'+ $RadarrURL + ':' + $radarrPort +'/movie/' + $ImdbInRadarr.titleSlug)


        #Compare imdb in search vs Radarr imdb is path exists in Radarr
        #if its the wrong imdb add it the report. FUTURE is to fix it
        If($PathInRadarr -and ($PathInRadarr.imdbID -ne $IMDBMovieInfo.imdbID) )
        {
            Write-Host ("Movie [{0}] name is incorrect, removing from Radarr to reprocess later" -f $RealMovieName) -ForegroundColor Red
            Write-Host ("   Actual Name: {0}" -f $IMDBMovieInfo.Title)
            Write-Host ("   Actual Imdb: {0}" -f $IMDBMovieInfo.imdbId)
            Write-Host ("   Radarr Name: {0}" -f $PathInRadarr.title)
            Write-Host ("   Radarr Imdb: {0}" -f $PathInRadarr.imdbId)

            $deleteMovieArgs = @{Headers = @{"X-Api-Key" = $radarrAPIkey}
                    URI = "http://${radarrURL}:${radarrPort}/api/v3/movie/$($PathInRadarr.ID)"
                    Method = "Delete"
            }

            # DO REMOVAL
            If($DoAction){Invoke-WebRequest @deleteMovieArgs | Out-Null}

            #populate removed movie details
            $MovieInRadarr | Add-Member -Type NoteProperty -Name RadarrName -Value $PathInRadarr.title
            $MovieInRadarr | Add-Member -Type NoteProperty -Name RadarrImdb -Value $PathInRadarr.imdbId
            $MovieInRadarr | Add-Member -Type NoteProperty -Name ActualName -Value $IMDBMovieInfo.Title
            $MovieInRadarr | Add-Member -Type NoteProperty -Name ActualImdb -Value $IMDBMovieInfo.imdbId
            $MovieReport += $MovieInRadarr

            #Export removed movie info to file
            $MovieReport | Export-Clixml ($RemovedMoviePath + "\RemovedMovieReport" + "_" + $RunningDate + ".xml")

            #Set this to true to add to radarr later on
            $AddMovietoRadarr = $true

            Start-sleep 1
        }

        #since both IMDB matched, check its video path to ensure its that right video
        #if its the wrong path add it the report. FUTURE is to fix it
        ElseIf("$($ImdbInRadarr.Path)" -ne "$($Movie.FullName)")
        {
            Write-Host ("Movie [{0}] path is incorrect, updating Radarr's path" -f $RealMovieName) -ForegroundColor Red
            Write-Host ("   Actual Path: {0}" -f $Movie.FullName)
            Write-Host ("   Radarr Path: {0}" -f $ImdbInRadarr.Path)
            Write-Host ("   Radarr Imdb: {0}" -f $ImdbInRadarr.imdbId)

            Write-Host ("Grabbing {0} from Radarr, using ID [{1}]..." -f $ImdbInRadarr.title,$ImdbInRadarr.ID) -ForegroundColor Gray
            $RadarrGetMovieID = @{Headers = @{"X-Api-Key" = $radarrAPIkey}
                            URI = "http://${radarrURL}:${radarrPort}/api/v3/movie/$($ImdbInRadarr.ID)"
                            Method = "Get"
                        }
            # DO GET
            $radarrGetIDRequest = Invoke-WebRequest @RadarrGetMovieID
            $radarrMovieID = $radarrGetIDRequest.Content | ConvertFrom-Json

            Start-sleep 1

            #replace the value
            $radarrMovieID.folderName=$Movie.FullName
            $radarrMovieID.path=$Movie.FullName
            $radarrMovieID.PSObject.Properties.Remove('movieFile')
            #convert PSObject back into JSON format
            $body = $radarrMovieID | ConvertTo-Json #| % { [System.Text.RegularExpressions.Regex]::Unescape($_) }

            $RadarrUpdateMovieID = @{Headers = @{"X-Api-Key" = $radarrAPIkey}
                        URI = "http://${radarrURL}:${radarrPort}/api/v3/movie/$($ImdbInRadarr.ID)"
                        Method = "Put"
                    }

            # DO UPDATE
            If($DoAction){Invoke-WebRequest @RadarrUpdateMovieID -Body $body | Out-Null}

            #populate removed movie details
            $MovieInRadarr | Add-Member -Type NoteProperty -Name RadarrIMDB -Value $ImdbInRadarr.imdbId
            $MovieInRadarr | Add-Member -Type NoteProperty -Name RadarrPath -Value $ImdbInRadarr.Path
            $MovieInRadarr | Add-Member -Type NoteProperty -Name ActualPath -Value $Movie.FullName
            $WrongMovieReport += $MovieInRadarr

            #Export removed movie info to file
            $MovieReport | Export-Clixml ($UpdatedMoviePath + "\UpdatedMovieReport" + "_" + $RunningDate + ".xml")

            #Set this to true to add to radarr later on
            $AddMovietoRadarr = $true

            Start-sleep 1
        }
        Else
        {
            Write-Host ("Movie [{0}] was found in Radarr's database, ignoring" -f $RealMovieName) -ForegroundColor Green

            $ExistingMovie = New-Object System.Object
            $ExistingMovie | Add-Member -Type NoteProperty -Name id -Value $ImdbInRadarr.id
            $ExistingMovie | Add-Member -Type NoteProperty -Name Title -Value $ImdbInRadarr.title
            $ExistingMovie | Add-Member -Type NoteProperty -Name year -Value $ImdbInRadarr.year
            $ExistingMovie | Add-Member -Type NoteProperty -Name RadarrURL -Value ('http://'+ $RadarrURL + ':' + $radarrPort +'/movie/' + $ImdbInRadarr.titleSlug)

            #add to another array for reporting
            $ExistingMovieReport += $ExistingMovie
        }
    }
    Else{
        Write-Host ("Movie [{0}] was not found in Radarr's database, adding to Radarr..." -f $RealMovieName) -ForegroundColor DarkBlue
        $AddMovietoRadarr = $true
    }

    ##===============================
    ## ADD MOVIE TO RADAAR
    ##===============================
    If($AddMovietoRadarr)
    {
        Write-Host ("Found Movie Information for {0}" -f $IMDBMovieInfo.Title)
        $Regex = "[^{\p{L}\p{Nd}\'}]+"

        [string]$actualName = $IMDBMovieInfo.Title
        [string]$sortName = ($IMDBMovieInfo.Title).ToLower()
        [string]$cleanName = (($IMDBMovieInfo.Title) -replace $Regex,"").Trim().ToLower()
        [string]$ActualYear = $IMDBMovieInfo.Year
        [string]$imdbID = $IMDBMovieInfo.imdbID
        #[string]$imdbID = ($IMDBMovieInfo.imdbID).substring(2,($IMDBMovieInfo.imdbID).length-2)
        [int32]$tmdbID = $TMDBMovieInfo.tmdbID
        [string]$Image = $TMDBMovieInfo.Poster
        [string]$simpleTitle = (($IMDBMovieInfo.Title).replace("'","") -replace $Regex,"-").Trim().ToLower()
        [string]$titleSlug = $simpleTitle + "-" + $TMDBMovieInfo.tmdbID
        $MovieRootPath = $Movie.FullName

        Write-Host ("Adding movie to Radarr: {0}" -f $actualName) -ForegroundColor Gray
        Write-Host ("   Path: {0}" -f $MovieRootPath)
        Write-Host ("   Imdb: {0}" -f $imdbID)
        Write-Host ("   Tmdb: {0}" -f $tmdbID)
        Write-Host ("   Slug: {0}" -f $titleSlug)
        Write-Host ("   Year: {0}" -f $ActualYear)

        #build New movie object
        $NewMovie = New-Object System.Object
        $NewMovie | Add-Member -Type NoteProperty -Name Title -Value $actualName
        $NewMovie | Add-Member -Type NoteProperty -Name Year -Value $ActualYear
        $NewMovie | Add-Member -Type NoteProperty -Name IMDB -Value $imdbID
        $NewMovie | Add-Member -Type NoteProperty -Name TMDB -Value $tmdbID
        $NewMovie | Add-Member -Type NoteProperty -Name TitleSlug -Value $titleslug
        $NewMovie | Add-Member -Type NoteProperty -Name FolderPath -Value $MovieRootPath
        $NewMovie | Add-Member -Type NoteProperty -Name RadarrPath -Value ('http://' + $RadarrURL + ':' + $radarrPort + '/movie/' + $titleslug)

        $Body = @{ title=$actualName;
            sortTitle=$sortName;
            cleanTitle=$cleanName;
            qualityProfileId="1";
            year=$ActualYear;
            tmdbid=$tmdbID;
            imdbid=$imdbID;
            titleslug=$titleSlug;
            monitored="true";
            path=$MovieRootPath;
            images=@( @{
                covertype="poster";
                url=$Image
            } )
        }
        $BodyObj = ConvertTo-Json -InputObject $Body #| % { [System.Text.RegularExpressions.Regex]::Unescape($_) }
        #$BodyArray = ConvertFrom-Json -InputObject $BodyObj

        $RadarrPostArgs = @{Headers = @{"X-Api-Key" = $radarrAPIkey}
                        URI = "http://${radarrURL}:${radarrPort}/api/v3/movie"
                        Method = "Post"
                }
        try
        {
            #add to another array for reporting
            $AddedMovieReport += $NewMovie

            #Export movie info to file
            $AddedMovieReport | Export-Clixml ($AddedMoviePath + "\AddedMovieReport" + "_" + $RunningDate + "_Success.xml")

            # DO POST (ADD)
            If($DoAction){Invoke-WebRequest @RadarrPostArgs -Body $BodyObj | Out-Null}
        }
        catch {
            Write-Error -ErrorRecord $_

            #add to another array for reporting
            $FailedMovieReport += $NewMovie

            #Export movie info to file
            $FailedMovieReport | Export-Clixml ($AddedMoviePath + "\AddedMovieReport" + "_" + $RunningDate + "_Failed.xml")
            #Break
        }

        start-sleep 1
    }
}

#build radarr list
Write-Host "Grabbing all movies in Radarr again..."
$RadarrGetArgs = @{Headers = @{"X-Api-Key" = $radarrAPIkey}
                URI = "http://${radarrURL}:${radarrPort}/api/v3/movie"
                Method = "Get"
            }
$radarrWebRequest = Invoke-WebRequest @RadarrGetArgs
$radarrmovies = $radarrWebRequest.Content | ConvertFrom-Json

Write-Host ("Existing Movies   : {0}" -f $ExistingMovieReport.Count)
Write-Host ("Unmatched Movies  : {0}" -f $UnmatchedMovieReport.Count)
Write-Host ("Wrong Movies      : {0}" -f $WrongMovieReport.Count)
Write-Host ("Added Movies      : {0}" -f $AddedMovieReport.Count)
Write-Host ("Failed Movies     : {0}" -f $FailedMovieReport.Count)
Write-Host ("No Info for Movie : {0}" -f $NoMovieInfoReport.Count)

Stop-Transcript