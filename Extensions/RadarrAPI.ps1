$global:ApiPath = 'api/v3'

<#
    .LINK
    https://github.com/Radarr/Radarr/wiki/API:Movie



    .EXAMPLES
        rescan movies
        $movie_id = $env:radarr_movie_id
        $params = @{"name"="RescanMovie";"movieId"="$movie_id";} | ConvertTo-Json
        Invoke-WebRequest -Uri "http://localhost:7878/${global:ApiPath}/command?apikey=$radarrAPI" -Method POST -Body $params

        #find an movied in drone factory folder
        $params = @{"name"="DownloadedMoviesScan"} | ConvertTo-Json
        Invoke-WebRequest -Uri "http://localhost:7878/${global:ApiPath}/command?apikey=$radarrAPI" -Method POST -Body $params

        #find missing movies
        $params = @{"name"="missingMoviesSearch";"filterKey"="status";"filterValue"="released"} | ConvertTo-Json
        Invoke-WebRequest -Uri "http://localhost:7878/${global:ApiPath}/command?apikey=$radarrAPI" -Method POST -Body $params

        $MovieName =
            $MovieRootPath = 'E:\Media\Movies\Superhero & Comics\Thor Collection\Thor - Ragnarok (2017)'

            $Body = @{ title="Thor: Ragnarok";
                        qualityProfileId="1";
                        year=2017;
                        tmdbid="284053";
                        titleslug="thor: ragnarok-284053";
                        monitored="true";
                        path=$MovieRootPath;
                        images=@( @{
                            covertype="poster";
                            url="https://image.tmdb.org/t/p/w174_and_h261_bestv2/avy7IR8UMlIIyE2BPCI4plW4Csc.jpg"
                        } )
                     }


            $BodyObj = ConvertTo-Json -InputObject $Body

            $BodyArray = ConvertFrom-Json -InputObject $BodyObj

            $iwrArgs = @{Headers = @{"X-Api-Key" = $radarrAPIkey}
                            URI = "http://localhost:7878/${global:ApiPath}/movie"
                            Method = "POST"
                    }

                Invoke-WebRequest @iwrArgs -Body $BodyObj | Out-Null

        curl -H "Content-Type: application/json" -X POST -d '{"title":"Thor: Ragnarok","qualityProfileId":"6","tmdbid":"284053","titleslug":"thor: ragnarok-284053", "monitored":"true", "rootFolderPath":"H:/Video/Movies/", "images":[{"covertype":"poster","url":"https://image.tmdb.org/t/p/w174_and_h261_bestv2/avy7IR8UMlIIyE2BPCI4plW4Csc.jpg"}]}' http://192.168.1.111/radarr/${global:ApiPath}/movie?apikey=xxxxx
        curl -H "Content-Type: application/json" -X POST -d '{"title":"Proof","qualityProfileId":"4","apikey":"[MYAPIKEY]", "tmdbid":"14904","titleslug":"proof-14904", "monitored":"true", "rootFolderPath":"/Volume1/Movies/", "images":[{"covertype":"poster","url":"https://image.tmdb.org/t/p/w640/ghPbOsvg8WrJQBSThtNakBGuDi4.jpg"}]}' http://192.168.1.10:8310/${global:ApiPath}/movie
#>

