Function Get-AzureADApplicationName(){
    <#
    .SYNOPSIS
    This function is used to get the AzureAD Application Name by ID from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets the Azure AD Application Name
    .EXAMPLE
    Get-AzureADApplicationName -AppId 162358712538975698
    Returns the Application Name for the given Application id
    .NOTES
    NAME: Get-AzureADApplicationName
    #>
    param(
            [String]
            $AppId
        )
    try {
        if($AppId -match("^(\{){0,1}[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}(\}){0,1}$")){
            $uri = "https://graph.microsoft.com/beta/servicePrincipals?`$Filter=appId%20eq%20%27$AppId%27"
            $app = (Invoke-MSGraphRequest -Url $uri -HttpMethod GET).Value[0]
            "$($app.displayName)($AppId)"
        } else {
            $AppId
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