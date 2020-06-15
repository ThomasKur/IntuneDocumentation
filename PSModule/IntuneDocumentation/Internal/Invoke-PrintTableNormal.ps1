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
        }
        $ht[$Name] = $Value
    }
    ($ht.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2
}