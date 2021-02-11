
function Add-Text {
    <#
    .SYNOPSIS
    This function is used to add a line of text in the documentation.
    .EXAMPLE
    Add-Text -format 'docx' -Text "Display Name"
    Adds the text 'Display Name' in the 'docx' format file at $FullDocumentationPath
    .NOTES
    NAME: Add-Text
    #>
    param(
        [Parameter(Mandatory = $true)]
        [String]$format,

        [Parameter(Mandatory = $true)]
        [String]$Text,

        [Parameter(Mandatory=$false, HelpMessage = "Please choose a font size between 4 and 72")]
        [ValidateRange(4, 72)]
        [Int32]$Size
    )
    if ($format -eq 'md') {
        $Text | Out-File -FilePath $FullDocumentationPath -Append -Encoding utf8
    } else {
        Add-WordText -FilePath $FullDocumentationPath -Text $Text -Size $Size
    }
}