Function Get-RadarrMovie{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0,
            ParameterSetName="Id")]
        [int32]$MovieId,

        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0,
            ParameterSetName="Title")]
        [string]$MovieTitle,

        [Parameter(Mandatory=$false)]
        [int]$Year,

        [Parameter(Mandatory=$false)]
        [string]$URL = 'http://localhost',

        [Parameter(Mandatory=$false)]
        [string]$Port = '7878',

        [Parameter(Mandatory=$false)]
        [string]$Api,

        [Parameter(Mandatory=$false)]
        [switch]$AsObject
    )
    Begin{
        #if global setting found use those instead fo defualt
        If($Global:RadarrURL -and $Global:RadarrPort){
            [string]$URI = Get-RadarrURI "${Global:RadarrURL}:${Global:RadarrPort}/${global:ApiPath}/movie"
        }
        Else{
            [string]$URI = Get-RadarrURI "${URL}:${Port}/${global:ApiPath}/movie"
        }

        If ($PSCmdlet.ParameterSetName -eq "Title") {
            $query = "lookup?&term=$MovieTitle"
        }
        If ($PSCmdlet.ParameterSetName -eq "Id") {
            $query = "$MovieId"
        }

        #use global API or check if specified APi is not null
        If($Global:RadarrAPIkey){
            $Api = $Global:RadarrAPIkey
        }
        Elseif($Api -eq $null){
            Throw "-Api parameter is mandatory"
        }

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference')
        }

    }
    Process {
        $RadarrGetArgs = @{Headers = @{"X-Api-Key" = $Api}
                    URI = "$URI/$query"
                    Method = "Get"
        }
        If($PSBoundParameters.ContainsKey('Verbose')){Write-Verbose $RadarrGetArgs.URI}

        try {
            $request = Invoke-WebRequest @RadarrGetArgs -UseBasicParsing -Verbose:$VerbosePreference
            $MovieObj = $request.Content | ConvertFrom-Json -Verbose:$VerbosePreference
        }
        catch {
            Write-Error -ErrorRecord $_
        }
    }
    End{
        If([boolean]$AsObject){
            If($PSBoundParameters.ContainsKey('year')){
                return ($MovieObj | where year -eq $Year | Select -First 1)
            }Else{
                return $MovieObj
            }

        }
        Else{
            return $request.Content
        }
    }
}

Function Get-RadarrMovies{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [string]$URL = 'http://localhost',

        [Parameter(Mandatory=$false)]
        [string]$Port = '7878',

        [Parameter(Mandatory=$false)]
        [string]$Api
    )
    Begin{
        #if global setting found use those instead fo defualt
        If($Global:RadarrURL -and $Global:RadarrPort){
            [string]$URI = Get-RadarrURI "${Global:RadarrURL}:${Global:RadarrPort}/${global:ApiPath}/movie"
        }
        Else{
            [string]$URI = Get-RadarrURI "${URL}:${Port}/${global:ApiPath}/movie"
        }

        #use global API or check if specified APi is not null
        If($Global:RadarrAPIkey){
            $Api = $Global:RadarrAPIkey
        }
        Elseif($Api -eq $null){
            Throw "-Api parameter is mandatory"
        }

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference')
        }
    }
    Process {
        $RadarrGetArgs = @{Headers = @{"X-Api-Key" = $Api}
                    URI = $URI
                    Method = "Get"
                }

        If($PSBoundParameters.ContainsKey('Verbose')){Write-Verbose $RadarrGetArgs.URI}

        Try{
            $Request = Invoke-WebRequest @RadarrGetArgs -UseBasicParsing -Verbose:$VerbosePreference
            $MovieObj = $Request.Content | ConvertFrom-Json -Verbose:$VerbosePreference
            Write-Verbose ("Found {0} Movies" -f $MovieObj.Count)
        }
        Catch{
            Write-Host ("Unable to connect to Radarr, error {0}" -f $_.Exception.Message)
        }
    }
    End {
        return $MovieObj

    }
}


