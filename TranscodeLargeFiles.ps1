<#
.SYNOPSIS
    Grab each file and determine its size, if larger than 500mb. transcode and replace.
.DESCRIPTION
    To get ffmpeg to display a progress status, I had to first get the video duration using ffprobe.
    Using ffprobes value and redirecting ffmpeg stanradr error output to a log, I was able to grab
    the last line in the log and find the current transcode spot in the timeline and build a progress
    bar actively showing ffmpeg's percentage.
.NOTES
    Make sure to change the variables paths to your directory
.LINK
     - comskip.exe (entire zipped directory) --> https://www.videohelp.com/software/Comskip/old-versions#downloadold
     - ffmpeg.exe --> https://ffmpeg.org/download.html
     - ffprobe.exe (comes with ffmpeg) --> https://ffmpeg.org/download.html
     - PlexComskip.py (optional) --> https://github.com/ekim1337/PlexComskip
     - Python 2.7 (optional) --> https://www.python.org/downloads/release/python-2713/
#>

## Variables: Script Name and Script Paths

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

$LogfileName = "$($scriptName)_$(Get-Date -Format 'yyyy-MM-dd_Thh-mm-ss-tt').log"
[string]$Logfile = "$LogDir\$LogfileName.log"
##*===============================================
##* EXTENSIONS
##*===============================================
Import-Module BitsTransfer

#Import Script extensions
. "$ExtensionPath\Logging.ps1"
. "$ExtensionPath\videoparser.ps1"

##*===============================================
##* CONFIGS
##*===============================================
[string]$ScriptNameDesc = "Transocde Large Video Files"
[string]$ScriptVersion= "1.0"

[string]$searchDir = 'F:\Media\TV Series'
[int32]$FindSizeGreaterThan = 800MB

[boolean]$UsePlexComSkip = $false
[string]$PythonPath = 'C:\Python27\python.exe'
[string]$PlexDVRComSkipScriptPath = 'E:\Data\Plex\DVRPostProcessingScript\comskip81_098\PlexComskip.py'
[string]$ComSkipPath = 'E:\Data\Plex\DVRPostProcessingScript\comskip82_003'

[string]$FFMpegPath = 'E:\Data\Plex\DVRPostProcessingScript\ffmpeg\bin\ffmpeg.exe'
[string]$FFProbePath = 'E:\Data\Plex\DVRPostProcessingScript\ffmpeg\bin\ffprobe.exe'
[string]$TranscodeDir = 'G:\TranscoderTempDirectory\ComskipInterstitialDirectory'
[string]$TranscodeLogDir = 'E:\Data\Plex\DVRPostProcessingScript\Logs'

[boolean]$Transcode2PassAlways = $false
[int32]$TranscodePasses = 2
[string]$TranscodeJobName = "FFMPEG"

[Boolean]$CheckCommercialSkip = $False
[string]$CommericalJobName = "COMSKIP"

# Get Start Time
$startDTM = (Get-Date)
Write-Log -Message ("Script Started [{0}]" -f (Get-Date)) -Source $scriptName -Severity 1 -WriteHost -MsgPrefix (Pad-PrefixOutput -Prefix $scriptName -UpperCase)

##*===============================================
##* MAIN
##*===============================================
$CheckSize = Convert-ToBytes $FindSizeGreaterThan

Write-Log -Message ("Searching for large video files in [{0}], this may take a while..." -f $searchDir) -Source 'SEARCHER' -Severity 4 -WriteHost -MsgPrefix (Pad-PrefixOutput -Prefix "SEARCHER" -UpperCase)

#get size of entire directory
$SearchFolderStatsBefore = Get-HugeDirStats $searchDir
#get all files larger than speicifed size and order than by largest first
$FoundLargeFiles = Get-ChildItem $searchDir -Recurse -ErrorAction "SilentlyContinue" | Where-Object {$_.Length -gt $FindSizeGreaterThan} | Sort-Object length -Descending
Write-Log -Message ("Found [{0}] files with size over [{1}], File processing will start soon. DO NOT close any windows that may popup up!" -f [int32]$FoundLargeFiles.Count,$CheckSize) -Source 'SEARCHER' -Severity 2 -WriteHost -MsgPrefix (Pad-PrefixOutput -Prefix "SEARCHER" -UpperCase)

#get length of current count to format message equally
$FoundFileLength = [int32]$FoundLargeFiles.Count.ToString().Length

