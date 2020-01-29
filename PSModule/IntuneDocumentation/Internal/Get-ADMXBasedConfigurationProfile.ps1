Function Get-ADMXBasedConfigurationProfile(){
    <#
    .SYNOPSIS
    This function is used to get the ADMX Policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets the Intune ADMX Configuration
    .EXAMPLE
    Get-ADMXBasedConfigurationProfile
    Returns the ADMX based Configuration Profiles configured in Intune
    .NOTES
    NAME: Get-ADMXBasedConfigurationProfile
    #>
    try {
        Update-MSGraphEnvironment -SchemaVersion 'beta'
        Connect-MSGraph
        $Policies = Invoke-MSGraphRequest -HttpMethod GET -Url "/deviceManagement/groupPolicyConfigurations"
        $return = @()
        foreach($Policy in $Policies.value){
            $return2 = @()
            $values = Invoke-MSGraphRequest -HttpMethod GET -Url "/deviceManagement/groupPolicyConfigurations/$($Policy.Id)/definitionValues"
            foreach($value in $values.value){
                try{
                    $definition = (Invoke-MSGraphRequest -HttpMethod GET -Url "/deviceManagement/groupPolicyConfigurations/$($Policy.Id)/definitionValues/$($value.id)/definition")
                    $res = Invoke-MSGraphRequest -HttpMethod GET -Url "/deviceManagement/groupPolicyConfigurations/$($Policy.Id)/definitionValues/$($value.id)/presentationValues"
                    $return2 += [PSCustomObject]@{ 
                        DisplayName = $definition.displayName
                        #ExplainText = $definition.explainText
                        Scope = $definition.classType
                        Path = $definition.categoryPath
                        SupportedOn = $definition.supportedOn
                        Enabled = $value.enabled
                        Value = if($res.value.value.GetType().baseType.Name -eq "Array"){ $res.value.value -join ", "  }else { $res.value.value }
                    }
                } catch {
                    Write-Log -Message "Error reading ADMX setting" -Type Warn -Exception $_.Exception
                }
            }
            $return += [PSCustomObject]@{ 
                DisplayName = $Policy.displayName
                Settings = $return2
            }
        }
        Update-MSGraphEnvironment -SchemaVersion v1.0
        Connect-MSGraph
        return $return
    } catch {     
        Write-Log "Response content:`n$responseBody" -Type Error
        Write-Log "Failed to get ADMX based Intune Policies." -Type Error -Exception $_.Exception
    }
}