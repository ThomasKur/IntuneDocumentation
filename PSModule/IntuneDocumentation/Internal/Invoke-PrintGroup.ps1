Function Invoke-PrintGroup(){
    <#
    .SYNOPSIS
    This function retrieves details about an AAD group.
    .DESCRIPTION
    This function retrieves details about an AAD group.
    .EXAMPLE
    Invoke-PrintGroup -GroupId $assignment
    Returns the information from the Group

    .OUTPUTS
    Outputs a custom object with the following structure:
    - Name
    - MemberCount
    - GroupType
    - DynamicRule

    .NOTES
    NAME: Invoke-PrintGroup
    #>
    param(
        $GroupIds
    )
    $GroupObjs = @()
    foreach($GroupId in ($GroupIds | Select-Object -Unique)){
        $GroupObj = Get-Groups -groupid $GroupId 
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
        $Members = Get-Groups_Members -groupId $GroupId
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
        $GroupObjs +=[PSCustomObject]@{
            Name = $Name
            MemberCount = $MemberCount
            GroupType = $GType
            DynamicRule = $DynamicRule
        }
    }
    if($null -ne $GroupObjs){
        Add-Table -InputObject $GroupObjs -format $format
    }
}