#Remove all movies
Function Remove-RadarrMovies{
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    param (
        [Parameter(Mandatory=$false)]
        [string]$URL = 'http://localhost',

        [Parameter(Mandatory=$false)]
        [string]$Port = '7878',

        [Parameter(Mandatory=$false)]
        [string]$Api,

        [Parameter(Mandatory=$false)]
        [switch]$UnmonitoredOnly
    )
    Begin{
        #if global setting found use those instead fo defualt
        If($Global:RadarrURL -and $Global:RadarrPort){
            [string]$URI = Get-RadarrURI "${Global:RadarrURL}:${Global:RadarrPort}/${global:ApiPath}/movie"
        }
        Else{
            [string]$URI = Get-RadarrURI "${URL}:${Port}/${global:ApiPath}/movie"
        }

        #use global API or check if specified APi is not null
        If($Global:RadarrAPIkey){
            $Api = $Global:RadarrAPIkey
        }
        Elseif($Api -eq $null){
            Throw "-Api parameter is mandatory"
        }

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference')
        }
        if (-not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = $PSCmdlet.SessionState.PSVariable.GetValue('ConfirmPreference')
        }
        if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
            $WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
        }
        #Write-Verbose ('[{0}] Confirm={1} ConfirmPreference={2} WhatIf={3} WhatIfPreference={4}' -f $MyInvocation.MyCommand, $Confirm, $ConfirmPreference, $WhatIf, $WhatIfPreference)
    }
    Process {
        $removeMovies = @()
        If($UnmonitoredOnly){
            $i=1
            while ($i -le 500) {
                $iwrArgs = @{Headers = @{"X-Api-Key" = $radarrAPIkey}
                            URI = "$URI/.$i"
                    }

                try {
                    $movie = Invoke-WebRequest @iwrArgs | Select-Object -ExpandProperty Content | ConvertFrom-Json -Verbose:$VerbosePreference
                    if ($movie.downloaded -eq $true -or $movie.monitored -eq $false) {
                        Write-Host "Adding $($movie.title) to list of movies to be removed." -ForegroundColor Red
                        $removeMovies += $movie
                    }
                    else {
                        Write-Host "$($movie.title) is monitored. Skipping." -ForegroundColor Gray
                    }
                }
                catch {
                    Write-Host "Empty ID#$i or bad request"
                }
                $i++

            }
        }
        Else{
            $removeMovies = Get-AllRadarrMovies -Api $radarrAPIkey -Verbose:$VerbosePreference
        }

        Write-Host "Proceeding to remove $($removeMovies.count) movies!" -ForegroundColor Yellow
        If($PSBoundParameters.ContainsKey('Confirm')){
            $confirmation = Read-Host "Confirm`nAre you sure you want to perform this action`nPerforming the operation '"'Remove-AllRadarrMovies'"' on $($removeMovies.count) movies`n[Y] Yes to All"
            if ($confirmation -eq 'y') {
                Continue
            }
            Else{
                Return
            }
        }

        $deletecount = 0
        foreach ($downloadedMovie in $removeMovies){


            $iwrArgs = @{Headers = @{"X-Api-Key" = $radarrAPIkey}
                    URI = "$URI/.$($downloadedMovie.id)"
                    Method = "Delete"
            }

            If($PSBoundParameters.ContainsKey('WhatIf')){
                Write-Host ('What if: Performing the operation "Remove Movie" on target "{0}"' -f $downloadedMovie.title)
            }
            Else{
                Try{
                    $Request = Invoke-WebRequest @iwrArgs -Verbose:$VerbosePreference
                    Write-Host "Removed $($downloadedMovie.title)!" -ForegroundColor Green
                    $deletecount ++
                }
                Catch{
                    Write-Host ("Unable to delete movie {0}, error {1}" -f $downloadedMovie.title,$_.Exception.Message)
                }
            }
        }
    }
    End{
        Write-Ver ("{0} movies were removed from Radarr" -f $deletecount)
    }
}

