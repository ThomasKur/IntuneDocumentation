Function Get-AzureADUser(){
    <#
    .SYNOPSIS
    This function is used to get the AzureAD User Name by ID from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets the Azure AD User Name
    .EXAMPLE
    Get-AzureADUser -UserId 162358712538975698
    Returns the User Name for the given User id
    .NOTES
    NAME: Get-AzureADUser
    #>
    param(
            [String]
            $UserId
        )
    try {
        if($UserId -match("^(\{){0,1}[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}(\}){0,1}$")){
            $uri = "https://graph.microsoft.com/beta/users/$UserId"
            $user = (Invoke-MSGraphRequest -Url $uri -HttpMethod GET)
            "$($user.displayName)($($user.userPrincipalName))"
        } else{
            $UserId
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