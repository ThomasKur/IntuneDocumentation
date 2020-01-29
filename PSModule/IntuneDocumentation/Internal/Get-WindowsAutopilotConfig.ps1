Function Get-WindowsAutopilotConfig(){
    <#
    .SYNOPSIS
    This function is used to get the AutoPilot configuration from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets the AutoPilot Configuration
    .EXAMPLE
    Get-WindowsAutopilotConfig
    Returns the AutoPilot Configuration configured in Intune
    .NOTES
    NAME: Get-WindowsAutopilotConfig
    #>
    try {
        $uri = "https://graph.microsoft.com/Beta/deviceManagement/windowsAutopilotDeploymentProfiles"
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