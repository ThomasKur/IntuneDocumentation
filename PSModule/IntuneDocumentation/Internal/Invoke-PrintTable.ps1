Function Invoke-PrintTable(){
    <#
    .SYNOPSIS
    This function is used to print the assignment information to the word file.
    .DESCRIPTION
    This function is used to print the assignment information to the word file. It also gets group names.
    .EXAMPLE
    Invoke-PrintAssignmentDetail -Assignments $assignment
    Prints the information from the Assignents Array
    .NOTES
    NAME: Invoke-TranslatePropertyName
    #>
    param(
        [Parameter(Mandatory=$true)]
        $Properties,
        [Parameter(Mandatory=$true)]
        [String]$TypeName
    )
    if($Script:UseTranslation){
        Invoke-PrintTableTranslate  -Properties $Properties -TypeName $TypeName
    } else {
        Invoke-PrintTableNormal -Properties $Properties 
    }
}