Function Get-MAM_Windows_Assignment(){
    <#
        .SYNOPSIS
        This function is used to get the Windows MAM Assignments from the Graph API REST interface
        .DESCRIPTION
        The function connects to the Graph API Interface and gets the Windows MAM Assignments
        .EXAMPLE
        Get-MAM_Windows_Assignment -policyId $id
        Returns the Windows MAM Assignments configured in Intune
        .NOTES
        NAME: Get-MAM_Windows_Assignment
        #>
        param(
            $policyId
        )
        try {
            $uri = "https://graph.microsoft.com/Beta/deviceAppManagement/mdmWindowsInformationProtectionPolicies/$policyId/assignments"
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