#Remove movie
Function Remove-RadarrMovie{
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    param (
        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0,
            ParameterSetName="Id")]
        [int32]$Id,

        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0,
            ParameterSetName="Title")]
        [string]$Title,

        [Parameter(Mandatory=$false)]
        [string]$URL = 'http://localhost',

        [Parameter(Mandatory=$false)]
        [string]$Port = '7878',

        [Parameter(Mandatory=$false)]
        [string]$Api,

        [Parameter(Mandatory=$false)]
        [switch]$Report
    )
    Begin{
        #if global setting found use those instead fo defualt
        If($Global:RadarrURL -and $Global:RadarrPort){
            [string]$URI = Get-RadarrURI "${Global:RadarrURL}:${Global:RadarrPort}/${global:ApiPath}/movie"
        }
        Else{
            [string]$URI = Get-RadarrURI "${URL}:${Port}/${global:ApiPath}/movie"
        }

        #use global API or check if specified APi is not null
        If($Global:RadarrAPIkey){
            $Api = $Global:RadarrAPIkey
        }
        Elseif($Api -eq $null){
            Throw "-Api parameter is mandatory"
        }

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference')
        }
        if (-not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = $PSCmdlet.SessionState.PSVariable.GetValue('ConfirmPreference')
        }
        if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
            $WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
        }
        #Write-Verbose ('[{0}] Confirm={1} ConfirmPreference={2} WhatIf={3} WhatIfPreference={4}' -f $MyInvocation.MyCommand, $Confirm, $ConfirmPreference, $WhatIf, $WhatIfPreference)
    }
    Process {
        If ($PSCmdlet.ParameterSetName -eq "Title") {
            $ExistingMovie = Get-RadarrMovie -MovieTitle $Title -Api $Api -AsObject
        }
        If ($PSCmdlet.ParameterSetName -eq "Id") {
            $ExistingMovie = Get-RadarrMovie -MovieId $Id -Api $Api -AsObject
        }

        If($ExistingMovie){
            Write-Host ("Removing Movie [{0}] from Radarr..." -f $ExistingMovie.Title) -ForegroundColor Yellow
            If($PSBoundParameters.ContainsKey('Verbose')){
                Write-Host ("   Title:") -ForegroundColor Gray -NoNewline
                    Write-Host (" {0}" -f $ExistingMovie.Title)
                Write-Host ("   Radarr ID:") -ForegroundColor Gray -NoNewline
                    Write-Host (" {0}" -f $ExistingMovie.id)
                Write-Host ("   Imdb:") -ForegroundColor Gray -NoNewline
                    Write-Host (" {0}" -f $ExistingMovie.imdbId)
                Write-Host ("   Path:") -ForegroundColor Gray -NoNewline
                    Write-Host (" {0}" -f $ExistingMovie.path)
            }

            If($PSBoundParameters.ContainsKey('Confirm')){
                $confirmation = Read-Host "Confirm`nAre you sure you want to perform this action`nPerforming the operation '"'Remove-RadarrMovie'"' on $($ExistingMovie.Title)`n[Y] Yes"
                if ($confirmation -eq 'y') {
                    Continue
                }
                Else{
                    Return
                }
            }

            $deleteMovieArgs = @{Headers = @{"X-Api-Key" = $Api}
                                URI = "$URI/$Id"
                                Method = "Delete"
            }

            If($PSBoundParameters.ContainsKey('WhatIf')){
                Write-Host ('What if: Performing the operation "Remove Movie" on target "{0}"' -f $ExistingMovie.Title)
            }
            Else{
                try
                {
                    $Request = Invoke-WebRequest @deleteMovieArgs -Verbose:$VerbosePreference
                    $DeleteStatus = $true
                }
                catch {
                    Write-Host ("Unable to delete movie {0}, error {1}" -f $ExistingMovie.Title,$_.Exception.Message)
                    $DeleteStatus = $false
                    #Break
                }
            }

        }
        Else{
            Write-Host ("Movie with ID [{0}] does not exist in Radarr..." -f $Id) -ForegroundColor Yellow
            $DeleteStatus = $false
        }

    }
    End {
        If($Report -and $ExistingMovie){
            $MovieReport = @()
            $Movie = New-Object System.Object
            $Movie | Add-Member -Type NoteProperty -Name Id -Value $ExistingMovie.Id
            $Movie | Add-Member -Type NoteProperty -Name Title -Value $ExistingMovie.Title
            $Movie | Add-Member -Type NoteProperty -Name Year -Value $ExistingMovie.Year
            $Movie | Add-Member -Type NoteProperty -Name IMDB -Value $ExistingMovie.imdbID
            $Movie | Add-Member -Type NoteProperty -Name TMDB -Value $ExistingMovie.tmdbID
            $Movie | Add-Member -Type NoteProperty -Name TitleSlug -Value $ExistingMovie.titleslug
            $Movie | Add-Member -Type NoteProperty -Name FolderPath -Value $ExistingMovie.Path
            $Movie | Add-Member -Type NoteProperty -Name Deleted -Value $DeleteStatus
            $MovieReport += $Movie

            Return $MovieReport
        }
        ElseIf($Report -and !$ExistingMovie){
            $MovieReport = @()
            $Movie = New-Object System.Object
            $Movie | Add-Member -Type NoteProperty -Name Id -Value $ExistingMovie.Id
            $MovieReport += $Movie

            Return $MovieReport

        }
        Else{

            Return $DeleteStatus
        }

    }
}

