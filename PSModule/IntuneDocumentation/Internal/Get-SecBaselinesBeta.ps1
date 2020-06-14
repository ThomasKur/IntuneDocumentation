Function Get-SecBaselinesBeta(){
    <#
    .SYNOPSIS
    This function is used to get the all Security Baselines from the Beta Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets the Security Baselines
    .EXAMPLE
    Get-SecBaselinesBeta
    Returns the Security Baselines configured in Intune
    .NOTES
    NAME: Get-SecBaselinesBeta
    #>
    try {
        $uri = "https://graph.microsoft.com/beta/deviceManagement/intents"
        $templates = (Invoke-MSGraphRequest -Url $uri -HttpMethod GET).Value
        $returnTemplates = @()
        foreach($template in $templates){
            $settings = Invoke-MSGraphRequest -Url "https://graph.microsoft.com/beta/deviceManagement/intents/$($template.id)/settings"
            $returnTemplate = [PSCustomObject]@{ id = $template.id }
            $returnTemplate | Add-Member Noteproperty -Name displayName -Value $template.displayName -Force 

            $TempSettings = @()
            foreach($setting in $settings.value){
                # $settingDef = Invoke-MSGraphRequest -Url "https://graph.microsoft.com/beta/deviceManagement/settingDefinitions/$($setting.id)" -ErrorAction SilentlyContinue
                # $displayName = $settingDef.Value.displayName 
                # if($null -eq $displayName){
                $displayName = $setting.definitionId -replace "deviceConfiguration--","" -replace "admx--",""  -replace "_"," "
                # }
                if($null -eq $setting.value){
                    $v = ""
                } else {
                    $v = $setting.value
                }
                $TempSetting = [PSCustomObject]@{ displayName = $displayName; Value = $v }
                $TempSettings += $TempSetting
            }
            $returnTemplate | Add-Member Noteproperty -Name Settings -Value $TempSettings -Force
            $assignments = Invoke-MSGraphRequest -Url "https://graph.microsoft.com/beta/deviceManagement/intents/$($template.id)/assignments"
            $returnTemplate | Add-Member Noteproperty -Name Assignments -Value $assignments.Value -Force
            $returnTemplates += $returnTemplate
        }
        $returnTemplates

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