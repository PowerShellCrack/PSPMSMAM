<#
Imdb info

Title      : Red Dragon
Year       : 2002
Rated      : R
Released   : 04 Oct 2002
Runtime    : 124 min
Genre      : Crime, Drama, Thriller
Director   : Brett Ratner
Writer     : Thomas Harris (novel), Ted Tally (screenplay)
Actors     : Anthony Hopkins, Edward Norton, Ralph Fiennes, Harvey Keitel
Plot       : A retired F.B.I. Agent with psychological gifts is assigned to help track down "The Tooth Fairy", a mysterious serial killer. Aiding him is imprisoned forensic psychiatrist Dr. Hannibal "The Cannibal"
             Lecter.
Language   : English, French
Country    : Germany, USA
Awards     : 4 wins & 10 nominations.
Poster     : https://m.media-amazon.com/images/M/MV5BMTQ4MDgzNjM5MF5BMl5BanBnXkFtZTYwMjUwMzY2._V1_SX300.jpg
Ratings    : {@{Source=Internet Movie Database; Value=7.2/10}, @{Source=Rotten Tomatoes; Value=68%}, @{Source=Metacritic; Value=60/100}}
Metascore  : 60
imdbRating : 7.2
imdbVotes  : 222,645
imdbID     : tt0289765
Type       : movie
DVD        : 01 Apr 2003
BoxOffice  : $92,930,005
Production : Universal Pictures
Website    : http://www.reddragonmovie.com/
Response   : True
#>


