function Add-ScriptText {
    <#
    .SYNOPSIS
    This function is used to add script content in the documentation.
    .EXAMPLE
    Add-ScriptText -format 'docx' -Text "Write-Log $Value"
    Adds the text 'Write-Log $Value' formatted as code in the 'docx' format file at $FullDocumentationPath
    .NOTES
    NAME: Add-ScriptText
    #>    
    param(
        [Parameter(Mandatory = $true)]
        [String]$format,

        [Parameter(Mandatory = $true)]
        [String]$Text
    )
    if ($format -eq 'md') {
        '```' + "`r`n$Text`r`n"  + '```' | Out-File -FilePath $FullDocumentationPath -Append -Encoding utf8
    } else {
        Add-WordText -FilePath $FullDocumentationPath -Text $Text -Size 10 -Italic -FontFamily "Courier New"
    }
}