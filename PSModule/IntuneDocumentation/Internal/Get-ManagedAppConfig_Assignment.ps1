Function Get-ManagedAppConfig_Assignment(){
    <#
        .SYNOPSIS
        This function is used to get the Managed App Config Assignments from the Graph API REST interface
        .DESCRIPTION
        The function connects to the Graph API Interface and gets the Managed App Config Assignments
        .EXAMPLE
        Get-ManagedAppConfig_Assignment -policyId $id
        Returns the Managed App Config Assignments configured in Intune
        .NOTES
        NAME: Get-ManagedAppConfig_Assignment
        #>
        param(
            $policyId
        )
        try {
            $uri = "https://graph.microsoft.com/Beta/deviceAppManagement/targetedManagedAppConfigurations/$policyId/assignments"
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