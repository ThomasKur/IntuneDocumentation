function Add-Header {
    <#
    .SYNOPSIS
    This function is used to add a header in the documentation.
    .EXAMPLE
    Add-Header -format 'md' -Text "Assignments" -level 2
    Adds Assignments as a 2nd level heading in the 'md' format file at $FullDocumentationPath
    .NOTES
    NAME: Add-Header
    #>    
    param(
        [Parameter(Mandatory = $true)]
        [String]$format,

        [Parameter(Mandatory = $true)]
        [String]$Text,

        [Parameter(HelpMessage = "Please choose a heading level between 1 and 6")]
        [ValidateRange(1, 6)]
        [int32]$level
    )
    
    if ($format -eq 'md') {
        # For markdown we already used a H1 for the doc Title, so to ensure proper header order 
        # add 1 to the given header level
        "$('#' * ($level + 1)) $Text`r`n" | Out-File -FilePath $FullDocumentationPath -Append -Encoding utf8
    } else {
        Add-WordText -FilePath $FullDocumentationPath -Heading "Heading$level" -Text $Text
    }
}
