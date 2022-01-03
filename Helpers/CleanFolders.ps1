<#
.SYNOPSIS
Svendsen Tech's generic script for removing empty directories from a
directory tree structure.

Finds or removes/deletes empty directories recursively from the drive or
directory you specify.

You will need to use the -VerifyNoEmpty parameter or multiple
runs to get rid of nested empty directories. See the -VerifyNoEmpty parameter's
description for further details.

This isn't the most efficient approach as the ones I can think of seem to
increase the script's complexity considerably. It should be useful for a
multitude of use cases.

Author: Joakim Svendsen
Modified: Richard Tracy
.PARAMETER Path
Required. Base root path to iterate recursively.
.PARAMETER Find
Default behaviour where it just prints. Overrides -Remove if both are specified.
.PARAMETER Remove
Removes all empty dirs (as in actually deletes them with Remove-Item).
.PARAMETER VerifyNoEmpty
Makes the script run until no empty directories are found. This is in order
to handle nested empty directories, as in a directory that currently only
contains an empty directory would be empty after the first run/iteration and
need to be remove in a subsequent run. Specifying this parameter causes the
script to run until it's done a complete run without finding a single empty
directory. This might be time-consuming depending on the size of the directory
tree structure.

If there is an error while deleting a directory, it will not run again, to
avoid an infinite loop.
#>

function Remove-EmptyDirs {
    param(
        [Parameter(Mandatory=$true)][string] $Path,
        [switch] $Find,
        [switch] $Confirm,
        [switch] $VerifyNoEmpty
    )
    Begin{
        if (-not (Test-Path -LiteralPath $Path -PathType Container)) { 
            write-host "The specified path does not exist." -ForegroundColor Red
            break
        }
    }
    Process{
        $FoundEmpty = $false
        Write-Host "Iterating '$Path'"
        Get-ChildItem -LiteralPath $Path -Force -Recurse | Where-Object { $_.PSIsContainer } | ForEach-Object {  
            if ($Find -or -not $Confirm) {   
                if (-not (Get-ChildItem -LiteralPath $_.FullName -Force )) {     
                    # Directory should be empty
                    $_.FullName + ' is empty'
                } 
            }
            
            elseif ($Confirm -and $VerifyNoEmpty) { 
                $Counter = 0
                while (($OutsideFoundEmpty = Remove-EmptyDirs) -eq $true) {
                    $Counter++
                    Write-Host -ForegroundColor Yellow "-VerifyNoEmpty specified. Found empty dirs on run no ${Counter}. Starting next run." 
                }
                $Counter++
                Write-Host "Made $Counter runs in total"
            }
            # This is the dangerous part
            elseif ($Confirm) {
                if (-not (Get-ChildItem -LiteralPath $_.FullName -Force)) {
                    $FoundEmpty = $true
                    # Directory should be empty
                    Remove-Item -LiteralPath $_.FullName -Force
                    if (-not $?) { 
                        $message = "Error: $(Get-Date): Unable to delete $($_.FullName): $($Error[0].ToString))"
                        If($Log){$message | Out-File -Append $Log}
                        Write-Host $message -ForegroundColor Red 
                        
                        $FoundEmpty = $false # avoid infinite loop
                    }
                    else { 
                        $message = "$(Get-Date): Successfully deleted the empty folder: $($_.FullName)"
                        If($Log){$message | Out-File -Append $Log}
                        Write-Host $message -ForegroundColor Green 
                    }
                }
            }  
        }# end of ForEach-Object 
    }
    End{ 
        #return $FoundEmpty
    }
} # end of function Remove-EmptyDirs



Function Remove-AgedItems
{
    <#
    
    .DESCRIPTION
    Function that can be used to remove files older than a specified age and also remove empty folders.

    .PARAMETER Path
    Specifies the target Path.
    
    .PARAMETER Age
    Specifies the target Age in days, e.g. Last write time of the item.
    
    .PARAMETER Force
    Switch parameter that allows for hidden and read-only files to also be removed.
    
    .PARAMETER Empty Folder
    Switch parameter to use empty folder remove function.

    .EXAMPLE
    Remove-AgedItems -Path 'C:\Users\rholland\TesfFunction' -Age 7 #Remove Files In The Target Path That Are Older Than The Specified Age (in days), Recursively.

    Remove-AgedItems -Path 'C:\Users\rholland\TesfFunction' -Age 7 -Force #Remove Files In The Target Path That Are Older Than The Specified Age (in days), Recursively. Force will include hidden and read-only files.

    Remove-AgedItems -Path 'C:\Users\rholland\TesfFunction' -Age 0 -EmptyFolder #Remove All Empty Folders In Target Path.

    Remove-AgedItems -Path 'C:\Users\rholland\TesfFunction' -Age 7 -EmptyFolder #Remove All Empty Folders In Target Path That Are Older Than Specified Age (in days).

    .NOTES
    The -EmptyFolders switch branches the function so that it will only perform its empty folder cleanup operation, it will not affect aged files with this switch.
    It is recommended to first perform a cleanup of the aged files in the target path and them perform a cleanup of the empty folders.

    #>
    
    param ([String][Parameter(Mandatory = $true)]
        $Path,
        [int][Parameter(Mandatory = $true)]
        $Age,
        [switch]$Force,
        [switch]$EmptyFolder)
 
    $CurrDate = (get-date)

    if (Test-Path -Path $Path)
    {
        $Items = (Get-ChildItem -Path $Path -Recurse -Force -File)
        $AgedItems = ($Items | Where-object { $_.LastWriteTime -lt $CurrDate.AddDays(- $Age) })

        if ($EmptyFolder.IsPresent)
        {
            $Folders = @()
            ForEach ($Folder in (Get-ChildItem -Path $Path -Recurse | Where { ($_.PSisContainer) -and ($_.LastWriteTime -lt $CurrDate.AddDays(- $Age)) }))
            {
                $Folders += New-Object PSObject -Property @{
                    Object = $Folder
                    Depth = ($Folder.FullName.Split("\")).Count
                }
            }
            $Folders = $Folders | Sort Depth -Descending
            $Deleted = @()
            ForEach ($Folder in $Folders)
            {
                If ($Folder.Object.GetFileSystemInfos().Count -eq 0)
                { 
                    Remove-Item -Path $Folder.Object.FullName -Force
                    Start-Sleep -Seconds 0.2
                }
            }
        }
        else
        {
            if ($Force.IsPresent)
            {
                $AgedItems | Remove-Item -Recurse -Force
                
            }
            else
            {
                $AgedItems | Remove-Item -Recurse
            }
        }
    }
    Else
    {
        Write-Error "Target path has not been found"
    }
}