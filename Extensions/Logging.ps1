Function Write-Log {
<#
.SYNOPSIS
	Write messages to a log file in CMTrace.exe compatible format or Legacy text file format.
.DESCRIPTION
	Write messages to a log file in CMTrace.exe compatible format or Legacy text file format and optionally display in the console.
.PARAMETER Message
	The message to write to the log file or output to the console.
.PARAMETER Severity
	Defines message type. When writing to console or CMTrace.exe log format, it allows highlighting of message type.
	Options: 0,1,4,5 = Information (default), 2 = Warning (highlighted in yellow), 3 = Error (highlighted in red)
.PARAMETER Source
	The source of the message being logged.
.PARAMETER LogFile
	Set the log and path of the log file. Default to global variable $LogFilePath
.PARAMETER $MsgPrefix
    Tacks on a message header to each log entry with a appending ::
    Example: START :: Log start on 10/28/2018
.PARAMETER WriteHost
	Write the log message to the console.
    The Severity sets the color:
        5 is 'Gray' Letters with 'Black' background; considered low severity
        4 is 'Cyan' Letters with 'Black' background; considered low severity
	    3 is 'Red' Letters with 'Black' background; considered high severity
	    2 is 'Yellow' Letters with 'Black' background; considered medium severity
	    1 is 'White' Letters with 'Black' background; considered low severity
        0 is 'Green' Letters with 'Black' background; considered low severity

.PARAMETER ContinueOnError
	Suppress writing log message to console on failure to write message to log file. Default is: $true.
.PARAMETER PassThru
	Return the message that was passed to the function
.EXAMPLE
	 Write-Log -Message "Starting Log" -Source ${CmdletName} -Severity 1 -WriteHost
.EXAMPLE
	 Write-Log -Message ("Starting Log") -Source ${CmdletName} -Severity 0 -WriteHost -MsgPrefix "START"
.NOTES
    Taken from http://psappdeploytoolkit.com
.LINK

#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
		[AllowEmptyCollection()]
		[Alias('Text')]
		[string[]]$Message,
        [Parameter(Mandatory=$false,Position=1)]
		[ValidateNotNullorEmpty()]
        [Alias('Prefix')]
        [string]$MsgPrefix,
        [Parameter(Mandatory=$false,Position=2)]
		[ValidateRange(0,5)]
		[int16]$Severity = 1,
		[Parameter(Mandatory=$false,Position=3)]
		[ValidateNotNull()]
		[string]$Source = '',
        [Parameter(Mandatory=$false,Position=4)]
		[ValidateNotNullorEmpty()]
		[switch]$WriteHost,
        [Parameter(Mandatory=$false,Position=5)]
		[ValidateNotNullorEmpty()]
        [switch]$NewLine,
        [Parameter(Mandatory=$false,Position=6)]
		[ValidateNotNullorEmpty()]
		[string]$LogFile = $global:LogFilePath,
		[Parameter(Mandatory=$false,Position=7)]
		[ValidateNotNullorEmpty()]
		[boolean]$ContinueOnError = $true,
		[Parameter(Mandatory=$false,Position=8)]
		[switch]$PassThru = $false

    )
    Begin {
		## Get the name of this function
		[string]${CmdletName} = $PSCmdlet.MyInvocation.MyCommand.Name

		## Logging Variables
		#  Log file date/time
		[string]$LogTime = (Get-Date -Format 'HH:mm:ss.fff').ToString()
		[string]$LogDate = (Get-Date -Format 'MM-dd-yyyy').ToString()
		[int32]$script:LogTimeZoneBias = [timezone]::CurrentTimeZone.GetUtcOffset([datetime]::Now).TotalMinutes
		[string]$LogTimePlusBias = $LogTime + $script:LogTimeZoneBias
		#  Get the file name of the source script
		Try {
			If ($script:MyInvocation.Value.ScriptName) {
				[string]$ScriptSource = Split-Path -Path $script:MyInvocation.Value.ScriptName -Leaf -ErrorAction 'Stop'
			}
			Else {
				[string]$ScriptSource = Split-Path -Path $script:MyInvocation.MyCommand.Definition -Leaf -ErrorAction 'Stop'
			}
		}
		Catch {
			$ScriptSource = ''
		}

        ## Create script block for generating CMTrace.exe compatible log entry
		[scriptblock]$CMTraceLogString = {
			Param (
				[string]$lMessage,
				[string]$lSource,
				[int16]$lSeverity
			)
			"<![LOG[$lMessage]LOG]!>" + "<time=`"$LogTimePlusBias`" " + "date=`"$LogDate`" " + "component=`"$lSource`" " + "context=`"$([Security.Principal.WindowsIdentity]::GetCurrent().Name)`" " + "type=`"$lSeverity`" " + "thread=`"$PID`" " + "file=`"$ScriptSource`">"
		}

		## Create script block for writing log entry to the console
		[scriptblock]$WriteLogLineToHost = {
			Param (
				[string]$lTextLogLine,
				[int16]$lSeverity
			)
			If ($WriteHost) {
				#  Only output using color options if running in a host which supports colors.
				If ($Host.UI.RawUI.ForegroundColor) {
					Switch ($lSeverity) {
                        5 { Write-Host -Object $lTextLogLine -ForegroundColor 'Gray' -BackgroundColor 'Black'}
                        4 { Write-Host -Object $lTextLogLine -ForegroundColor 'Cyan' -BackgroundColor 'Black'}
						3 { Write-Host -Object $lTextLogLine -ForegroundColor 'Red' -BackgroundColor 'Black'}
						2 { Write-Host -Object $lTextLogLine -ForegroundColor 'Yellow' -BackgroundColor 'Black'}
						1 { Write-Host -Object $lTextLogLine  -ForegroundColor 'White' -BackgroundColor 'Black'}
                        0 { Write-Host -Object $lTextLogLine -ForegroundColor 'Green' -BackgroundColor 'Black'}
					}
				}
				#  If executing "powershell.exe -File <filename>.ps1 > log.txt", then all the Write-Host calls are converted to Write-Output calls so that they are included in the text log.
				Else {
					Write-Output -InputObject $lTextLogLine
				}
			}
		}

        ## Exit function if logging to file is disabled and logging to console host is disabled
		If (($DisableLogging) -and (-not $WriteHost)) { [boolean]$DisableLogging = $true; Return }
		## Exit Begin block if logging is disabled
		If ($DisableLogging) { Return }

        ## Dis-assemble the Log file argument to get directory and name
		[string]$LogFileDirectory = Split-Path -Path $LogFile -Parent
        [string]$LogFileName = Split-Path -Path $LogFile -Leaf

        ## Create the directory where the log file will be saved
		If (-not (Test-Path -LiteralPath $LogFileDirectory -PathType 'Container')) {
			Try {
				$null = New-Item -Path $LogFileDirectory -Type 'Directory' -Force -ErrorAction 'Stop'
			}
			Catch {
				[boolean]$DisableLogging = $true
				#  If error creating directory, write message to console
				If (-not $ContinueOnError) {
					Write-Host -Object "[$LogDate $LogTime] [${CmdletName}] $ScriptSection :: Failed to create the log directory [$LogFileDirectory]. `n$(Resolve-Error)" -ForegroundColor 'Red'
				}
				Return
			}
		}

		## Assemble the fully qualified path to the log file
		[string]$LogFilePath = Join-Path -Path $LogFileDirectory -ChildPath $LogFileName

    }
	Process {
        ## Exit function if logging is disabled
		If ($DisableLogging) { Return }

        Switch ($lSeverity)
            {
                5 { $Severity = 1 }
                4 { $Severity = 1 }
				3 { $Severity = 3 }
				2 { $Severity = 2 }
				1 { $Severity = 1 }
                0 { $Severity = 1 }
            }

        ## If the message is not $null or empty, create the log entry for the different logging methods
		[string]$CMTraceMsg = ''
		[string]$ConsoleLogLine = ''
		[string]$LegacyTextLogLine = ''

		#  Create the CMTrace log message

		#  Create a Console and Legacy "text" log entry
		[string]$LegacyMsg = "[$LogDate $LogTime]"
		If ($MsgPrefix) {
			[string]$ConsoleLogLine = "$LegacyMsg [$MsgPrefix] :: $Message"
		}
		Else {
			[string]$ConsoleLogLine = "$LegacyMsg :: $Message"
		}

        ## Execute script block to create the CMTrace.exe compatible log entry
		[string]$CMTraceLogLine = & $CMTraceLogString -lMessage $Message -lSource $Source -lSeverity $Severity

		##
		[string]$LogLine = $CMTraceLogLine

        Try {
			$LogLine | Out-File -FilePath $LogFilePath -Append -NoClobber -Force -Encoding 'UTF8' -ErrorAction 'Stop'
		}
		Catch {
			If (-not $ContinueOnError) {
				Write-Host -Object "[$LogDate $LogTime] [$ScriptSection] [${CmdletName}] :: Failed to write message [$Message] to the log file [$LogFilePath]." -ForegroundColor 'Red'
			}
		}

        ## Execute script block to write the log entry to the console if $WriteHost is $true
		& $WriteLogLineToHost -lTextLogLine $ConsoleLogLine -lSeverity $Severity
    }
	End {
        If ($PassThru) { Write-Output -InputObject $Message }
    }
}


