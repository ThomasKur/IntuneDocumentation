function Add-Table {
    <#
    .SYNOPSIS
    This function is used to add a table using an Object as input in the documentation.
    .EXAMPLE
    Add-Table -InputObject $Properties -format 'md'
    Converts the $Properties object to a Markdown formatted table and adds to the 'md' format file at $FullDocumentationPath
    .NOTES
    NAME: Add-Table
    #>     
    param(
        [Parameter(
            Mandatory = $true,
            ValueFromPipeline = $true
        )]
        [PSObject[]]$InputObject,

        [Parameter(Mandatory = $true)]
        [String]$format,

        [Parameter(Mandatory = $false)]
        [String]$AutoFitStyle = 'Window'
    )
    process {
        if ($format -eq 'md') {
            ConvertTo-MD ($InputObject) | Out-File -FilePath $FullDocumentationPath -Append -Encoding utf8
        } else {
            $InputObject | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle $AutoFitStyle -Design LightListAccent2 
        }
    }
}
