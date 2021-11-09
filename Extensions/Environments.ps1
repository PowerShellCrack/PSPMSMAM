#region FUNCTION: Check if running in WinPE
Function Test-WinPE{
    return Test-Path -Path Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlset\Control\MiniNT
  }
  #endregion

#region FUNCTION: Attempt to connect to Task Sequence environment
Function Test-SMSTSENV{
  <#
      .SYNOPSIS
          Tries to establish Microsoft.SMS.TSEnvironment COM Object when running in a Task Sequence

      .REQUIRED
          Allows Set Task Sequence variables to be set

      .PARAMETER ReturnLogPath
          If specified, returns the log path, otherwise returns ts environment
  #>
  param(
      [switch]$ReturnLogPath
  )

  Begin{
      ## Get the name of this function
      [string]${CmdletName} = $MyInvocation.MyCommand

      if ($PSBoundParameters.ContainsKey('Verbose')) {
          $VerbosePreference = $PSCmdlet.SessionState.PSVariable.GetValue('VerbosePreference')
      }
  }
  Process{
      try{
          # Create an object to access the task sequence environment
          $Script:tsenv = New-Object -COMObject Microsoft.SMS.TSEnvironment
          Write-Debug ("{0} ::  Task Sequence environment detected!" -f ${CmdletName})
      }
      catch{
          Write-Debug ("{0} ::  Task Sequence environment NOT detected. Running with script environment variables" -f ${CmdletName})

          #set variable to null
          $Script:tsenv = $null
      }
      Finally{
          #set global Logpath
          if ($Script:tsenv){
              #grab the progress UI
              $Script:TSProgressUi = New-Object -ComObject Microsoft.SMS.TSProgressUI

              # Convert all of the variables currently in the environment to PowerShell variables
              $tsenv.GetVariables() | ForEach-Object { Set-Variable -Name "$_" -Value "$($tsenv.Value($_))" }

              # Query the environment to get an existing variable
              # Set a variable for the task sequence log path

              #Something like: C:\MININT\SMSOSD\OSDLOGS
              #[string]$LogPath = $tsenv.Value("LogPath")
              #Somthing like C:\WINDOWS\CCM\Logs\SMSTSLog
              [string]$LogPath = $tsenv.Value("_SMSTSLogPath")

          }
          Else{
              [string]$LogPath = $env:Temp
              $Script:tsenv = $false
          }
      }
  }
  End{
      If($ReturnLogPath){
          return $LogPath
      }
      Else{
          return $Script:tsenv
      }
  }
}
#endregion