Function Pad-PrefixOutput {

    Param (
    [Parameter(Mandatory=$true)]
    [string]$Prefix,
    [switch]$UpperCase,
    [int32]$MaxPad = 20
    )

    If($Prefix.Length -ne $MaxPad){
        $addspace = $MaxPad - $Prefix.Length
        $newPrefix = $Prefix + (' ' * $addspace)
    }Else{
        $newPrefix = $Prefix
    }

    If($UpperCase){
        return $newPrefix.ToUpper()
    }Else{
        return $newPrefix
    }
}


Function Pad-Counter {
    Param (
    [string]$Number,
    [int32]$MaxPad
    )

    return $Number.PadLeft($MaxPad,"0")

}

# Write a message to log.
function Add-Message ($MSG) {
	$script:Logger += "$(get-date -format u) $MSG`n"
	Write-Output $MSG
}

# Write an error to log.
function Log-Error ($MSG) {
	$script:Logger += "$(get-date -format u) ERROR`: $MSG`n"
	Write-Error "ERROR`: $MSG"
}

# Write contents of log to file.
function Write-MessageLog {
	Write-Output $script:Logger | Out-File $LogFile -Append
}


# Get command line arguments to fill in the fields
# Must be the first statement in the script
Function Send-Gmail{
    param(
        [Parameter(Mandatory = $true,
                        Position = 0,
                        ValueFromPipelineByPropertyName = $true)]
        [Alias('From')] # This is the name of the parameter e.g. -From user@mail.com
        [String]$EmailFrom, # This is the value [Don't forget the comma at the end!]

        [Parameter(Mandatory = $true,
                        Position = 1,
                        ValueFromPipelineByPropertyName = $true)]
        [Alias('To')]
        [String[]]$EmailTo,

        [Parameter(Mandatory = $true,
                        Position = 2,
                        ValueFromPipelineByPropertyName = $true)]
        [Alias( 'Subj' )]
        [String]$EmailSubj,

        [Parameter(Mandatory = $true,
                        Position = 3,
                        ValueFromPipelineByPropertyName = $true)]
        [Alias( 'Body' )]
        [String]$EmailBody,

        [Parameter(Mandatory = $false,
                        Position = 4,
                        ValueFromPipelineByPropertyName = $true)]
        [Alias( 'Attachment' )]
        [String[]]$EmailAttachments

    )

    # From Christian @ StackOverflow.com
    $SMTPServer = "smtp.gmail.com" 
    $SMTPClient = New-Object Net.Mail.SMTPClient( $SmtpServer, 587 )  
    $SMTPClient.EnableSSL = $true 
    $SMTPClient.Credentials = New-Object System.Net.NetworkCredential( "GMAIL_USERNAME", "GMAIL_PASSWORD" ); 

    # From Core @ StackOverflow.com
    $emailMessage = New-Object System.Net.Mail.MailMessage
    $emailMessage.From = $EmailFrom
    foreach ( $recipient in $EmailTo )
    {
        $emailMessage.To.Add( $recipient )
    }
    $emailMessage.Subject = $EmailSubj
    $emailMessage.Body = $EmailBody
    # Do we have any attachments?
    # If yes, then add them, if not, do nothing
    if ( $EmailAttachments.Count -ne $NULL ) 
    {
        $emailMessage.Attachments.Add()
    }
    $SMTPClient.Send( $emailMessage )
}