Function New-RadarrMovie {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    param (


        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string]$Title,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string]$Year,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [string]$imdbID,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [int32]$tmdbID,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias('Poster')]
        [string]$PosterImage,

        [Parameter(Mandatory=$true)]
        [string]$Path,

        [Parameter(Mandatory=$false)]
        [switch]$SearchAfterImport,

        [Parameter(Mandatory=$false)]
        [string]$URL = 'http://localhost',

        [Parameter(Mandatory=$false)]
        [string]$Port = '7878',

        [Parameter(Mandatory=$false)]
        [string]$Api,

        [Parameter(Mandatory=$false)]
        [switch]$Report
    )
    Begin{
        #if global setting found use those instead fo defualt
        If($Global:RadarrURL -and $Global:RadarrPort){
            [string]$URI = Get-RadarrURI "${Global:RadarrURL}:${Global:RadarrPort}/${global:ApiPath}/movie"
        }
        Else{
            [string]$URI = Get-RadarrURI "${URL}:${Port}/${global:ApiPath}/movie"
        }

        #use global API or check if specified APi is not null
        If($Global:RadarrAPIkey){
            $Api = $Global:RadarrAPIkey
        }
        Elseif($Api -eq $null){
            Throw "-Api parameter is mandatory"
        }

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference')
        }
        if (-not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = $PSCmdlet.SessionState.PSVariable.GetValue('ConfirmPreference')
        }
        if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
            $WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
        }
        #Write-Verbose ('[{0}] Confirm={1} ConfirmPreference={2} WhatIf={3} WhatIfPreference={4}' -f $MyInvocation.MyCommand, $Confirm, $ConfirmPreference, $WhatIf, $WhatIfPreference)
    }
    Process {
        <# TEST
        $Title='Scream 2'
        $Path='E:\Media\Movies\Mysteries & Horrors\Scream 2 (1997)\Scream 2 (1997) - Bluray-1080p.mp4'
        $Imdbid='tt0120082'
        $TmdbId= 4233
        $Year='1997'
        $PosterImage='https://image.tmdb.org/t/p/original/mumarnp1ZBHFdmt2q6x9ELuC3x0.jpg'
        #>
        
        If($VerbosePreference -eq "Continue"){Write-Host ("Processing details for movie title [{0}]..." -f $Title)}
        [string]$actualName = $Title
        [string]$sortName = ($Title).ToLower()
        $Regex = "[^{\p{L}\p{Nd}\'}]+"
        [string]$cleanName = (($Title) -replace $Regex,"").Trim().ToLower()
        [int32]$ActualYear = $Year
        [string]$imdbID = $imdbID
        #[string]$imdbID = ($imdbID).substring(2,($imdbID).length-2)
        [int32]$tmdbID = $tmdbID
        [string]$Image = $PosterImage
        [string]$simpleTitle = (($Title).replace("'","") -replace $Regex,"-").Trim().ToLower()
        [string]$titleSlug = $simpleTitle + "-" + $tmdbID
        Write-Host ("Adding movie [{0}] to Radarr database..." -f $actualName) -ForegroundColor Yellow
        If($VerbosePreference -eq "Continue"){
            Write-Host ("   Title:") -ForegroundColor Gray -NoNewline
                Write-Host (" {0}" -f $actualName)
            Write-Host ("   Path:") -ForegroundColor Gray -NoNewline
                Write-Host (" {0}" -f $Path)
            Write-Host ("   Imdb:") -ForegroundColor Gray -NoNewline
                Write-Host (" {0}" -f $imdbID)
            Write-Host ("   Tmdb:") -ForegroundColor Gray -NoNewline
                Write-Host (" {0}" -f $tmdbID)
            Write-Host ("   Slug:") -ForegroundColor Gray -NoNewline
                Write-Host (" {0}" -f $titleSlug)
            Write-Host ("   Year:") -ForegroundColor Gray -NoNewline
                Write-Host (" {0}" -f $ActualYear)
            Write-Host ("   Poster:") -ForegroundColor Gray -NoNewline
                Write-Host (" {0}" -f $Image)
        }

        $Body = @{ title=$actualName;
            sortTitle=$sortName;
            cleanTitle=$cleanName;
            qualityProfileId=1;
            year=$ActualYear;
            tmdbid=$tmdbID;
            imdbid=$imdbID;
            titleslug=$titleSlug;
            monitored=$true;
            path=$Path;
            addOptions=@{
                searchForMovie=[boolean]$SearchAfterImport
            };
            images=@( @{
                covertype="poster";
                url=$Image
            } );
        }

        $BodyObj = ConvertTo-Json -InputObject $Body #| % { [System.Text.RegularExpressions.Regex]::Unescape($_) }
        #$BodyArray = ConvertFrom-Json -InputObject $BodyObj

        $RadarrPostArgs = @{Headers = @{"X-Api-Key" = $Api}
                        URI = $URI
                        Method = "Post"
                }


        If($PSBoundParameters.ContainsKey('WhatIf')){
            Write-Host ('What if: Performing the operation "New Movie" on target "{0}"' -f $actualName)
        }
        Else{
            try
            {
                $Request = Invoke-WebRequest @RadarrPostArgs -Body $BodyObj -Verbose:$VerbosePreference
                Write-Verbose "Invoke API using JSON: $BodyObj"
                $ImportStatus = $true

            }
            catch {
                Write-Host ("Unable to add movie {0}, error {1}" -f $actualName,$_.Exception.Message)
                $ImportStatus = $false
                #Break
            }
        }
    }
    End {
        If(!$Report){
            Return $ImportStatus
        }
        Else{
            $MovieReport = @()
            $Movie = New-Object System.Object
            $Movie | Add-Member -Type NoteProperty -Name Title -Value $actualName
            $Movie | Add-Member -Type NoteProperty -Name Year -Value $ActualYear
            $Movie | Add-Member -Type NoteProperty -Name IMDB -Value $imdbID
            $Movie | Add-Member -Type NoteProperty -Name TMDB -Value $tmdbID
            $Movie | Add-Member -Type NoteProperty -Name TitleSlug -Value $titleslug
            $Movie | Add-Member -Type NoteProperty -Name FolderPath -Value $Path
            $Movie | Add-Member -Type NoteProperty -Name RadarrUrl -Value ('http://' + $URL + ':' + $Port + '/movie/' + $titleSlug)
            $Movie | Add-Member -Type NoteProperty -Name Imported -Value $ImportStatus
            $MovieReport += $Movie

            Return $MovieReport

        }

    }
}

