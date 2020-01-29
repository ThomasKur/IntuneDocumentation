Function Get-ConditionalAccess(){
    <#
    .SYNOPSIS
    This function is used to get the Conditional Access from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets the Azure AD Conditional Access Configuration
    .EXAMPLE
    Get-ConditionalAccess
    Returns the Conditional Access Configuration configured in AzureAD
    .NOTES
    NAME: Get-ConditionalAccess
    #>
    try {
        $uri = "https://graph.microsoft.com/Beta/conditionalAccess/policies"
        (Invoke-MSGraphRequest -Url $uri -HttpMethod GET).Value
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