# Send an email with the contents of the log buffer.
# SMTP configuration and credentials are in the configuration dictionary.
function Email-Log ($config, $message) {
	$EmailFrom        = $config["EmailFrom"]
	$EmailTo          = $config["EmailTo"]
	$EmailSubject     = "DDNS log $(get-date -format u)"  
	  
	$SMTPServer       = $config["SMTPServer"]
	$SMTPPort         = $config["SMTPPort"]
	$SMTPAuthUsername = $config["SMTPAuthUsername"]
	$SMTPAuthPassword = $config["SMTPAuthPassword"]

	#$mailmessage = New-Object System.Net.Mail.MailMessage 
	#$mailmessage.From = $EmailFrom
	#$mailmessage.To.Add($EmailTo)
	#$mailmessage.Subject = $EmailSubject
	#$mailmessage.Body = $message

	#$SMTPClient = New-Object Net.Mail.SmtpClient($SmtpServer, $SMTPPort) 
	#$SMTPClient.EnableSsl = $true 
	#$SMTPClient.Credentials = New-Object System.Net.NetworkCredential("$SMTPAuthUsername", "$SMTPAuthPassword") 
	#$SMTPClient.Send($mailmessage)

    $credentials = new-object Management.Automation.PSCredential "$SMTPAuthUsername", ("$SMTPAuthPassword" | ConvertTo-SecureString -AsPlainText -Force)
    Send-MailMessage -From $EmailFrom  -to $EmailTo -Subject $EmailSubject `
    -Body $message -SmtpServer $SMTPServer -port $SMTPPort -UseSsl `
    -Credential $credentials
    Add-Message "EMAIL: sent email to $EmailTo"
}

