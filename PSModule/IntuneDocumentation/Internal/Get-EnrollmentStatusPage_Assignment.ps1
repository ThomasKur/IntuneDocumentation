Function Get-EnrollmentStatusPage_Assignment(){
    <#
        .SYNOPSIS
        This function is used to get the Enrollment Status Page configuration Assignments from the Graph API REST interface
        .DESCRIPTION
        The function connects to the Graph API Interface and gets the Enrollment Status Page Configuration Assignments
        .EXAMPLE
        Get-EnrollmentStatusPage_Assignment -deviceEnrollmentConfigurationsId $id
        Returns the Enrollment Status Page Configuration Assignments configured in Intune
        .NOTES
        NAME: Get-EnrollmentStatusPage_Assignment
        #>
        param(
            $deviceEnrollmentConfigurationsId
        )
        try {
            $uri = "https://graph.microsoft.com/Beta/deviceManagement/deviceEnrollmentConfigurations/$deviceEnrollmentConfigurationsId/assignments"
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