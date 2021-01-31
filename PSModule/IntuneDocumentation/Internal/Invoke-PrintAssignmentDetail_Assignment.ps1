Function Invoke-PrintAssignmentDetail_Assignment(){
    <#
    .SYNOPSIS
    This function is used to collect information about assignment and the group.
    .DESCRIPTION
    This function is used to collect information about assignment and the group.
    .EXAMPLE
    Invoke-PrintAssignmentDetail_Assignment -Assignment $assignment
    Returns the information from the Assignent

    .OUTPUTS
    Outputs a custom object with the following structure:
    - Name
    - MemberCount
    - Type
    - DynamicRule

    .NOTES
    NAME: Invoke-PrintAssignmentDetail_Assignment 
    #>
    param(
        $Assignment
    )
    if($null -ne $Assignment.target.groupId){
        $GroupObj = Get-Groups -groupid $Assignment.target.groupId 
        $Name = $GroupObj.displayName
        if($GroupObj.groupTypes -contains "DynamicMembership"){
            if($GroupObj.membershipRule -like "*user.*"){
                $GType = "DynamicUser"
            } else {
                $GType = "DynamicDevice"
            }
        } else {
            $GType = "Static"
        }
        $Members = Get-Groups_Members -groupId $Assignment.target.groupId
        if($null -eq $Members.count){
            if($null -eq $Members){
                $MemberCount = 1
            } else {
                $MemberCount = 0
            }
        } else {
            $MemberCount = $Members.count
        }
        $DynamicRule = $GroupObj.membershipRule
        if($null -eq $DynamicRule){
            $DynamicRule = "-"
        }
        $returnObj =[PSCustomObject]@{
            Name = $Name
            MemberCount = $MemberCount
            GroupType = $GType
            DynamicRule = $DynamicRule
        }
    } else {

        $Name = "$(($Assignment.target.'@odata.type' -replace "#microsoft.graph.",''))"
        switch ( $Name )
        {
            "allDevicesAssignmentTarget" { $Name = "All Devices" }
            "allLicensedUsersAssignmentTarget" { $Name = "All Users"  }
        }
        
        $returnObj =[PSCustomObject]@{
            Name = $Name
            MemberCount = "-"
            GroupType = "BuilIn"
            DynamicRule = "-"
        }
    } 

    #Intent if Available
    if($null -ne $Assignment.intent){
        $returnObj | Add-Member -MemberType NoteProperty -Name "Intent" -Value $Assignment.intent
    } else {
        $returnObj | Add-Member -MemberType NoteProperty -Name "Intent" -Value "-"
    }
    # Source
    if($null -ne $Assignment.source){
        $returnObj | Add-Member -MemberType NoteProperty -Name "Source" -Value $Assignment.source
    } else {
        $returnObj | Add-Member -MemberType NoteProperty -Name "Source" -Value "-"
    }
    # Include or Exclude
    if($Assignment.'@odata.type' -imatch 'exclusion'){
        $returnObj | Add-Member -MemberType NoteProperty -Name "Type" -Value "Exclude"
    } else {
        $returnObj | Add-Member -MemberType NoteProperty -Name "Type" -Value "Include"
    }

    $returnObj
}