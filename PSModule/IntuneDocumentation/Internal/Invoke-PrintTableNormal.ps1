Function Invoke-PrintTableNormal(){
    <#
    .SYNOPSIS
    This function is used to print the configuration without translation to the word file.
    .EXAMPLE
    Invoke-TableNormal -Properties $p -TypeName $t
    Prints the information from the Config Array
    .NOTES
    NAME: Invoke-TableNormal
    #>
    param(
        [Parameter(Mandatory=$true)]
        $Properties
    )
    $MaxStringLengthSettings = 350
    $ht = @{}
    
    foreach($p in $Properties) { 
        $Name = $p.Name       
        if((Format-MsGraphData "$($p.Value)").Length -gt $MaxStringLengthSettings){
            $Value = "$((Format-MsGraphData "$($p.Value)").substring(0, $MaxStringLengthSettings))..."
        } else {
            $Value = "$((Format-MsGraphData "$($p.Value)")) "
        }
        
        if($null -eq $Value){
            $Value = ""
        } elseif ($format -eq 'md') {
            # Markdown has rendering issues with new lines in a table
            $Value = ($Value -replace ('\r\n', '')) -replace ('\n','')
            # some oma setting values are in xml format, wrap this part to avoid rendering issues
            $pattern = [regex]'(.*)value=<(.*)'
            if ($Value -match $pattern) {
                $Value = $pattern.Replace($Value, '$1value=<code><$2</code>', 1)
            }
        }
        $ht[$Name] = $Value
    }
    Add-Table -InputObject ($ht.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) -format $format
}