Function Set-VideoNFO{
    [CmdletBinding()]
    Param
    (
    [string]$MovieFolder,
    [string]$imdbAPI,
    [string]$tmdbAPI,
    [string]$FFProbePath = 'D:\Data\Plex\DVRPostProcessingScript\ffmpeg\bin\ffprobe.exe'
    )

    $date = get-date -Format "yyy-MM-dd hh:mm:ss"

    $movie = Split-Path $MovieFolder -Leaf
    $yearfound = $MovieFolder -match ".?\((.*?)\).*"
    $MovieYear = $matches[1]
    $SearchMovieName = ($movie).replace("($MovieYear)","").Trim()
    $MovieFound = Get-ChildItem $MovieFolder -Include ('*.mp4','*.mkv','*.mpeg','*.mpg','*.avi','*.wmv') -Recurse
    If($MovieFound){
        [string]$NfoMovieName = [IO.Path]::GetFileNameWithoutExtension($MovieFound.Name)
        $MovieInfoFullPath = $MovieFolder + "\" + $NfoMovieName + ".nfo"
        $inCollection = $MovieFolder | Where-Object {$_.FullName -match "Collection" -or $_.FullName -match "Anthology"}
        $matches.Values

        $IMDB = Get-ImdbTitle -Title $SearchMovieName -Api $OMDBAPI -Year $MovieYear
        If($IMDB){
            $IMDBItem = Get-IMDBItem $IMDB.imdbID
            $IMDBMovie = Get-ImdbMovie -Title $SearchMovieName -Year $MovieYear
            $TMDBMovie = Find-TMDBItem -Type Movie -SearchAction ByType -ApiKey $TMDBAPI -Title $SearchMovieName -Year $MovieYear
            If($TMDBMovie){$tmdbid = $TMDBMovie.id}
        }Else{
            Return
        }
    }
    Else{
        return
    }



    $xml = $null
    $xml += "<?xml version=""1.0"" encoding=""UTF-8"" standalone=""yes""?>";$xml += "`r`n"
    $xml += "<!-- created on $date - powershell videoparser -->";$xml += "`r`n"
    $xml += "<movie>";$xml += "`r`n"
    $xml += "   <title>$($IMDB.Title)</title>";$xml += "`r`n"
    $xml += "   <originaltitle>$($IMDB.Title)</originaltitle>";$xml += "`r`n"
    If($inCollection){
        $xml += "   <set>";$xml += "`r`n"
        $xml += "       <name>$($matches.Values)</name>";$xml += "`r`n"
        $xml += "       <overview>$SetOverview</overview>";$xml += "`r`n"
        $xml += "   </set>";$xml += "`r`n"
    }
    $xml += "   <sorttitle></sorttitle>";$xml += "`r`n"
    $xml += "   <rating>$($IMDB.imdbRating)</rating>";$xml += "`r`n"
    $xml += "   <year>$($IMDB.Year)</year>";$xml += "`r`n"
    $xml += "   <top250>$top250</top250>";$xml += "`r`n"
    $xml += "   <votes>$($IMDB.imdbVotes)</votes>";$xml += "`r`n"
    $xml += "   <outline>$($IMDB.Plot)</outline>";$xml += "`r`n"
    $xml += "   <plot>$($IMDB.Plot)</plot>";$xml += "`r`n"
    $xml += "   <tagline>$($IMDBMovie.Taglines)</tagline>";$xml += "`r`n"
    $xml += "   <runtime>$($IMDB.Runtime)</runtime>";$xml += "`r`n"
    $xml += "   <thumb>$($TMDBMovie.Poster)</thumb>";$xml += "`r`n"
    $xml += "   <fanart>$($TMDBMovie.Backdrop)</fanart>";$xml += "`r`n"
    $xml += "   <mpaa>$($IMDB.Rated)</mpaa>";$xml += "`r`n"
    $xml += "   <certification>$certification</certification>";$xml += "`r`n"
    $xml += "   <id>$($IMDBItem.MPAARating)</id>";$xml += "`r`n"
    $xml += "   <ids>";$xml += "`r`n"
    $xml += "       <entry>";$xml += "`r`n"
    $xml += "           <key>imdb</key>";$xml += "`r`n"
    $xml += "           <value xsi:type='xs:string' xmlns:xs='http://www.w3.org/2001/XMLSchema' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'>$($IMDB.imdbid)</value>";$xml += "`r`n"
    $xml += "       </entry>";$xml += "`r`n"
    If($tmdbid){
        $xml += "       <entry>";$xml += "`r`n"
        $xml += "           <key>tmdb</key>";$xml += "`r`n"
        $xml += "           <value xsi:type='xs:int' xmlns:xs='http://www.w3.org/2001/XMLSchema' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'>$($TMDBMovie.id)</value>";$xml += "`r`n"
        $xml += "       </entry>";$xml += "`r`n"
        If($inCollection){
            $xml += "       <entry>";$xml += "`r`n"
            $xml += "           <key>tmdbSet</key>";$xml += "`r`n"
            $xml += "           <value xsi:type='xs:int' xmlns:xs='http://www.w3.org/2001/XMLSchema' xmlns:xsi='http://www.w3.org/2001/XMLSchema-instance'>$tmdbsetid</value>";$xml += "`r`n"
            $xml += "       </entry>";$xml += "`r`n"
        }
    }
    $xml += "   </ids>";$xml += "`r`n"
    $xml += "   <tmdbId>$($TMDBMovie.id)</tmdbId>";$xml += "`r`n"
    $xml += "   <trailer>$($IMDBMovie.Link)</trailer>";$xml += "`r`n"
    $xml += "   <country>$($IMDB.country)</country>";$xml += "`r`n"
    $xml += "   <premiered>>$($IMDB.Released)</premiered>";$xml += "`r`n"
    If($fileinfo){
        $xml += "   <fileinfo>";$xml += "`r`n"
        $xml += "       <streamdetails>";$xml += "`r`n"
        $xml += "           <video>";$xml += "`r`n"
        $xml += "               <codec>$vidcodec</codec>";$xml += "`r`n"
        $xml += "               <aspect>$sapect</aspect>";$xml += "`r`n"
        $xml += "               <width>$width</width>";$xml += "`r`n"
        $xml += "               <height>$height</height>";$xml += "`r`n"
        $xml += "               <durationinseconds>5546</durationinseconds>";$xml += "`r`n"
        $xml += "           </video>";$xml += "`r`n"
        Foreach($audio in $audiochanels){
            $xml += "           <audio>";$xml += "`r`n"
            $xml += "               <codec>$($audio.codec)</codec>";$xml += "`r`n"
            $xml += "               <language>$($audio.language)</language>";$xml += "`r`n"
            $xml += "               <channels>$($audio.channel)</channels>";$xml += "`r`n"
            $xml += "           </audio>";$xml += "`r`n"
        }
        $xml += "           <subtitle>";$xml += "`r`n"
        $xml += "               <language>$fileinfolang</language>";$xml += "`r`n"
        $xml += "           </subtitle>";$xml += "`r`n"
        $xml += "       </streamdetails>";$xml += "`r`n"
        $xml += "   </fileinfo>";$xml += "`r`n"
    }
    $xml += "   <watched>$watched</watched>";$xml += "`r`n"
    $xml += "   <playcount>$playcount</playcount>";$xml += "`r`n"
    Foreach($genre in $IMDB.Genre){
        $xml += "   <genre>$genre</genre>";$xml += "`r`n"
    }
    Foreach($studio in ($IMDBMovie.Production -split ",").Trim()){
        $xml += "   <studio>$studio</studio>";$xml += "`r`n"
    }
    Foreach($credit in $credits){
        $xml += "   <credits>$credit</credits>";$xml += "`r`n"
    }
    $xml += "   <director>$($IMDB.Director)</director>";$xml += "`r`n"
    Foreach($actor in $IMDB.actors){
        $xml += "   <actor>";$xml += "`r`n"
        $xml += "       <name>$actor</name>";$xml += "`r`n"
        $xml += "       <thumb>$($actor.thumb)</thumb>";$xml += "`r`n"
        $xml += "   </actor>";$xml += "`r`n"
    }
    Foreach($writer in ($IMDB.Writer -split ",").Trim()){
        $xml += "   <writer>";$xml += "`r`n"
        $xml += "       <name>$writer</name>";$xml += "`r`n"
        $xml += "   </writer>";$xml += "`r`n"
    }
    Foreach($producer in $IMDB.producer){
        $xml += "   <producer>";$xml += "`r`n"
        $xml += "       <name>$producer</name>";$xml += "`r`n"
        $xml += "   </producer>";$xml += "`r`n"
    }
    $xml += "   <languages>$($IMDB.language)</languages>";$xml += "`r`n"
    $xml += "</movie>";$xml += "`r`n"
    $xml | Out-File -FilePath $MovieInfoFullPath -Force
}

