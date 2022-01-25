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