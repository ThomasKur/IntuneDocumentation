Function Get-AzureADRole(){
    <#
    .SYNOPSIS
    This function is used to get the AzureAD Role Name by ID from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets the Azure AD Role Name
    .EXAMPLE
    Get-AzureADRole -RoleId 162358712538975698
    Returns the Role Name for the given Role id
    .NOTES
    NAME: Get-AzureADRole
    #>
    param(
            [String]
            $RoleId
        )
    try {
        if($RoleId -match("^(\{){0,1}[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}(\}){0,1}$")){
            $uri = "https://graph.microsoft.com/beta/directoryRoleTemplates/$RoleId"
            (Invoke-MSGraphRequest -Url $uri -HttpMethod GET).displayName
        } else {
            $RoleId
        }
    } catch {
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Log "Response content:`n$responseBody" -Type Error
        Write-Log "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)" -Type Error
    }
}