Function Get-VideoNFO{
    Param(
    [string]$MovieFolder
    )

    $MovieNfoFound = Get-ChildItem $MovieFolder -Include '*.nfo' -Recurse | Select -First 1
    If($MovieNfoFound){
        [xml]$NfoFile = Get-Content $MovieNfoFound
        [array]$Genres = ($NfoFile.movie.genre) -join ", "
        [string]$Languages = ($NfoFile.movie.languages) -join ", "
        [string]$Actors = ($NfoFile.movie.actor.Name | Select -First 4) -join ", "
        [string]$Writers = ($NfoFile.movie.writers.Name.writers | Select -First 4) -join ", "
        [string]$Producers = ($NfoFile.movie.producer.Name) -join ", "
        [string]$Countries = ($NfoFile.movie.country) -join ", "
        [string]$Studios = ($NfoFile.movie.studio) -join ", "
        If($NfoFile.movie.durationminutes){$duration = ($NfoFile.movie.durationminutes + ' min')}
        Else{$duration = ($NfoFile.movie.runtime + ' min')}
        If($NfoFile.movie.cover.name){
            $cover = $NfoFile.movie.cover.name | Select -First 1
        }
        $formattedDate = Get-Date($NfoFile.movie.premiered) -Format 'dd MMM yyyy'
        [string]$ReleaseDate = [DateTime]::ParseExact(($NfoFile.movie.releasedate.'#text').replace('.','/'), 'dd\/MM\/yyyy',[Globalization.CultureInfo]::InvariantCulture)
        $formattedReleasedDate = Get-Date($ReleaseDate) -Format 'dd MMM yyyy'

        $returnObject = New-Object System.Object
        $returnObject | Add-Member -Type NoteProperty -Name Title -Value $NfoFile.movie.title
        $returnObject | Add-Member -Type NoteProperty -Name Year -Value $NfoFile.movie.year
        $returnObject | Add-Member -Type NoteProperty -Name MPAARating -Value $NfoFile.movie.mpaa
        $returnObject | Add-Member -Type NoteProperty -Name Released -Value $formattedDate
        $returnObject | Add-Member -Type NoteProperty -Name RuntimeMinutes -Value $duration
        $returnObject | Add-Member -Type NoteProperty -Name Director -Value $NfoFile.movie.director
        $returnObject | Add-Member -Type NoteProperty -Name Writers -Value $Writers
        $returnObject | Add-Member -Type NoteProperty -Name Producers -Value $Producers
        $returnObject | Add-Member -Type NoteProperty -Name Actors -Value $Actors
        $returnObject | Add-Member -Type NoteProperty -Name Plot -Value $NfoFile.movie.plot
        $returnObject | Add-Member -Type NoteProperty -Name Language -Value $Languages
        $returnObject | Add-Member -Type NoteProperty -Name Country -Value $Countries
        $returnObject | Add-Member -Type NoteProperty -Name Poster -Value $cover
        $returnObject | Add-Member -Type NoteProperty -Name imdbRating -Value $NfoFile.movie.rating
        $returnObject | Add-Member -Type NoteProperty -Name imdbVotes -Value $NfoFile.movie.votes
        $returnObject | Add-Member -Type NoteProperty -Name imdbID -Value $NfoFile.movie.id
        $returnObject | Add-Member -Type NoteProperty -Name tmdbID -Value $NfoFile.movie.tmdbId
        $returnObject | Add-Member -Type NoteProperty -Name Type -Value 'movie'
        $returnObject | Add-Member -Type NoteProperty -Name Genre -Value $Genres
        $returnObject | Add-Member -Type NoteProperty -Name ReleaseDate -Value $formattedReleasedDate
        $returnObject | Add-Member -Type NoteProperty -Name Production -Value $Studios
        If($NfoFile.movie.set.name){$returnObject | Add-Member -Type NoteProperty -Name Set -Value $NfoFile.movie.set.name}

        Write-Output $returnObject
    }
}

