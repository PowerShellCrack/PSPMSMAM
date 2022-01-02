
Function Convert-NumberToWord([string]$string,[int]$digit,[switch]$PastTense){
    If($digit){
        $digit -match '(\d+)' | Out-Null
    }
    Else{
        $string -match '\D+(\d+)' | Out-Null
    }

    switch ($Matches[1]){
        "0" {[string]$toWord = 'Zero'}
        "1" {If($PastTense){[string]$toWord = 'First'}Else{[string]$toWord = 'One'}}
        "2" {If($PastTense){[string]$toWord = 'Second'}Else{[string]$toWord = 'Two'}}
        "3" {If($PastTense){[string]$toWord = 'Third'}Else{[string]$toWord = 'Three'}}
        "4" {If($PastTense){[string]$toWord = 'Fouth'}Else{[string]$toWord = 'Four'}}
        "5" {If($PastTense){[string]$toWord = 'Fifth'}Else{[string]$toWord = 'Five'}}
        "6" {If($PastTense){[string]$toWord = 'Sixth'}Else{[string]$toWord = 'Six'}}
        "7" {If($PastTense){[string]$toWord = 'Seventh'}Else{[string]$toWord = 'Seven'}}
        "8" {If($PastTense){[string]$toWord = 'Eighth'}Else{[string]$toWord = 'Eight'}}
        "9" {If($PastTense){[string]$toWord = 'Nineth'}Else{[string]$toWord = 'Nine'}}
        "10" {If($PastTense){[string]$toWord = 'Tenth'}Else{[string]$toWord = 'Ten'}}
        "11" {If($PastTense){[string]$toWord = 'Eleventh'}Else{[string]$toWord = 'Eleven'}}
        "12" {If($PastTense){[string]$toWord = 'Twelveth'}Else{[string]$toWord = 'Twelve'}}
        "13" {If($PastTense){[string]$toWord = 'Thirteenth'}Else{[string]$toWord = 'Thirteen'}}
        default {[string]$toWord = $null}
    }
    If($digit){
        $Value = $toWord
    }
    Else{
        $Value = ($String) -replace $Matches[1],$toWord
    }
    Return $Value
}

Function Convert-WordToNumber([string]$string){
    $Value = $null
    switch -regex ("b\$string\b"){
        'zero'  {[string]$toWord = '0'}
        'one'   {[string]$toWord = '1'}
        'two'   {[string]$toWord = '2'}
        'three' {[string]$toWord = '3'}
        'four'  {[string]$toWord = '4'}
        'five'  {[string]$toWord = '5'}
        'six'   {[string]$toWord = '6'}
        'seven' {[string]$toWord = '7'}
        'eight' {[string]$toWord = '8'}
        'nine'  {[string]$toWord = '9'}
        'ten'   {[string]$toWord = '10'}
        'eleven'{[string]$toWord = '11'}
        'twelve'{[string]$toWord = '12'}
        "thirteen" {[string]$toWord = '13'}
        default {[string]$toWord = $null}
    }

    $Value = ($String) -replace $Matches[0],$toWord
    Return $Value
}