function Show-ProgressStatus
{
    <#
    .SYNOPSIS
        Shows task sequence secondary progress of a specific step

    .DESCRIPTION
        Adds a second progress bar to the existing Task Sequence Progress UI.
        This progress bar can be updated to allow for a real-time progress of
        a specific task sequence sub-step.
        The Step and Max Step parameters are calculated when passed. This allows
        you to have a "max steps" of 400, and update the step parameter. 100%
        would be achieved when step is 400 and max step is 400. The percentages
        are calculated behind the scenes by the Com Object.

    .PARAMETER Message
        The message to display the progress
    .PARAMETER Step
        Integer indicating current step
    .PARAMETER MaxStep
        Integer indicating 100%. A number other than 100 can be used.
    .INPUTS
         - Message: String
         - Step: Long
         - MaxStep: Long
    .EXAMPLE
        Set's "Custom Step 1" at 30 percent complete
        Show-ProgressStatus -Message "Running Custom Step 1" -Step 100 -MaxStep 300

    .EXAMPLE
        Set's "Custom Step 1" at 50 percent complete
        Show-ProgressStatus -Message "Running Custom Step 1" -Step 150 -MaxStep 300
    .EXAMPLE
        Set's "Custom Step 1" at 100 percent complete
        Show-ProgressStatus -Message "Running Custom Step 1" -Step 300 -MaxStep 300
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string] $Message,
        [Parameter(Mandatory=$true)]
        [int]$Step,
        [Parameter(Mandatory=$true)]
        [int]$MaxStep,
        [string]$SubMessage,
        [int]$IncrementSteps
    )

    Begin{

        If($SubMessage){
            $StatusMessage = ("{0} [{1}]" -f $Message,$SubMessage)
        }
        Else{
            $StatusMessage = $Message
        }
    }
    Process
    {
        If($Script:tsenv){
            $Script:TSProgressUi.ShowActionProgress(`
                $Script:tsenv.Value("_SMSTSOrgName"),`
                $Script:tsenv.Value("_SMSTSPackageName"),`
                $Script:tsenv.Value("_SMSTSCustomProgressDialogMessage"),`
                $Script:tsenv.Value("_SMSTSCurrentActionName"),`
                [Convert]::ToUInt32($Script:tsenv.Value("_SMSTSNextInstructionPointer")),`
                [Convert]::ToUInt32($Script:tsenv.Value("_SMSTSInstructionTableSize")),`
                $StatusMessage,`
                $Step,`
                $Maxstep)
        }
        Else{
            Write-Progress -Activity "$Message ($Step of $Maxstep)" -Status $StatusMessage -PercentComplete (($Step / $Maxstep) * 100) -id 1
        }
    }
    End{
    }
}


Function Invoke-StatusUpdate{
    param(
        [Parameter(Mandatory=$true)]
        [string] $Message,
        [int]$Step,
        [int]$MaxStep,
        [boolean]$UpdateUI,
        [hashtable]$UpdateTextElement,
        [hashtable]$UpdateBorderElement,
        [string[]]$HideUIElement,
        [string[]]$ShowUIElement,
        [ValidateSet("Green", "Yellow", "Red")]
        [string]$DisplayColor,
        [switch]$Outhost,
        [switch]$ShowProgress
    )

    Switch($DisplayColor){
    'Green'  {$ProgressColor="LightGreen";$MessageColor='Green';$BorderColor='Black'}
    'Yellow' {$ProgressColor="Yellow";$MessageColor='Yellow';$BorderColor='Yellow'}
    'Red'    {$ProgressColor="Red";$MessageColor='Red';$BorderColor='Red'}
    default {$ProgressColor="LightGreen";$MessageColor='white';$BorderColor='Black'}
    }

    #ensure the steps are nto out of bounds
    If($Maxstep -eq 0){$Maxstep=1}
    If($Step -gt $Maxstep){$Maxstep=$Step}

    #display progress if stpes are provided
    If($ShowProgress){
        If($Step -and $Maxstep){
            Show-ProgressStatus -Message $Message -Step $Step -MaxStep $Maxstep
        }Else{
            Show-ProgressStatus -Message $Message -Step 0 -MaxStep 1
        }
    }

    If($Outhost){Write-host $Message -ForegroundColor $MessageColor}

    If($UpdateUI){
        If(!($Global:StatusScreen.Window.IsInitialized)){
            Start-UIStatusScreen
        }

        $Global:StatusScreen.Window.Dispatcher.Invoke("Normal",[action]{
            $Global:StatusScreen.window.Topmost = $true
        })

        #update progressbar if steps are provided; otherwise scroll the progress bar
        If($Step -and $Maxstep){
            $Percentage = (($Step / $Maxstep) * 100)
            Update-UIProgress -Label $Message -Progress $Percentage -Color $ProgressColor
        }
        Else{
            Update-UIProgress -Label $Message -Color $ProgressColor -Indeterminate
        }

        If($PSBoundParameters.ContainsKey('UpdateTextElement') ){
            #update each text element
            $UpdateTextElement.GetEnumerator() | ForEach-Object {
                #write-host ($_.key + '=' + $_.Value)
                Update-UIElementProperty -ElementName $_.key -Property Text -Value $_.Value
            }
        }

        If($PSBoundParameters.ContainsKey('UpdateBorderElement') ){
            #update border element
            $UpdateBorderElement.GetEnumerator() | ForEach-Object {
                Update-UIElementProperty -ElementName $_.key -Property BorderThickness -Value $_.Value
                If($BorderColor -ne 'Black'){
                    Update-UIElementProperty -ElementName $_.key -Property BorderBrush -Value $BorderColor
                }
            }
        }

        If($PSBoundParameters.ContainsKey('HideUIElement') ){
            #hide each element
            Foreach($HElement in $HideUIElement){Update-UIElementProperty -ElementName $HElement -Property Visibility -Value 'Hidden'}
        }

        If($PSBoundParameters.ContainsKey('ShowUIElement') ){
            #show each element
            Foreach($SElement in $ShowUIElement){Update-UIElementProperty -ElementName $SElement -Property Visibility -Value 'Visible'}
        }

        #if the steps are done and progress color is green; show countdown
        If( ($Step -eq $Maxstep) -and ($DisplayColor -eq 'Green') ){
            Invoke-UICountdown -CountDown 6 -TextElement 'CloseWindow' -Action {Close-UIStatusScreen}
        }
    }
}


<# STATUS SAMPLE CODE (without function)

If($ShowStatusUI){
    Start-UIStatusScreen
    Update-UIProgress -Label $message -Indeterminate
}

If($ShowStatusUI){
    Update-UIProgress -Label $message -Progress 100 -Color Red
    Update-UIElementProperty -ElementName 'Hash_DeployTS_Text' -Property Text -Value ("TaskSequence ID missing")
    Update-UIElementProperty -ElementName 'CloseWindow' -Property Visibility -Value 'Hidden'
    Update-UIElementProperty -ElementName 'Shutdown' -Property Visibility -Value 'Visible'
}
Show-ProgressStatus -Message $message -Step ($stepCounter++) -MaxStep $script:Maxsteps


Write-host $message -NoNewLine
If($ShowStatusUI){
    Update-UIProgress -Label $Message -Progress $i
    Update-UIElementProperty -ElementName 'Hash_DeployWIM_Text' -Property BorderThickness -Value 1
    Update-UIElementProperty -ElementName 'Hash_DeployWIM_Text' -Property Text -Value ('Hashing WIM File...')
}
Show-ProgressStatus -Message $message -Step ($stepCounter++) -MaxStep $script:Maxsteps

#>