function Get-HugeDirStats($directory) {
    function go($dir, $stats)
    {
        foreach ($f in [system.io.Directory]::EnumerateFiles($dir))
        {
            $stats.Count++
            $stats.Size += (New-Object io.FileInfo $f).Length
        }
        foreach ($d in [system.io.directory]::EnumerateDirectories($dir))
        {
            go $d $stats
        }
    }
    $statistics = New-Object PsObject -Property @{Count = 0; Size = [long]0 }
    go $directory $statistics

    $statistics
}

function Convert-ToBytes($num)
{
    $suffix = "B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"
    $index = 0
    while ($num -gt 1kb)
    {
        $num = $num / 1kb
        $index++
    }

    "{0:N1} {1}" -f $num, $suffix[$index]
}

#region Function Execute-Process
Function Execute-Process {
<#
.SYNOPSIS
	Execute a process with optional arguments, working directory, window style.
.DESCRIPTION
	Executes a process, e.g. a file included in the Files directory of the App Deploy Toolkit, or a file on the local machine.
	Provides various options for handling the return codes (see Parameters).
.PARAMETER Path
	Path to the file to be executed. If the file is located directly in the "Files" directory of the App Deploy Toolkit, only the file name needs to be specified.
	Otherwise, the full path of the file must be specified. If the files is in a subdirectory of "Files", use the "$dirFiles" variable as shown in the example.
.PARAMETER Parameters
	Arguments to be passed to the executable
.PARAMETER WindowStyle
	Style of the window of the process executed. Options: Normal, Hidden, Maximized, Minimized. Default: Normal.
	Note: Not all processes honor the "Hidden" flag. If it it not working, then check the command line options for the process being executed to see it has a silent option.
.PARAMETER CreateNoWindow
	Specifies whether the process should be started with a new window to contain it. Default is false.
.PARAMETER WorkingDirectory
	The working directory used for executing the process. Defaults to the directory of the file being executed.
.PARAMETER NoWait
	Immediately continue after executing the process.
.PARAMETER PassThru
	Returns ExitCode, STDOut, and STDErr output from the process.
.PARAMETER IgnoreExitCodes
	List the exit codes to ignore.
.PARAMETER ContinueOnError
	Continue if an exit code is returned by the process that is not recognized by the App Deploy Toolkit. Default: $false.
.EXAMPLE
	Execute-Process -Path 'uninstall_flash_player_64bit.exe' -Parameters '/uninstall' -WindowStyle 'Hidden'
	If the file is in the "Files" directory of the App Deploy Toolkit, only the file name needs to be specified.
.EXAMPLE
	Execute-Process -Path "$dirFiles\Bin\setup.exe" -Parameters '/S' -WindowStyle 'Hidden'
.EXAMPLE
	Execute-Process -Path 'setup.exe' -Parameters '/S' -IgnoreExitCodes '1,2'
.EXAMPLE
	Execute-Process -Path 'setup.exe' -Parameters "-s -f2`"$configToolkitLogDir\$installName.log`""
	Launch InstallShield "setup.exe" from the ".\Files" sub-directory and force log files to the logging folder.
.EXAMPLE
	Execute-Process -Path 'setup.exe' -Parameters "/s /v`"ALLUSERS=1 /qn /L* \`"$configToolkitLogDir\$installName.log`"`""
	Launch InstallShield "setup.exe" with embedded MSI and force log files to the logging folder.
.NOTES
    Taken from http://psappdeploytoolkit.com
.LINK

#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$true)]
		[Alias('FilePath')]
		[ValidateNotNullorEmpty()]
		[string]$Path,
		[Parameter(Mandatory=$false)]
		[Alias('Arguments')]
		[ValidateNotNullorEmpty()]
		[string[]]$Parameters,
		[Parameter(Mandatory=$false)]
		[ValidateSet('Normal','Hidden','Maximized','Minimized')]
		[Diagnostics.ProcessWindowStyle]$WindowStyle = 'Normal',
		[Parameter(Mandatory=$false)]
		[ValidateNotNullorEmpty()]
		[switch]$CreateNoWindow = $false,
		[Parameter(Mandatory=$false)]
		[ValidateNotNullorEmpty()]
		[string]$WorkingDirectory,
		[Parameter(Mandatory=$false)]
		[switch]$NoWait = $false,
		[Parameter(Mandatory=$false)]
		[switch]$PassThru = $false,
		[Parameter(Mandatory=$false)]
		[ValidateNotNullorEmpty()]
		[string]$IgnoreExitCodes,
		[Parameter(Mandatory=$false)]
		[ValidateNotNullorEmpty()]
		[boolean]$ContinueOnError = $false
	)

	Begin {
		## Get the name of this function and write header
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name
	}
	Process {
		Try {
			$private:returnCode = $null

			## Validate and find the fully qualified path for the $Path variable.
			If (([IO.Path]::IsPathRooted($Path)) -and ([IO.Path]::HasExtension($Path))) {
				If (-not (Test-Path -LiteralPath $Path -PathType 'Leaf' -ErrorAction 'Stop')) {
					Throw "File [$Path] not found."
				}
			}
			Else {
				#  The first directory to search will be the 'Files' subdirectory of the script directory
				[string]$PathFolders = $dirFiles
				#  Add the current location of the console (Windows always searches this location first)
				[string]$PathFolders = $PathFolders + ';' + (Get-Location -PSProvider 'FileSystem').Path
				#  Add the new path locations to the PATH environment variable
				$env:PATH = $PathFolders + ';' + $env:PATH

				#  Get the fully qualified path for the file. Get-Command searches PATH environment variable to find this value.
				[string]$FullyQualifiedPath = Get-Command -Name $Path -CommandType 'Application' -TotalCount 1 -Syntax -ErrorAction 'Stop'

				#  Revert the PATH environment variable to it's original value
				$env:PATH = $env:PATH -replace [regex]::Escape($PathFolders + ';'), ''

				If ($FullyQualifiedPath) {
					$Path = $FullyQualifiedPath
				}
				Else {
					Throw "[$Path] contains an invalid path or file name."
				}
			}

			## Set the Working directory (if not specified)
			If (-not $WorkingDirectory) { $WorkingDirectory = Split-Path -Path $Path -Parent -ErrorAction 'Stop' }

			Try {
				## Disable Zone checking to prevent warnings when running executables
				$env:SEE_MASK_NOZONECHECKS = 1

				## Using this variable allows capture of exceptions from .NET methods. Private scope only changes value for current function.
				$ErrorActionPreference = 'Stop'

				## Define process
				$processStartInfo = New-Object -TypeName 'System.Diagnostics.ProcessStartInfo' -ErrorAction 'Stop'
				$processStartInfo.FileName = $Path
				$processStartInfo.WorkingDirectory = $WorkingDirectory
				$processStartInfo.UseShellExecute = $false
				$processStartInfo.ErrorDialog = $false
				$processStartInfo.RedirectStandardOutput = $true
				$processStartInfo.RedirectStandardError = $true
				$processStartInfo.CreateNoWindow = $CreateNoWindow
				If ($Parameters) { $processStartInfo.Arguments = $Parameters }
				If ($windowStyle) { $processStartInfo.WindowStyle = $WindowStyle }
				$process = New-Object -TypeName 'System.Diagnostics.Process' -ErrorAction 'Stop'
				$process.StartInfo = $processStartInfo


				## Add event handler to capture process's standard output redirection
				[scriptblock]$processEventHandler = { If (-not [string]::IsNullOrEmpty($EventArgs.Data)) { $Event.MessageData.AppendLine($EventArgs.Data) } }
				$stdOutBuilder = New-Object -TypeName 'System.Text.StringBuilder' -ArgumentList ''
				$stdOutEvent = Register-ObjectEvent -InputObject $process -Action $processEventHandler -EventName 'OutputDataReceived' -MessageData $stdOutBuilder -ErrorAction 'Stop'

				## Start Process
				If ($Parameters) {
					Write-Log -Message "Executing [$Path $Parameters]..." -Source ${CmdletName} -Severity 4 -WriteHost -MsgPrefix (Pad-PrefixOutput -Prefix "Running Command"  -UpperCase)
				}
				Else {
					Write-Log -Message "Executing [$Path]..." -Source $TranscodeJobName -Severity 4 -WriteHost -MsgPrefix (Pad-PrefixOutput -Prefix "Running Command"  -UpperCase)
				}
				[boolean]$processStarted = $process.Start()

				If ($NoWait) {
					Write-Log -Message 'NoWait parameter specified. Continuing without waiting for exit code...' -Source ${CmdletName}
				}
				Else {
					$process.BeginOutputReadLine()
					$stdErr = $($process.StandardError.ReadToEnd()).ToString() -replace $null,''

					## Instructs the Process component to wait indefinitely for the associated process to exit.
					$process.WaitForExit()

					## HasExited indicates that the associated process has terminated, either normally or abnormally. Wait until HasExited returns $true.
					While (-not ($process.HasExited)) { $process.Refresh(); Start-Sleep -Seconds 1 }

					## Get the exit code for the process
					Try {
						[int32]$returnCode = $process.ExitCode
					}
					Catch [System.Management.Automation.PSInvalidCastException] {
						#  Catch exit codes that are out of int32 range
						[int32]$returnCode = 60013
					}

					## Unregister standard output event to retrieve process output
					If ($stdOutEvent) { Unregister-Event -SourceIdentifier $stdOutEvent.Name -ErrorAction 'Stop'; $stdOutEvent = $null }
					$stdOut = $stdOutBuilder.ToString() -replace $null,''
                    If(!$stdOut){
                        $stdOut = $($process.StandardOutput.ReadToEnd()).ToString() -replace $null,''
                    }

				}
			}
			Finally {
				## Make sure the standard output event is unregistered
				If ($stdOutEvent) { Unregister-Event -SourceIdentifier $stdOutEvent.Name -ErrorAction 'Stop'}

				## Free resources associated with the process, this does not cause process to exit
				If ($process) { $process.Close() }

				## Re-enable Zone checking
				Remove-Item -LiteralPath 'env:SEE_MASK_NOZONECHECKS' -ErrorAction 'SilentlyContinue'
			}

			If (-not $NoWait) {
				## Check to see whether we should ignore exit codes
				$ignoreExitCodeMatch = $false
				If ($ignoreExitCodes) {
					#  Split the processes on a comma
					[int32[]]$ignoreExitCodesArray = $ignoreExitCodes -split ','
					ForEach ($ignoreCode in $ignoreExitCodesArray) {
						If ($returnCode -eq $ignoreCode) { $ignoreExitCodeMatch = $true }
					}
				}
				#  Or always ignore exit codes
				If ($ContinueOnError) { $ignoreExitCodeMatch = $true }

				## If the passthru switch is specified, return the exit code and any output from process
				If ($PassThru) {
					[psobject]$ExecutionResults = New-Object -TypeName 'PSObject' -Property @{ ExitCode = $returnCode; StdOut = $stdOut; StdErr = $stdErr }
					Write-Output -InputObject $ExecutionResults
				}
				ElseIf ($ignoreExitCodeMatch) {
					Write-Log -Message "[$Path] Execution complete and the exit code [$returncode] is being ignored." -Source ${CmdletName}
				}
				ElseIf ($returnCode -eq 0) {
					Write-Log -Message "[$Path] Execution completed successfully with exit code [$returnCode]." -Source ${CmdletName}
				}
				Else {
					Write-Log -Message "[$Path] Execution failed with exit code [$returnCode]." -Severity 3 -Source ${CmdletName}
					Exit -ExitCode $returnCode
				}
			}
		}
		Catch {
			If ($PassThru) {
				[psobject]$ExecutionResults = New-Object -TypeName 'PSObject' -Property @{ ExitCode = $returnCode; StdOut = If ($stdOut) { $stdOut } Else { '' }; StdErr = If ($stdErr) { $stdErr } Else { '' } }
				Write-Output -InputObject $ExecutionResults
			}
			Else {
				Exit -ExitCode $returnCode
			}
		}
	}
	End {

	}
}
#endregion