Function Search-MovieTitle{
    [CmdletBinding(DefaultParameterSetName='Title')]
    param (
        [Parameter(ParameterSetName='Title', Mandatory=$true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string]
        $Title,

        [Parameter(ParameterSetName='Title', ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [string[]]
        $AlternateTitles,

        [Parameter(ParameterSetName='Title', ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true)]
        [int]
        $Year,

        [Parameter(Mandatory=$true)]
        [string]
        $IMDBApiKey,

        [Parameter(Mandatory=$true)]
        [string]
        $TMDBApiKey,

        [Parameter(Mandatory=$false)]
        [switch]
        $ReturnBoolean,

        [Parameter(Mandatory=$false)]
        [switch]
        $RequireBoth

    )
    Begin{
        $AllTitles = @()
        $IMDBMovieTitles = @()
        $TMDBMovieTitles = @()
        $IMDBMovieInfo = $null
        $TMDBMovieInfo = $null
        $NoSpecialIMDBTitles = $null
        $NoSpecialTMDBTitles = $null

        $ContinueToSearch = $true
    }
    Process{
        #if a year was found within the name, query IMDB and TMDB for name and year for a better match
        If($Year){
            $ParamHash = @{Year = $Year}
            $YearLabel = " with year [$Year]"
        }

        If($AlternateTitles){
            $AllTitles = $AlternateTitles + $title | Select -Unique
        }Else{
            $AllTitles += $Title
        }

        [int]$Count = 1


        If($ContinueToSearch -and $AllTitles){
            #TEST $WorkingTitle = $AllTitles[0]
            #TEST $WorkingTitle = $AllTitles[1]
            Foreach ($WorkingTitle in $AllTitles){
                
                $SearchCountlabel = Convert-NumberToWord -digit $Count -PastTense

                If($ContinueToSearch -and $WorkingTitle){
                    Write-Host ("{0} search for alternate movie title [{1}]{2} in IMDB..." -f $SearchCountlabel,$WorkingTitle,$YearLabel) -ForegroundColor Gray -NoNewline
                    $IMDBMovieInfo = Get-ImdbTitle -Title $WorkingTitle @ParamHash -Api $IMDBApiKey -ErrorAction SilentlyContinue
                    If($IMDBMovieInfo){Write-Host ("Found {0}" -f $IMDBMovieInfo.Count)}Else{Write-Host "Found 0"}
                    If(!$Year){$Year = $IMDBMovieInfo.Year}

                    Write-Host ("{0} search for alternate movie title [{1}]{2} in TMDB..." -f $SearchCountlabel,$WorkingTitle,$YearLabel) -ForegroundColor Gray -NoNewline
                    $TMDBMovieInfo = Find-TMDBItem -Type Movie -SearchAction ByType -Title $WorkingTitle @ParamHash -ApiKey $TMDBApiKey -SelectFirst -ErrorAction SilentlyContinue
                    If($TMDBMovieInfo){Write-Host ("Found {0}" -f $TMDBMovieInfo.Count)}Else{Write-Host "Found 0"}
                    If(!$Year){$Year = (Get-Date $TMDBMovieInfo.ReleaseDate -Format yyyy -ErrorAction SilentlyContinue)}

                    $NoSpecialIMDBTitles = ($IMDBMovieInfo.Title -replace 'é','e' -replace "[^{\p{L}\p{Nd}\'}]+", " ").Normalize("FormD") -replace '\p{M}'
                    $NoSpecialTMDBTitles = ($TMDBMovieInfo.Title -replace 'é','e' -replace "[^{\p{L}\p{Nd}\'}]+", " ").Normalize("FormD") -replace '\p{M}'

                    If($RequireBoth -and (!$NoSpecialIMDBTitles -and !$NoSpecialTMDBTitles) ){
                        Write-Host ("Movie information for [{0}]{1} is not available from ") -NoNewline -ForegroundColor Red
                        If($NoSpecialIMDBTitles){
                            Write-Host ("IMDB") -NoNewline -ForegroundColor Green
                        }Else{
                            Write-Host ("IMDB") -NoNewline -ForegroundColor Red
                        }
                        Write-Host (" and/or ") -NoNewline -ForegroundColor Red
                        
                        If($NoSpecialTMDBTitles){
                            Write-Host ("TMDB") -NoNewline -ForegroundColor Green
                        }Else{
                            Write-Host ("TMDB") -NoNewline -ForegroundColor Red
                        }
                        Write-Host (". Both are required!") -ForegroundColor Red
                        $ContinueToSearch = $true
                    }
                    ElseIf(!$RequireBoth -and ($NoSpecialIMDBTitles -or $NoSpecialTMDBTitles)){
                        If($NoSpecialIMDBTitles){
                             Write-Host ("Movie information was found from IMDB [{0}]{1}" -f $NoSpecialIMDBTitles,$YearLabel) -ForegroundColor Gray
                             $MatchedMovieTitle = $IMDBMovieInfo.Title
                        }
                        If($NoSpecialTMDBTitles){
                             $MatchedMovieTitle = $TMDBMovieInfo.Title
                             Write-Host ("Movie information was found from TMDB [{0}]{1}" -f $NoSpecialTMDBTitles,$YearLabel) -ForegroundColor Gray
                        }
                        $ContinueToSearch = $false
                    }
                    ElseIf($NoSpecialIMDBTitles -ne $NoSpecialTMDBTitles){
                        If(( (Convert-WordToNumber $NoSpecialIMDBTitles) -eq (Convert-WordToNumber $NoSpecialTMDBTitles) ) -or ( (Convert-NumberToWord $NoSpecialIMDBTitles) -eq (Convert-NumberToWord $NoSpecialTMDBTitles) )){
                            Write-Host ("Movie information was matched from both IMDB [{0}] and TMDB [{1}]{2}" -f $NoSpecialIMDBTitles,$NoSpecialTMDBTitles,$YearLabel) -ForegroundColor Green
                            $MatchedMovieTitle = $IMDBMovieInfo.Title
                            $ContinueToSearch = $false
                            Continue
                        }
                        Else{
                            Write-Host ("Movie information does not match from IMDB [{0}] and TMDB [{1}]{2}" -f $IMDBMovieInfo.Title,$TMDBMovieInfo.Title,$YearLabel) -ForegroundColor Red
                            $ContinueToSearch = $true
                        }
                    }
                    Else{
                        Write-Host ("Movie information was matched from both IMDB [{0}] and TMDB [{1}]{2}" -f $NoSpecialIMDBTitles,$NoSpecialTMDBTitles,$YearLabel) -ForegroundColor Green
                        $MatchedMovieTitle = $IMDBMovieInfo.Title
                        $ContinueToSearch = $false
                        Continue
                    }
                }
            }

            $Count = $Count + 1
        } #end title search

    }
    End{
        #if a title was found and boolean return not specified
        If(!$ReturnBoolean -and ($IMDBMovieInfo -or $TMDBMovieInfo)){
            $returnObjects = @()

            $returnObject = New-Object System.Object
            If($IMDBMovieInfo){
                $returnObject | Add-Member -Type NoteProperty -Name Title -Value $IMDBMovieInfo.title
                $returnObject | Add-Member -Type NoteProperty -Name Year -Value $IMDBMovieInfo.year
                $returnObject | Add-Member -Type NoteProperty -Name Rated -Value $IMDBMovieInfo.Rated
                $returnObject | Add-Member -Type NoteProperty -Name Released -Value $IMDBMovieInfo.Released
                $returnObject | Add-Member -Type NoteProperty -Name Runtime -Value $IMDBMovieInfo.Runtime
                $returnObject | Add-Member -Type NoteProperty -Name Director -Value $IMDBMovieInfo.Director
                $returnObject | Add-Member -Type NoteProperty -Name Writer  -Value $IMDBMovieInfo.Writer
                $returnObject | Add-Member -Type NoteProperty -Name Actors -Value $IMDBMovieInfo.Actors
                $returnObject | Add-Member -Type NoteProperty -Name Plot -Value $IMDBMovieInfo.Plot
                $returnObject | Add-Member -Type NoteProperty -Name Language -Value $IMDBMovieInfo.Language
                $returnObject | Add-Member -Type NoteProperty -Name Country -Value $IMDBMovieInfo.Country 
                $returnObject | Add-Member -Type NoteProperty -Name Awards -Value $IMDBMovieInfo.Awards
                $returnObject | Add-Member -Type NoteProperty -Name Poster  -Value $IMDBMovieInfo.Poster
                $returnObject | Add-Member -Type NoteProperty -Name Ratings  -Value $IMDBMovieInfo.Ratings
                $returnObject | Add-Member -Type NoteProperty -Name Metascore -Value $IMDBMovieInfo.Metascore
                $returnObject | Add-Member -Type NoteProperty -Name imdbRating -Value $IMDBMovieInfo.imdbRating 
                $returnObject | Add-Member -Type NoteProperty -Name imdbVotes  -Value $IMDBMovieInfo.imdbVotes
                $returnObject | Add-Member -Type NoteProperty -Name imdbID  -Value $IMDBMovieInfo.imdbID
                $returnObject | Add-Member -Type NoteProperty -Name Type  -Value $IMDBMovieInfo.Type
                $returnObject | Add-Member -Type NoteProperty -Name DVD  -Value $IMDBMovieInfo.DVD
                $returnObject | Add-Member -Type NoteProperty -Name BoxOffice  -Value $IMDBMovieInfo.BoxOffice
                $returnObject | Add-Member -Type NoteProperty -Name Production -Value $IMDBMovieInfo.Production
                $returnObject | Add-Member -Type NoteProperty -Name Website  -Value $IMDBMovieInfo.Website
                If(!$TMDBMovieInfo){
                    $returnObject | Add-Member -Type NoteProperty -Name Genres -Value ($IMDBMovieInfo.Genre -split ',').Trim()
                }
            }
            If($TMDBMovieInfo){
                #If IMDB does not return data, use TMDB's data
                If(!$IMDBMovieInfo){
                    $returnObject | Add-Member -Type NoteProperty -Name Title -Value $TMDBMovieInfo.title
                    $returnObject | Add-Member -Type NoteProperty -Name Poster -Value $TMDBMovieInfo.Poster
                    $returnObject | Add-Member -Type NoteProperty -Name Language -Value $TMDBMovieInfo.Language
                    $returnObject | Add-Member -Type NoteProperty -Name Year -Value $TMDBMovieInfo.year
                }
                $returnObject | Add-Member -Type NoteProperty -Name TotalVotes -Value $TMDBMovieInfo.TotalVotes
                $returnObject | Add-Member -Type NoteProperty -Name tmdbID -Value $TMDBMovieInfo.tmdbID
                $returnObject | Add-Member -Type NoteProperty -Name Video -Value $TMDBMovieInfo.Video
                $returnObject | Add-Member -Type NoteProperty -Name VoteAverage -Value $TMDBMovieInfo.VoteAverage
                
                $returnObject | Add-Member -Type NoteProperty -Name Popularity -Value $TMDBMovieInfo.popularity
                
                $returnObject | Add-Member -Type NoteProperty -Name OriginalTitle -Value $TMDBMovieInfo.OriginalTitle
                $returnObject | Add-Member -Type NoteProperty -Name Genres -Value ($TMDBMovieInfo.Genres -split ',').Trim()
                $returnObject | Add-Member -Type NoteProperty -Name Backdrop -Value $TMDBMovieInfo.Backdrop
                $returnObject | Add-Member -Type NoteProperty -Name Adult -Value $TMDBMovieInfo.Adult
                $returnObject | Add-Member -Type NoteProperty -Name Overview -Value $TMDBMovieInfo.overview
                $returnObject | Add-Member -Type NoteProperty -Name ReleaseDate -Value $TMDBMovieInfo.ReleaseDate
                
            }

            #combine genres 
            If($IMDBMovieInfo.Genre -and $TMDBMovieInfo.Genres){
                $returnObject.Genres = ($IMDBMovieInfo.Genre -split ',').Trim() + ($TMDBMovieInfo.Genres -split ',').Trim() | Select -Unique
            }

            $returnObjects += $returnObject

            return $returnObjects
        }
        #if both title was found and boolean return WAS specified
        ElseIf($RequireBoth -and $IMDBMovieInfo -and $TMDBMovieInfo){
            return $true
        }
        #if both title was not found and boolean return WAS specified
        ElseIf($RequireBoth -and (!$IMDBMovieInfo -or !$TMDBMovieInfo)){
            return $false
        }
        #if a title was found and boolean return WAS specified
        ElseIf($IMDBMovieInfo -or $TMDBMovieInfo){
            return $true
        }
        #if a title was NOT found and boolean return WAS specified
        Else{
            return $false
        }
    }
}
