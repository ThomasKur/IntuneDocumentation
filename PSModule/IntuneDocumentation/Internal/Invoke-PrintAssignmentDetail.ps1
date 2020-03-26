Function Invoke-PrintAssignmentDetail(){
    <#
        .SYNOPSIS
        This function is used to print the assignment information to the word file.
        .DESCRIPTION
        This function is used to print the assignment information to the word file. It also gets group names.
        .EXAMPLE
        Invoke-PrintAssignmentDetail -Assignments $assignment
        Prints the information from the Assignents Array
        .NOTES
        NAME: Invoke-PrintAssignmentDetail
        #>
        param(
            $Assignments
        )
        if($Assignments){
            write-Log "Document assignments..."
            Add-WordText -FilePath $FullDocumentationPath -Heading Heading3 -Text "Assignments"
            if($Assignments.count -gt 1){
                $AssignmentsList = @()
                foreach($group in $DCPA){
                    if($null -ne $group.target.groupId){
                        $AssignmentsList += (Get-AADGroup -groupid $group.target.groupId).displayName
                    } else {
                        $AssignmentsList += "$(($group.target.'@odata.type' -replace "#microsoft.graph.",''))"
                    }
                    
                }
                $AssignmentsList | Add-WordText -FilePath $FullDocumentationPath -Size 12
            } else {
                if($null -ne $Assignments.target.groupId){
                    (Get-AADGroup -groupid $Assignments.target.groupId).displayName | Add-WordText -FilePath $FullDocumentationPath  -Size 12
                } else {
                    "$(($Assignments.target.'@odata.type' -replace "#microsoft.graph.",''))" | Add-WordText -FilePath $FullDocumentationPath  -Size 12
                }
                
            }
        }
        
}