Function Start-FFMPEGProcess {
    Param (
    [boolean]$DisplayProgress,
    [switch]$Passes
    )


    #$ffmpegPassArgs =   "-i ""$($file.FullName)"" -vcodec libx264 -ac 1 -vpre fastfirstpass -pass 1 ""$NewFileFullPath""",
    #                    "-i ""$($file.FullName)"" -vcodec libx264 -ac 1 -vpre normal -pass 2 ""$NewFileFullPath"""
    $ffmpegPassArgs =   "-i ""$($file.FullName)"" -vcodec libxvid -q:v 5 -s 640x480 -aspect 640:480 -r 30 -g 300 -bf 2 -acodec libmp3lame -ab 160k -ar 32000 -async 32000 -ac 2 -pass 1 -an -f rawvideo -y ""$NullFileFullPath""",
                        "-i ""$($file.FullName)"" -vcodec libxvid -q:v 5 -s 640x480 -aspect 640:480 -r 30 -g 300 -bf 2 -acodec libmp3lame -ab 160k -ar 32000 -async 32000 -ac 2 -pass 2 -y ""$NewFileFullPath"""

    If($Passes)
    {
        $PassCount = 1
        Foreach ($Arg in $ffmpegPassArgs){

            If($DisplayProgress){
                Write-Log -Message "Executing [$FFMpegPath $Arg]..." -Source ("FFMPEG" + $PassCount + "PASS") -Severity 4 -WriteHost -MsgPrefix (Pad-PrefixOutput -Prefix "Running Command"  -UpperCase)
                $ffmpeg = Start-Process $FFMpegPath -ArgumentList $Arg -RedirectStandardError "$TranscodeLogDir\$GUID.log" -WindowStyle Hidden -PassThru
                #progress bar monitors the trancoding log for time duration and ends when process has exited
                Start-sleep 3
                Do{
                    Start-sleep 1
                    $ffmpegProgress = [regex]::split((Get-content "$TranscodeLogDir\$GUID.log" | Select -Last 1), '(,|\s+)') | where {$_ -like "time=*"}
                    If($ffmpegProgress){
                        $gettimevalue = [TimeSpan]::Parse(($ffmpegProgress.Split("=")[1]))
                        $starttime = $gettimevalue.ToString("hh\:mm\:ss\,fff")
                        $a = [datetime]::ParseExact($starttime,"HH:mm:ss,fff",$null)
                        $ffmpegTimelapse = (New-TimeSpan -Start (Get-Date).Date -End $a).TotalSeconds
                        $ffmpegPercent = $ffmpegTimelapse / $totalTime * 100
                        Write-Progress -id 2 -Activity ("Transcoding {0}" -f $file.FullName) -PercentComplete $ffmpegPercent -Status ("Video Pass {0} is {1:N2}% completed..." -f $PassCount,$ffmpegPercent)
                    }

                }Until ($ffmpeg.HasExited)
            }
            Else{
                #build new filename and path for pass
                $ffmpeg = Execute-Process -Path $FFMpegPath -Parameters $Arg -CreateNoWindow -PassThru
            }
            $PassCount = $PassCount +1
        }

    }
    Else {
        If($DisplayProgress){

            Write-Log -Message ("Procssing new file [{0}]" -f $NewFileFullPath) -Source $TranscodeJobName -Severity 5 -WriteHost -MsgPrefix $FileWriteHostPrefix
            Write-Log -Message "Executing [$FFMpegPath $ffmpegCombinedArgs]..." -Source "FFMPEG" -Severity 4 -WriteHost -MsgPrefix (Pad-PrefixOutput -Prefix "Running Command"  -UpperCase)
            $ffmpeg = Start-Process -FilePath $FFMpegPath -ArgumentList $ffmpegCombinedArgs -RedirectStandardError "$TranscodeLogDir\$GUID.log" -WindowStyle Hidden -PassThru
            #progress bar monitors the trancoding log for time duration and ends when process has exited
            Start-sleep 3
            Do{
                Start-sleep 1
                #parse log every second, get the last line
                $ffmpegProgress = [regex]::split((Get-content "$TranscodeLogDir\$GUID.log" | Select -Last 1), '(,|\s+)') | where {$_ -like "time=*"}
                #sometime the last line may not have a time value, only display progress when it does
                If($ffmpegProgress){
                    #The time value is in time-HH.MM.SS.mm, split it off the = and convert it to timespan format
                    $gettimevalue = [TimeSpan]::Parse(($ffmpegProgress.Split("=")[1]))
                    #send it to a string to be converted to datetime
                    $starttime = $gettimevalue.ToString("hh\:mm\:ss\,fff")
                    $a = [datetime]::ParseExact($starttime,"HH:mm:ss,fff",$null)
                    #now convert it into seconds to match ffprobe duration format
                    $ffmpegTimelapse = (New-TimeSpan -Start (Get-Date).Date -End $a).TotalSeconds
                    #divide them to get the percentage
                    $ffmpegPercent = $ffmpegTimelapse / $totalTime * 100
                    #display time
                    Write-Progress -id 2 -Activity ("Transcoding {0}" -f $file.FullName) -PercentComplete $ffmpegPercent -Status ("Video is {0:N2}% completed..." -f $ffmpegPercent)
                }
            }Until ($ffmpeg.HasExited)
        }
        Else{
            $ffmpeg = Execute-Process -Path $FFMpegPath -Parameters $ffmpegCombinedArgs -CreateNoWindow -PassThru
        }
    }

}
