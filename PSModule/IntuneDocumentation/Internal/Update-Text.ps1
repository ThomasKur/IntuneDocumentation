function Update-Text {
    <#
    .SYNOPSIS
    This function is used to replace text found in the documentation with a new value.
    .EXAMPLE
    Update-Text -format 'md' -SearchText "abc" -NewText "def"
    Updates all occurences of 'abc' with 'def' in the 'md' format file at $FullDocumentationPath
    .NOTES
    NAME: Update-Text
    #>
    param(
        [Parameter(Mandatory = $true)]
        [String]$format,

        [Parameter(Mandatory = $true)]
        [String]$SearchText,

        [Parameter(Mandatory = $true)]
        [String]$NewText
    )
    
    if ($format -eq 'md') {
        ((Get-Content -path $FullDocumentationPath -Raw) -replace $SearchText, $NewText) | Set-Content -Path $FullDocumentationPath
    } else {
        Update-WordText -FilePath $FullDocumentationPath -ReplacingText $SearchText -NewText $NewText
    }
}