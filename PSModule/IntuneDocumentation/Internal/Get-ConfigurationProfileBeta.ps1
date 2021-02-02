Function Get-ConfigurationProfileBeta(){
    <#
        .SYNOPSIS
        This function is used to get the Intune Configuration Profiles from the Beta Graph API REST interface
        .DESCRIPTION
        The function connects to the Graph API Interface and gets the Intune Configuration Profiles
        .EXAMPLE
        Get-ConfigurationProfileBeta
        Returns the Configuration Profiles configured in Intune
        .NOTES
        NAME: Get-ConfigurationProfileBeta
        #>
    
        try {
            $uri = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations"
            $request= (Invoke-MSGraphRequest -Url $uri -HttpMethod GET)
            $allScripts= @()

            $request.value.GetEnumerator() | ForEach-Object {
                try{
                    if($null -ne $PSItem.omaSettings){
                        foreach($setting in ($PSItem.omaSettings)){
                            $PSItem | Add-Member -MemberType NoteProperty -Name $setting.displayName -Value $setting
                        }
                    }
                } catch {}
                $PSItem
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