$currentCount = 0
$res = @()
#process each file using ffmpeg
Foreach ($file in $FoundLargeFiles){
    $Size = Convert-ToBytes $file.Length
    $currentCount = $currentCount+1
    [string]$PadCurrentCount = Pad-Counter -Number $currentCount -MaxPad $FoundFileLength
    $FileWriteHostPrefix = Pad-PrefixOutput -Prefix ("File {0} of {1}" -f $PadCurrentCount,$FoundLargeFiles.Count) -UpperCase

    #build progress bar for overall process
    $FilePercent = $PadCurrentCount / $FoundLargeFiles.Count * 100
    Write-Progress -id 1 -Activity ("Overall status [{1:N2}%]" -f $FileWriteHostPrefix,$FilePercent) -PercentComplete $FilePercent -Status ("Processing file {0} of {1} : : {2}" -f $PadCurrentCount,$FoundLargeFiles.Count,$file.Name)

    #build working directory
    $GUID = $([guid]::NewGuid().ToString().Trim())
    $ParentDir = Split-path $File.FullName -Parent
    $WorkingDir = Join-Path $TranscodeDir -ChildPath $GUID
    New-Item $WorkingDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null

    #build new filename and path
    $NewFileName = $file.BaseName + '.mp4'
    $NewFileFullPath = Join-Path $WorkingDir -ChildPath $NewFileName

    #build null filename and path for 2 passes
    $NullFileName = 'null.mp4'
    $NullFileFullPath = Join-Path $WorkingDir -ChildPath $NullFileName

    #build Log file name and path
    $NewFileLogName = $file.BaseName + '.log'
    $NewFileLogFullPath = Join-Path $TranscodeLogDir -ChildPath $NewFileLogName

    #get duration of video to calculate progress bar. If durastion is not found, do not display progress bar
    Write-Log -Message ("Probing file [{0}] for duration time" -f $file.Name) -Source $TranscodeJobName -Severity 5 -WriteHost -MsgPrefix $FileWriteHostPrefix
    $Progress = $false
    $ffprobeDur = Execute-Process -Path $FFProbePath -Parameters "-v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 ""$($file.FullName)""" -CreateNoWindow -PassThru
    $totalTime = $ffprobeDur.StdOut
    If($totalTime){$Progress = $true}

    #Treat .ts files differently than others
    #if extension is .ts this means it was recorded by a tuner
    #process it for commercialsand transcode it with 2 passes.
    If($file.Extension -eq '.ts'){
        If($CheckCommercialSkip){
            Write-Log -Message ("Recorded File found [{0}], removing commercials..." -f $file.Name) -Source $CommericalJobName -Severity 5 -WriteHost -MsgPrefix $FileWriteHostPrefix
            If($UsePlexComSkip){
                $comskip = Execute-Process -Path $PythonPath -Parameters "$PlexDVRComSkipScriptPath ""$($file.FullName)""" -CreateNoWindow -PassThru
            }Else{
                $comskip = Execute-Process -Path "$ComSkipPath\comskip.exe" -Parameters "--output ""$WorkingDir"" --ini ""$ComSkipPath\comskip.ini"" ""$($file.FullName)""" -CreateNoWindow -PassThru
            }
            If($comskip.ExitCode -eq 0)
            {
                Write-Log -Message ("Successfully processed commercials from file [{0}]." -f $file.FullName) -Source $CommericalJobName -Severity 0 -WriteHost -MsgPrefix $FileWriteHostPrefix
            }
            Else{
                Write-Log -Message ("Fail to pull commercials from file [{0}]. Error: {1}:{2}" -f $file.FullName,$comskip.ExitCode,$comskip.StdErr) -Source $CommericalJobName -Severity 3 -WriteHost -MsgPrefix $FileWriteHostPrefix
            }
        }Else{
            Write-Log -Message ("Recorded File found [{0}], skipping commercials check..." -f $file.Name) -Source $CommericalJobName -Severity 2 -WriteHost -MsgPrefix $FileWriteHostPrefix
        }

        If($Transcode2PassAlways -and ($File.Length -gt $FindSizeGreaterThan) ){
            #now re-encode the video to reduce it size
            Write-Log -Message ("[{0}] is too large [{1}]. Preparing re-transcoding 2 passes to reduce file size" -f $file.Name,$Size) -Source $TranscodeJobName -Severity 2 -WriteHost -MsgPrefix $FileWriteHostPrefix
            $ffmpegCombinedArgs = "-f mp4 -ac 2 -ar 44100 -threads 4 -c:v libx264 -c:a ac3 -crf 30 -preset fast"
            $ffmpeg = Start-FFMPEGProcess -DisplayProgress $Progress -Passes
        }

    }
    Else {

        #if a time duration was found, a progess bar can be used
        If($Transcode2PassAlways){
            #now re-encode the video to reduce it size
            Write-Log -Message ("[{0}] is too large [{1}]. Preparing re-transcoding 2 passes to reduce file size" -f $file.Name,$Size) -Source $TranscodeJobName -Severity 2 -WriteHost -MsgPrefix $FileWriteHostPrefix

            $ffmpeg = Start-FFMPEGProcess -DisplayProgress $Progress -Passes
        }
        Else{

            #build ffmpeg arguments
            $ffmpegAlwaysUseArgs = "-f mp4 -ac 2 -ar 44100 -threads 4"

            #get video extention to detemine ffmpeg arguments
            switch($file.Extension){
                '.avi'  {$ffmpegExtArgs = '-c:v libx264 -c:a aac -b:a 128k -crf 20 -preset fast'}
                '.mkv'  {$ffmpegExtArgs = '-c:v libx264 -c:a copy -crf 23'}
                '.mp4'  {$ffmpegExtArgs = '-c:v libx264 -crf 20 -preset veryfast -profile:v baseline'}
                '.wmv'  {$ffmpegExtArgs = '-c:v libx264 -c:a aac -crf 23-strict -2 -q:a 100 -preset fast'}
                '.mpeg' {$ffmpegExtArgs = '-c:v libx264 -c:a aac -b:a 128k -crf 20 -preset fast'}
                '.mpg'  {$ffmpegExtArgs = '-c:v copy -c:a ac3 -crf 30 -preset veryfast'}
                '.vob'  {$ffmpegExtArgs = '-c:v mpeg4 -c:a libmp3lame -b:v 800k -g 300 -bf 2  -b:a 128k'}
                default {$ffmpegExtArgs = '-c:v copy -c:a copy -crf 30 -preset veryfast'}
            }

            #Get video resolution to determine ffmpeg argument
            $ffprobeRes = Execute-Process -Path $FFProbePath -Parameters "-v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 ""$($file.FullName)""" -PassThru
            #sometimes videow have mutlple streams with resolutions of the same, we just need one
            $vidres = (($ffprobeRes.StdOut) -split '[\r\n]') |? {$_} | Select -First 1
            #If any of the resolutiuons exist, add a ffmpeg paramter to reduce it.
            $ffmpegVidArgs = ''
            switch( $vidres ){
                '1920x1080' {$ffmpegVidArgs = '-s 4cif'}
                '1280x720'  {$ffmpegVidArgs = '-s 4cif'}
                '1280x718'  {$ffmpegVidArgs = '-s hd720'}
                '1280x714'  {$ffmpegVidArgs = '-s hd720'}
                '128×96'    {$ffmpegVidArgs = '-vf super2xsai'}
                '256×192'   {$ffmpegVidArgs = '-vf super2xsai'}
            }

            #combine all the parameter to build the main string
            $ffmpegCombinedArgs  = "-y -i ""$($file.FullName)"" $ffmpegAlwaysUseArgs $ffmpegVidArgs $ffmpegExtArgs ""$NewFileFullPath"""
            #$ffmpegCombinedArgs  = "-y -i ""$($file.FullName)"" $ffmpegAlwaysUseArgs $ffmpegVidArgs $ffmpegExtArgs ""$NewFileFullPath"" 2> ""$TranscodeLogDir\$GUID.log"""
            #now re-encode the video to reduce it size
            Write-Log -Message ("[{0}] is too large [{1}]. Preparing re-transcoding process to reduce file size" -f $file.Name,$Size) -Source $TranscodeJobName -Severity 2 -WriteHost -MsgPrefix $FileWriteHostPrefix

            $ffmpeg = Start-FFMPEGProcess -DisplayProgress $Progress

            $NewFile = Get-Childitem $NewFileFullPath -ErrorAction "SilentlyContinue"
            $NewSize = Convert-ToBytes $NewFile.Length
            $NewFilefProbe = Execute-Process -Path $FFProbePath -Parameters "-v error -select_streams v:0 -show_entries stream=width,height -of csv=s=x:p=0 ""$NewFileFullPath""" -CreateNoWindow -PassThru
            $NewVidRes = ($NewFilefProbe.StdOut).Trim()

            #Check if size is larger than specified size , if so try to ruyn two pass on it
            If($NewFile.Length -gt $FindSizeGreaterThan){
                Write-Log -Message ("[{0}] is STILL too large [{1}], will try to run 2 passes reduce file size" -f $NewFile.Name,$NewSize) -Source $TranscodeJobName -Severity 2 -WriteHost -MsgPrefix $FileWriteHostPrefix

                $ffmpeg = Start-FFMPEGProcess -DisplayProgress $Progress -Passes
            }
        }

        #if transocde file is smaller than orginial, concider it an success
        $NewFile = Get-Childitem $NewFileFullPath -ErrorAction "SilentlyContinue"
        $NewSize = Convert-ToBytes $NewFile.Length
        If($NewFile.Length -lt $FindSizeGreaterThan){

            Write-Log -Message ("[{0}] has been reduced to [{1}]" -f $NewFile.Name,$NewSize) -Source $TranscodeJobName -Severity 0 -WriteHost -MsgPrefix $FileWriteHostPrefix

            #move file back to original location
            Write-Log -Message ("Transferring [{0}] to [{1}]" -f $NewFile.FullName,$ParentDir) -Source 'BITS' -Severity 5 -WriteHost -MsgPrefix $FileWriteHostPrefix
            $bits = Start-BitsTransfer -Source "$NewFileFullPath" -Destination $ParentDir -Description "Transferring to $ParentDir" -DisplayName "Moving $NewFileName" -Asynchronous

            While ($bits.JobState -eq "Transferring") {
                Sleep -Seconds 1
            }

            If ($bits.InternalErrorCode -ne 0) {
                Write-Log -Message ("Fail to transfer [{0}]. Error: {1}" -f $NewFile.FullName,$bits.InternalErrorCode) -Source 'BITS' -Severity 3 -WriteHost -MsgPrefix $FileWriteHostPrefix
            } else {
                Write-Log -Message ("Successfully transferred [{0}] to [{1}]" -f $NewFile.FullName,$ParentDir) -Source 'BITS' -Severity $bits.InternalErrorCode -WriteHost -MsgPrefix $FileWriteHostPrefix

                #remove original file
                Write-Log -Message ("Deleting original file [{0}]" -f $File.FullName) -Source 'BITS' -Severity 5 -WriteHost -MsgPrefix $FileWriteHostPrefix
                Remove-Item "$($file.FullName)" -Force -ErrorAction SilentlyContinue | Out-Null


                #Record video information
                [psobject]$vids = New-Object -TypeName 'PSObject' -Property @{
                    OriginalRes  = $vidres
                    OriginalSize = Convert-ToBytes $file.Length
                    OriginalName = $file.Name
                    Filepath = Split-Path $file.FullName -Parent
                    NewName = $NewFileName
                    NewSize = Convert-ToBytes $NewFile.Length
                    NewRes = $NewVidRes
                    GUID = $GUID
                    }
                $res += $vids

            }
        }
        Else{
            Write-Log -Message ("Transcode failed to reduce the file [{0}], size is [{1}]" -f $NewFileFullPath,$NewSize) -Source $TranscodeJobName -Severity 3 -WriteHost -MsgPrefix $FileWriteHostPrefix
            #remove working directory if failed
            Remove-Item $WorkingDir -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
            Continue
        }
    }

    #remove working directory
    Write-Log -Message ("Removing working directory [{0}]" -f $WorkingDir) -Source 'BITS' -Severity 5 -WriteHost -MsgPrefix $FileWriteHostPrefix
    Remove-Item $WorkingDir -Recurse -Force -ErrorAction SilentlyContinue | Out-Null

}

$SearchFolderStatsAfter = Get-HugeDirStats $searchDir
$shrinkspace = ( ($SearchFolderStatsBefore.Size - $SearchFolderStatsAfter.Size) / 1gb)

# Get End Time
$endDTM = (Get-Date)



$ts =  [timespan]::fromseconds(($endDTM-$startDTM).totalseconds)
Write-Log -Message ("Script Completed on [{0}] in [{1}]. Saved [{2}] in file space" -f (Get-Date),$ts.ToString("hh\:mm\:ss\,fff"),$shrinkspace) -Source $scriptName -Severity 1 -WriteHost -MsgPrefix $scriptName
return $res