<#
.SYNOPSIS
   Converts a PowerShell object to a Markdown table. Based on ConvertTo-Markdown from https://github.com/ishu3101/PSMarkdown with added support
   for multiple rows.
.DESCRIPTION
   The ConvertTo-MD function converts a Powershell Object to a Markdown formatted table
.EXAMPLE
   Get-Process | Where-Object {$_.mainWindowTitle} | Select-Object ID, Name, Path, Company | ConvertTo-MD
   This command gets all the processes that have a main window title, and it displays them in a Markdown table format with the process ID, Name, Path and Company.
.EXAMPLE
   ConvertTo-MD (Get-Date)
   This command converts a date object to Markdown table format
.EXAMPLE
   Get-Alias | Select Name, DisplayName | ConvertTo-MD
   This command displays the name and displayname of all the aliases for the current session in Markdown table format
#>
Function ConvertTo-MD {
    [CmdletBinding()]
    [OutputType([string])]
    Param (
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true
        )]
        [PSObject[]]$InputObject
    )

    Begin {
        $items = @()
        $columns = @{}
    }

    Process {
        ForEach($item in $InputObject) {
            $items += $item
            $item.PSObject.Properties | ForEach-Object {
                if($null -ne $_.Value){    
                    if(-not $columns.Contains($_.Name) -or $columns[$_.Name] -lt $_.Value.ToString().Length) {
                        $columns[$_.Name] = $_.Value.ToString().Length
                    }
                }
            }
        }
    }

    End {
        ForEach($key in $($columns.Keys)) {
            $columns[$key] = [Math]::Max($columns[$key], $key.Length)
        }

        $header = @()
        ForEach($key in $columns.Keys) {
            $header += ('{0,-' + $columns[$key] + '}') -f $key
        }
        [string]$HeaderToReturn = '| ' + ( $header -join ' | ' ) + ' |'

        $separator = @()
        ForEach($key in $columns.Keys) {
            $separator += '-' * $columns[$key]
        }
        [string]$SeparatorToReturn = '| ' + ( $separator -join ' | ' ) + ' |'

        [string]$ValuesToReturn = ""

        ForEach($item in $items) {
            $values = @()
            ForEach($key in $columns.Keys) {
                $values += ('{0,-' + $columns[$key] + '}') -f $item.($key)
            }
           $ValuesToReturn += '| ' + ( $values -join ' | ' ) + ' |' + "`r`n"
        }
       return [string]([string]::Concat($HeaderToReturn, "`n", $SeparatorToReturn, "`n", $ValuesToReturn))
    }
}