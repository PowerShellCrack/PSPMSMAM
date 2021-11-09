Function Archive-FileAndUpload{
    # @name         &ZIP and Upload...
    # @command      powershell.exe -ExecutionPolicy Bypass -File "%EXTENSION_PATH%" -sessionUrl "!S" -remotePath "!/" -archiveName "!?&Archive name:?archive.zip!" -pause !&
    # @description  Packs the selected files to a ZIP archive and uploads it
    # @flag         ApplyToDirectories
    # @require      .NET 4.5
    # @version      1

    param (
        # Use Generate URL function to obtain a value for -sessionUrl parameter.
        $sessionUrl = "sftp://user:mypassword;fingerprint=ssh-rsa-xx-xx-xx@example.com/",
        [Parameter(Mandatory)]
        $remotePath,
        [Switch]
        $pause = $False,
        [Switch]
        $use7Zip = $False,
        [Parameter(Mandatory)]
        $archiveName,
        [Parameter(Mandatory, ValueFromRemainingArguments, Position=0)]
        $localPaths
    )

    try
    {
        Write-Host ("Archiving {0} files to archive {1}..." -f $localPaths.Count, $archiveName)

        $archivePath = Join-Path ([System.IO.Path]::GetTempPath()) $archiveName

        if (Test-Path $archivePath)
        {
            Remove-Item $archivePath
        }

        # Using 7-Zip one can create also other archive formats, not just ZIP
        if ($use7Zip)
        {
            # Create archive
            # The 7z.exe can be replaced with portable 7za.exe
            & "C:\Program Files\7-Zip\7z.exe" a -tzip $archivePath $localPaths

            if ($LASTEXITCODE -gt 0)
            {
                throw "Archiving failed."
            }
        }
        else
        {
            Add-Type -AssemblyName "System.IO.Compression"
            Add-Type -AssemblyName "System.IO.Compression.FileSystem"

            $zip = [System.IO.Compression.ZipFile]::Open($archivePath, [System.IO.Compression.ZipArchiveMode]::Create)

            # Replace with Compress-Archive once PowerShell 5.0 is widespread

            foreach ($localPath in $localPaths)
            {
                $parentPath = Split-Path -Parent (Resolve-Path $localPath)

                if (Test-Path $localPath -PathType Leaf)
                {
                    $files = $localPath
                }
                else
                {
                    $files = Get-ChildItem $localPath -Recurse -File | Select-Object -ExpandProperty FullName
                }

                foreach ($file in $files)
                {
                    $entryName = $file.Replace(($parentPath + "\"), "")
                    Write-Host ("Adding {0}..." -f $entryName)
                    [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file, $entryName) | Out-Null
                }
            }

            $zip.Dispose()
        }

        Write-Host ("Archive {0} created, uploading..." -f $archiveName)

        # Load WinSCP .NET assembly
        $assemblyPath = if ($env:WINSCP_PATH) { $env:WINSCP_PATH } else { $PSScriptRoot }
        Add-Type -Path (Join-Path $assemblyPath "WinSCPnet.dll")

        # Setup session options
        $sessionOptions = New-Object WinSCP.SessionOptions
        $sessionOptions.ParseUrl($sessionUrl)

        $session = New-Object WinSCP.Session

        try
        {
            # Connect
            $session.Open($sessionOptions)

            $session.PutFiles($session.EscapeFileMask($archivePath), $remotePath).Check()

            Write-Host ("Archive {0} uploaded." -f $archiveName)
        }
        finally
        {
            # Disconnect, clean up
            $session.Dispose()
        }

        Remove-Item $archivePath
        $result = 0
    }
    catch [Exception]
    {
        Write-Host ("Error: {0}" -f $_.Exception.Message)
        $result = 1
    }

    # Pause if -pause switch was used
    if ($pause)
    {
        Write-Host "Press any key to exit..."
        [System.Console]::ReadKey() | Out-Null
    }

    exit $result
}