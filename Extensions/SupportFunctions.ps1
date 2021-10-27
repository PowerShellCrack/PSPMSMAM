<#
.SYNOPSIS
Faster version of Compare-Object for large data sets with a single value.
.DESCRIPTION
Uses hash tables to improve comparison performance for large data sets.
.PARAMETER ReferenceObject
Specifies an array of objects used as a reference for comparison.
.PARAMETER DifferenceObject
Specifies the objects that are compared to the reference objects.
.PARAMETER IncludeEqual
Indicates that this cmdlet displays characteristics of compared objects that
are equal. By default, only characteristics that differ between the reference
and difference objects are displayed.
.PARAMETER ExcludeDifferent
Indicates that this cmdlet displays only the characteristics of compared
objects that are equal.
.EXAMPLE
Compare-Object2 -ReferenceObject 'a','b','c' -DifferenceObject 'c','d','e' `
    -IncludeEqual -ExcludeDifferent
.EXAMPLE
Compare-Object2 -ReferenceObject (Get-Content .\file1.txt) `
    -DifferenceObject (Get-Content .\file2.txt)
.EXAMPLE
$p1 = Get-Process
notepad
$p2 = Get-Process
Compare-Object2 -ReferenceObject $p1.Id -DifferenceObject $p2.Id
.NOTES
Does not support objects with properties. Expand the single property you want
to compare before passing it in.
Includes optimization to run even faster when -IncludeEqual is omitted.
#>
function Compare-Object2 {
param(
    [psobject[]]
    $ReferenceObject,
    [psobject[]]
    $DifferenceObject,
    [switch]
    $IncludeEqual,
    [switch]
    $ExcludeDifferent
)

    # Put the difference array into a hash table,
    # then destroy the original array variable for memory efficiency.
    $DifHash = @{}
    $DifferenceObject | ForEach-Object {$DifHash.Add($_,$null)}
    Remove-Variable -Name DifferenceObject

    # Put the reference array into a hash table.
    # Keep the original array for enumeration use.
    $RefHash = @{}
    for ($i=0;$i -lt $ReferenceObject.Count;$i++) {
        $RefHash.Add($ReferenceObject[$i],$null)
    }

    # This code is ugly but faster.
    # Do the IF only once per run instead of every iteration of the ForEach.
    If ($IncludeEqual) {
        $EqualHash = @{}
        # You cannot enumerate with ForEach over a hash table while you remove
        # items from it.
        # Must use the static array of reference to enumerate the items.
        ForEach ($Item in $ReferenceObject) {
            If ($DifHash.ContainsKey($Item)) {
                $DifHash.Remove($Item)
                $RefHash.Remove($Item)
                $EqualHash.Add($Item,$null)
            }
        }
    } Else {
        ForEach ($Item in $ReferenceObject) {
            If ($DifHash.ContainsKey($Item)) {
                $DifHash.Remove($Item)
                $RefHash.Remove($Item)
            }
        }
    }

    If ($IncludeEqual) {
        $EqualHash.Keys | Select-Object @{Name='InputObject';Expression={$_}},`
            @{Name='SideIndicator';Expression={'=='}}
    }

    If (-not $ExcludeDifferent) {
        $RefHash.Keys | Select-Object @{Name='InputObject';Expression={$_}},`
            @{Name='SideIndicator';Expression={'<='}}
        $DifHash.Keys | Select-Object @{Name='InputObject';Expression={$_}},`
            @{Name='SideIndicator';Expression={'=>'}}
    }
}


function Remove-StringDiacritic
{
<#
.SYNOPSIS
	This function will remove the diacritics (accents) characters from a string.

.DESCRIPTION
	This function will remove the diacritics (accents) characters from a string.
.PARAMETER String
	Specifies the String(s) on which the diacritics need to be removed
.PARAMETER NormalizationForm
	Specifies the normalization form to use
	https://msdn.microsoft.com/en-us/library/system.text.normalizationform(v=vs.110).aspx
.EXAMPLE
	PS C:\> Remove-StringDiacritic "L'été de Raphaël"

	L'ete de Raphael
.NOTES
	Francois-Xavier Cat
	@lazywinadm
	www.lazywinadmin.com
	github.com/lazywinadmin
#>
	[CMdletBinding()]
	PARAM
	(
		[ValidateNotNullOrEmpty()]
		[Alias('Text')]
		[System.String[]]$String,
		[System.Text.NormalizationForm]$NormalizationForm = "FormD"
	)

	FOREACH ($StringValue in $String)
	{
		Write-Verbose -Message "$StringValue"
		try
		{
			# Normalize the String
			$Normalized = $StringValue.Normalize($NormalizationForm)
			$NewString = New-Object -TypeName System.Text.StringBuilder

			# Convert the String to CharArray
			$normalized.ToCharArray() |
			ForEach-Object -Process {
				if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($psitem) -ne [Globalization.UnicodeCategory]::NonSpacingMark)
				{
					[void]$NewString.Append($psitem)
				}
			}

			#Combine the new string chars
			Write-Output $($NewString -as [string])
		}
		Catch
		{
			Write-Error -Message $Error[0].Exception.Message
		}
	}
}