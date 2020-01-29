Function Get-DeviceManagementScript(){
    <#
        .SYNOPSIS
        This function is used to get the Intune PowerShell Scripts from the Graph API REST interface
        .DESCRIPTION
        The function connects to the Graph API Interface and gets the Intune PowerShell Scripts including the scripts
        .EXAMPLE
        Get-DeviceManagementScript
        Returns the Enrollment Status Page Configuration configured in Intune
        .NOTES
        NAME: Get-DeviceManagementScript
        #>
    
        try {
            $uri = "https://graph.microsoft.com/Beta/deviceManagement/deviceManagementScripts"
            $request= (Invoke-MSGraphRequest -Url $uri -HttpMethod GET)
            $allScripts= @()

            $request.value.GetEnumerator() | ForEach-Object {

                $currentScript =Invoke-MSGraphRequest -HttpMethod GET -Url "https://graph.microsoft.com/Beta/deviceManagement/deviceManagementScripts/$($PSItem.id)"
                
                $allScripts += [PSCustomObject]@{
                    id = $currentScript.id
                    displayName = $currentScript.displayName
                    description = $currentScript.description
                    enforceSignatureCheck = $PSItem.enforceSignatureCheck
                    runAs32Bit = $PSItem.runAs32Bit
                    runAsAccount = $PSItem.runAsAccount
                    fileName = $PSItem.fileName
                    scriptContent = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($currentScript.scriptContent))
                }
            }
            $allScripts
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