function Get-WebClient ($config) {
	$client = New-Object System.Net.WebClient
	if ($config["ProxyEnabled"]) {
		$ProxyAddress  = $config["ProxyAddress"]
		$ProxyPort     = $config["ProxyPort"]
		$ProxyDomain   = $config["ProxyDomain"]
		$ProxyUser     = $config["ProxyUser"]
		$ProxyPassword = $config["ProxyPassword"]
		$proxy         = New-Object System.Net.WebProxy
		$proxy.Address = $ProxyAddress
		if ($ProxyPort -and $ProxyPort -ne 80) {
			$proxy.Address = "$ProxyAddress`:$ProxyPort"
		} else {
			$proxy.Address = $ProxyAddress
		}
		$account = New-Object System.Net.NetworkCredential($ProxyUser, $ProxyPassword, $ProxyDomain)
		$proxy.Credentials = $account
		$client.Proxy = $proxy
		
	}
	$client
}


Function Update-DDNS{
<#
.SYNOPSIS
    Update-DDNS.ps1 
.DESCRIPTION
    Update Dynamic DNS on Namecheap.com via HTTP GET request.
.EXAMPLE
    Update-DDNS.ps1 
.NOTES
    https://dynamicdns.park-your-domain.com/update?host=[host]&domain=[domain_name]&password=[ddns_password]&ip=[your_ip]
.LINK
	https://www.namecheap.com/support/knowledgebase/article.aspx/29/11/how-do-i-use-a-browser-to-dynamically-update-the-hosts-ip
#>

Param (
    [Parameter(Mandatory=$false,Position=1)]
    [string] $ConfigFile,
    [Parameter(Mandatory=$false,Position=2)]
    [switch] $forceUpdate
)

Begin {
    
    Add-Message "START: Dynamic DNS Update Client Started"

    If (Test-Path $ConfigFile -ErrorAction SilentlyContinue){
        Add-Message "CONFIG: Config file found"
        
    }
    Else {
        Add-Message "ERROR: No configuration file [$ConfigFile] found, exiting script"
    }

    # Load configuration:
    Add-Message "Parsing $ConfigFile"
    $config = Parse-IniFile ($ConfigFile)
    if ($config.Count -eq 0) {
	    Log-Error "The file $ConfigFile didn't have any valid settings"
    }
}
Process{
    try {
	    
	    # Create a new web client
	    $client = Get-WebClient($config.Proxy)

	    # Get current public IP address
	    Add-Message "INFO: Retrieving the current public IP address"
	    $Pattern   = '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}'

        $global:myPublicIP = Invoke-RestMethod 'http://ipinfo.io/json' | Select-Object -ExpandProperty IP
	    Add-Message "INFO: Retrieving stored IP address"
	    $StoredIp  = [Environment]::GetEnvironmentVariable("PUBLIC_IP","User")
        If (!$StoredIp){
            [Environment]::SetEnvironmentVariable("PUBLIC_IP", "0.0.0.0", "User")
            $StoredIp  = [Environment]::GetEnvironmentVariable("PUBLIC_IP","User")
        }

	    if (!($global:myPublicIP -match $Pattern)) {
		    Log-Error "A valid public IP address could not be retrieved"
		    exit 3
	    }

	    Add-Message "Stored IP: [$StoredIp] Retrieved IP: [$global:myPublicIP]"
	    # Compare current IP address with environment variable
        $compareIPs = Compare-Object $StoredIp $global:myPublicIP -IncludeEqual -ExcludeDifferent -ErrorAction SilentlyContinue   
	    if (($compareIPs) -and !$forceUpdate) {
		    Add-Message "INFO: IP has not changed since last run; no changes will be made"
	    }
        Else {
            [Environment]::SetEnvironmentVariable("PUBLIC_IP", $global:myPublicIP, "User")
            Add-Message "UPDATE: Stored IP address updated to: $global:myPublicIP"
    
            #Update DDNS for home network
            $OpenDNS = $config.OpenDNS
            If($OpenDNS){
                $OpenDNSNetwork   = $OpenDNS["OpenDNSNetwork"]
		        $OpenDNSUsername  = $OpenDNS["OpenDNSUsername"]
		        $OpenDNSPassword  = $OpenDNS["OpenDNSPassword"]
		        $OpenDNSURL       = $OpenDNS["OpenDNSURL"]
                $OpenDNSToken     = $OpenDNS["OpenDNSToken"]
            
                Try{
                    $client = New-Object System.Net.Webclient
                    $client.Credentials = New-Object System.Net.NetworkCredential($OpenDNSUsername,$OpenDNSPassword)
                    #$client.UploadString($OpenDNSURL,"/nic/update?hostname=$OpenDNSNetwork")
                    $response = $client.UploadString($OpenDNSURL,"/nic/update?token=$OpenDNSToken&v=2&hostname=$OpenDNSNetwork")
                    Add-Message "OPENDNS: Updated OpenDNS network:" $OpenDNSNetwork
                }
                Catch{
                    Add-Message "ERROR: Unable to update OpenDNS network:" $OpenDNSNetwork
                }
            }
            Else{
                Add-Message "INFO: Skipping OpenDNS configuration, no settings found" $OpenDNSNetwork
            }

            $Domains = $config.Domain
            # Return each hashtable key and value
            $Domains.Keys | % {
                $key = $_
                $keyval = $Domains.$key
                $keyval  
	            Add-Message "UPDATE: Setting IP address on domain registrar for [$key]"
                # spit up key entry to find subdomain
	            $DDNSSubdomain = $key.split(".")[0]
	            $DDNSDomain    = $key.split(".")[1] + "." + $key.split(".")[2]
	            $DDNSPassword  = $keyval
                #sent uri response to namecheap
	            $UpdateUrl     = "https://dynamicdns.park-your-domain.com/update?host=$DDNSSubdomain&domain=$DDNSDomain&password=$DDNSPassword&ip=$global:myPublicIP"
	            $UpdateDDNS    = $client.DownloadString($UpdateUrl)
	            #Add-Message "URL: $UpdateUrl"
                #Add-Message "$UpdateDDNS"
	            Add-Message "UPDATE: DDNS for [$key] Updated at namecheap.com"
	    
            }

            $Ports = $config.PublicIP
            $Ports.Keys | % {
                $key = $_
                $keyval = $Ports.$key
                $keyval
                If ($key -eq "PublicIP"){
                    Add-Message ""
	                Add-Message "UPDATE: Setting Public IP address to: http://$($global:myPublicIP):$($keyval)"
                }
                Else{
                    Add-Message ""
	                Add-Message "UPDATE: Setting Public IP address to: http://$($key):$($keyval)"
                }
            }

            #if ip's were different send email
            If(!$compareIPs -or $force){
                Email-Log $config.Email $Logger
            }
        }
        Add-Message "DONE: Update-DDNS script Finished"
    }
    catch [System.Exception] {
	    Log-Error $_.Exception.Message
	    exit 5
    } 
}
	End {Write-MessageLog}
}