Function Update-RadarrMoviePath {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='Medium')]
    param (

        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0,
            ParameterSetName="Id")]
        [int32]$Id,

        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0,
            ParameterSetName="Title")]
        [string]$Title,

        [Parameter(Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0,
            ParameterSetName="Object")]
        [psobject]$InputObject,

        [Parameter(Mandatory=$false)]
        [int]$Year,

        [Parameter(Mandatory=$false)]
        [string]$URL = 'http://localhost',

        [Parameter(Mandatory=$false)]
        [string]$Port = '7878',

        [Parameter(Mandatory=$false)]
        [string]$Api,

        [Parameter(Mandatory=$true)]
        [Alias('ActualPath')]
        [string]$DestinationPath,

        [Parameter(Mandatory=$false)]
        [switch]$Report
    )
    Begin{
        #if global setting found use those instead fo defualt
        If($Global:RadarrURL -and $Global:RadarrPort){
            [string]$URI = Get-RadarrURI "${Global:RadarrURL}:${Global:RadarrPort}/${global:ApiPath}/movie"
        }
        Else{
            [string]$URI = Get-RadarrURI "${URL}:${Port}/${global:ApiPath}/movie"
        }

        #use global API or check if specified APi is not null
        If($Global:RadarrAPIkey){
            $Api = $Global:RadarrAPIkey
        }
        Elseif($Api -eq $null){
            Throw "-Api parameter is mandatory"
        }

        if (-not $PSBoundParameters.ContainsKey('Verbose')) {
            $VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference')
        }
        if (-not $PSBoundParameters.ContainsKey('Debug')) {
            $DebugPreference = $PSCmdlet.SessionState.PSVariable.GetValue('DebugPreference')
        }
        if (-not $PSBoundParameters.ContainsKey('Confirm')) {
            $ConfirmPreference = $PSCmdlet.SessionState.PSVariable.GetValue('ConfirmPreference')
        }
        if (-not $PSBoundParameters.ContainsKey('WhatIf')) {
            $WhatIfPreference = $PSCmdlet.SessionState.PSVariable.GetValue('WhatIfPreference')
        }
        #Write-Verbose ('[{0}] Confirm={1} ConfirmPreference={2} WhatIf={3} WhatIfPreference={4}' -f $MyInvocation.MyCommand, $Confirm, $ConfirmPreference, $WhatIf, $WhatIfPreference)
    }
    Process {
        #Grab current movie in Radarr

        If($PSBoundParameters.ContainsKey('year')){
            $Param = @{
                Year = $Year
                Api = $Api
                AsObject=$true
            }
        }Else{
            $Param = @{
                Api = $Api
                AsObject=$true
            }
        }

        If ($PSCmdlet.ParameterSetName -eq "Title") {
            [psobject]$ExistingMovie = Get-RadarrMovie -MovieTitle $Title @Param
        }
        If ($PSCmdlet.ParameterSetName -eq "Id") {
            [psobject]$ExistingMovie = Get-RadarrMovie -MovieId $Id @Param
        }

        If ($PSCmdlet.ParameterSetName -eq "Object") {
            #TEST $InputObject = $MovieObject
            #TEST $DestinationPath = $DestinationPath
            [psobject]$ExistingMovie = $InputObject
        }

        If(!$ExistingMovie){Throw "No Movie found, unable to update..."}

        #Write-Host ("Adding movie [{0}] to Radarr database..." -f $actualName) -ForegroundColor Gray
        If($VerbosePreference -eq "Continue"){
            Write-Host ("Movie [{0}] path is incorrect; updating Radarr's path..." -f $ExistingMovie.title) -ForegroundColor Yellow
             Write-Host ("   Old Path:") -ForegroundColor Gray -NoNewline
                 Write-Host (" {0}" -f $ExistingMovie.folderName) -ForegroundColor Gray
            Write-Host ("   New Path:") -ForegroundColor Gray -NoNewline
                 Write-Host (" {0}" -f $DestinationPath)

        }

        #update PSObject values
        $Id = $ExistingMovie.id
        $ExistingMovie.folderName = $DestinationPath
        $ExistingMovie.path = $DestinationPath

        #remove current uneeded info
        $ExistingMovie.PSObject.Properties.Remove('movieFile')
        $ExistingMovie.PSObject.Properties.Remove('alternatetitles')

        #convert PSObject back into JSON format
        $BodyObj = $ExistingMovie | ConvertTo-Json #| % { [System.Text.RegularExpressions.Regex]::Unescape($_) }

        $RadarrPutMovieID = @{Headers = @{"X-Api-Key"=$Api}
                    URI = "$URI/$Id"
                    Method = "Put"

                }
        try
        {
            If($DebugPreference -eq "Continue"){write-host ("Invoking [{0}] using JSON: {1}" -f ($URI + "/" + $Id),$BodyObj)}
            If(!$WhatIfPreference){Invoke-WebRequest @RadarrPutMovieID -Body $BodyObj -Verbose:$VerbosePreference -ErrorAction:$ErrorActionPreference}
            $UpdateStatus = $true

        }
        catch {
            If($VerbosePreference -eq "Continue"){Write-Error -ErrorRecord $_}
            $UpdateStatus = $false

        }
    }
    End {
        If(!$Report){
            Return $UpdateStatus
        }
        Else{
            $MovieReport = @()
            $Movie = New-Object System.Object
            $Movie | Add-Member -Type NoteProperty -Name ID -Value $Id
            $Movie | Add-Member -Type NoteProperty -Name Title -Value $ExistingMovie.Title
            $Movie | Add-Member -Type NoteProperty -Name Year -Value $ExistingMovie.Year
            $Movie | Add-Member -Type NoteProperty -Name OldPath -Value $ExistingMovie.Path
            $Movie | Add-Member -Type NoteProperty -Name NewPath -Value $DestinationPath
            $Movie | Add-Member -Type NoteProperty -Name Updated -Value $UpdateStatus
            $MovieReport += $Movie

            Return $MovieReport

        }
    }
}


Function Get-RadarrURI{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Uri]$URI,
        [System.Uri]$defaultURI = "http://localhost:7878"
    )

    Begin{
        $OriginalURI = $URI
        $validAddress = $null
    }
    Process{
        Try{
            If([system.uri]::IsWellFormedUriString($URI,[System.UriKind]::Absolute))
            {
                If($URI.Port -eq -1 -and $URI.LocalPath -match "(\d)"){
                    [System.Uri]$newURI = 'http://' + $URI.Scheme + ':' + $URI.LocalPath
                }
                Else{
                    [System.Uri]$newURI = $URI
                }

            }
            Else{
                [System.Uri]$newURI = 'http://' + $URI.OriginalString
            }
        }
        Catch{

        }


    }
    End{
        return $newURI.OriginalString
    }
}

Function Test-RadarrURI{
    [cmdletbinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Uri]$URI
    )
    try
    {
        (Invoke-WebRequest -Uri $URI -UseBasicParsing -DisableKeepAlive).StatusCode
    }
    catch [Net.WebException]
    {
        [int]$_.Exception.Response.StatusCode
    }
    finally{

    }

}