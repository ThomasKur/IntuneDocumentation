Function Get-ADMXBasedConfigurationProfile_Assignment(){
    <#
    .SYNOPSIS
    This function is used to get the ADMX Policy Assignments from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets the Intune ADMX Configuration Assignments
    .EXAMPLE
    Get-ADMXBasedConfigurationProfile_Assignment -ADMXBasedConfigurationProfileId $id
    Returns the ADMX based Configuration Profile Assignments configured in Intune
    .NOTES
    NAME: Get-ADMXBasedConfigurationProfile_Assignment
    #>
    param(
        $ADMXBasedConfigurationProfileId
    )
    try {
        $Policies = Invoke-MSGraphRequest -HttpMethod GET -Url "https://graph.microsoft.com/Beta/deviceManagement/groupPolicyConfigurations/$ADMXBasedConfigurationProfileId/assignments"
        $Policies.Value
    } catch {     
        Write-Log "Response content:`n$responseBody" -Type Error
        Write-Log "Failed to get ADMX based Intune Policies." -Type Error -Exception $_.Exception
    }
}