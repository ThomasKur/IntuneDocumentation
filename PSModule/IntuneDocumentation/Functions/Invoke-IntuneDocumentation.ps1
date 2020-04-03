Function Invoke-IntuneDocumentation(){
    <#
    .DESCRIPTION
    This Script documents an Intune Tenant with almost all settings, which are available over the Graph API.
    NOTE: This no longer does Conditional Access
    The Script is using the PSWord and Microsoft.Graph.Intune Module. Therefore you have to install them first.

    .EXAMPLE
    Invoke-IntuneDocumentation -FullDocumentationPath c:\temp\IntuneDoc.docx

    .NOTES
    Author: Thomas Kurth/baseVISION
    Co-Author: jflieben
    Co-Author: Robin Dadswell
    Date:   28.07.2019

    History
        See Release Notes in Github.

    ExitCodes:
        99001: Could not Write to LogFile
        99002: Could not Write to Windows Log
        99003: Could not Set ExitMessageRegistry
    #>
    [CmdletBinding()]
    Param(
        [ValidateScript({
            if($_ -notmatch "(\.docx)"){
                throw "The file specified in the path argument must be of type docx"
            }
            return $true 
        })]
        [System.IO.FileInfo]$FullDocumentationPath = ".\IntuneDocumentation.docx"
    )
    ## Manual Variable Definition
    ########################################################
    $DebugPreference = "Continue"
    $ScriptName = "DocumentIntune"
    $MaxStringLengthSettings = 350

    #region Initialization
    ########################################################
    Write-Log "Start Script $Scriptname"
    #region Authentication
    Connect-MSGraph
    #endregion
    #region Main Script
    ########################################################
    #region Save Path

    #endregion
    #region CopyTemplate
    if((Test-Path -Path $FullDocumentationPath)){
        Write-Log "File already exists, does not use built-in template." -Type Warn
    } else {
        Copy-Item "$PSScriptRoot\..\Data\Template.docx" -Destination $FullDocumentationPath
        Update-WordText -FilePath $FullDocumentationPath -ReplacingText "DATE" -NewText (Get-Date -Format "HH:mm dd.MM.yyyy")
        try{
            $org = Invoke-MSGraphRequest -Url /organization
            Update-WordText -FilePath $FullDocumentationPath -ReplacingText "TENANT" -NewText $org.value.displayName
        } catch{
            Update-WordText -FilePath $FullDocumentationPath -ReplacingText "TENANT" -NewText ""
        }
        
    }
    #endregion
    #region Document Apps
    $Intune_Apps = @()
    Get-IntuneMobileApp | ForEach-Object {
        $App_Assignment = Get-IntuneMobileAppAssignment -mobileAppId $_.id
        if($App_Assignment){
            $Intune_App = New-Object -TypeName PSObject
            $Intune_App | Add-Member Noteproperty "Publisher" $_.publisher
            $Intune_App | Add-Member Noteproperty "DisplayName" $_.displayName
            $Intune_App | Add-Member Noteproperty "Type" (Format-MsGraphData $_.'@odata.type')
            $Assignments = @()
            foreach($Assignment in $App_Assignment) {
                if($null -ne $Assignment.target.groupId){
                    $Assignments += "$((Get-AADGroup -groupid $Assignment.target.groupId).displayName)`n - Intent:$($Assignment.intent)"
                } else {
                    $Assignments += "$(($Assignment.target.'@odata.type' -replace "#microsoft.graph.",''))`n - Intent:$($Assignment.intent)"
                }
            }
            $Intune_App | Add-Member Noteproperty "Assignments" ($Assignments -join "`n")
            $Intune_Apps += $Intune_App
        }
    } 
    Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Applications"
    $Intune_Apps | Sort-Object Publisher,DisplayName | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Contents -Design LightListAccent2
    #endregion
    #region Document App protection policies
    Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "App Protection Policies"
    $MAMs = Get-IntuneAppProtectionPolicy
    foreach($MAM in $MAMs){
        write-Log "App Protection Policy: $($MAM.displayName)"
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text $MAM.displayName
        $ht2 = @{}
        $MAM.psobject.properties | ForEach-Object { $ht2[(Format-MsGraphData $($_.Name))] = (Format-MsGraphData $($_.Value)) }
        ($ht2.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2 
        if($MAM.'@odata.type' -eq "#microsoft.graph.iosManagedAppProtection"){
            $MAMA = Get-DeviceAppManagement_IosManagedAppProtections_Assignments -iosManagedAppProtectionId $MAM.id -iosManagedAppProtectionODataType microsoft.graph.iosManagedAppProtection
        }
        if($MAM.'@odata.type' -eq "#microsoft.graph.androidManagedAppProtection"){
            $MAMA = Get-DeviceAppManagement_AndroidManagedAppProtections_Assignments -androidManagedAppProtectionId $MAM.id -androidManagedAppProtectionODataType microsoft.graph.androidManagedAppProtection 
        }
        if($MAM.'@odata.type' -eq "#microsoft.graph.mdmWindowsInformationProtectionPolicy"){
            $MAMA = Get-DeviceAppManagement_WindowsInformationProtectionPolicies_Assignments -windowsInformationProtectionPolicyId $MAM.id -windowsInformationProtectionPolicyODataType microsoft.graph.windowsInformationProtectionPolicy
        }
        Invoke-PrintAssignmentDetail -Assignments $MAMA
    }
    #endregion
    #region Document App configuration policies
    Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "App Configuration Policies"
    $MACs = Get-DeviceAppManagement_MobileAppConfigurations
    foreach($MAC in $MACs){
        write-Log "App Protection Policy: $($MAC.displayName)"
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text $MAC.displayName
        $ht2 = @{}
        $MAC.encodedSettingXml = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($MAC.encodedSettingXml))
        $MAC.psobject.properties | ForEach-Object { $ht2[(Format-MsGraphData $($_.Name))] = (Format-MsGraphData $($_.Value)) }
        ($ht2.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2 
        $id = $MAM.id
        
        $MAMA = Get-DeviceAppManagement_MobileAppConfigurations_Assignments -managedDeviceMobileAppConfigurationId $id
        Invoke-PrintAssignmentDetail -Assignments $MAMA
    }
    #endregion
    #region Document Compliance Policies
    Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Compliance Policies"
    $DCPs = Get-IntuneDeviceCompliancePolicy
    foreach($DCP in $DCPs){
        write-Log "Device Compliance Policy: $($DCP.displayName)"
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text $DCP.displayName
        $ht2 = @{}
        $DCP.psobject.properties | ForEach-Object { $ht2[(Format-MsGraphData $($_.Name))] = (Format-MsGraphData $($_.Value)) }
        ($ht2.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2 
        $id = $DCP.id
        $DCPA = Get-IntuneDeviceCompliancePolicyAssignment -deviceCompliancePolicyId $id
        Invoke-PrintAssignmentDetail -Assignments $DCPA
    }
    #endregion
    #region Document T&C
    write-Log "Terms and Conditions"
    $GAndTs = Get-IntuneTermsAndConditions
    if($GAndTs){
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Terms and Conditions"
        foreach($GAndT in $GAndTs){
            Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text $GAndT.displayName
            $GAndT | Select-Object -Property id,createdDateTime,lastModifiedDateTime,displayName,title,version  | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Contents -Design LightListAccent2
            $DCPA = Get-DeviceManagement_TermsAndConditions_Assignments -termsAndConditionId $GAndT.id
            Invoke-PrintAssignmentDetail -Assignments $DCPA
        }
    }
    #endregion
    
    #region Document Device Configurations
    Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Device Configuration"
    $DCPs = Get-ConfigurationProfileBeta
    foreach($DCP in $DCPs){
        write-Log "Device Compliance Policy: $($DCP.displayName)"
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text $DCP.displayName
        $ht2 = @{}
        $DCP.psobject.properties | ForEach-Object { 
            $ht2[(Format-MsGraphData $($_.Name))] = if((Format-MsGraphData "$($_.Value)").Length -gt $MaxStringLengthSettings){
                    "$((Format-MsGraphData "$($_.Value)").substring(0, $MaxStringLengthSettings))..."
                } else {
                    "$((Format-MsGraphData "$($_.Value)")) "
                }
        }
        ($ht2.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2
        $id = $DCP.id
        $DCPA = Get-IntuneDeviceConfigurationPolicyAssignment -deviceConfigurationId $id
        Invoke-PrintAssignmentDetail -Assignments $DCPA
    }
    $ADMXPolicies = Get-ADMXBasedConfigurationProfile
    foreach($ADMXPolicy in $ADMXPolicies){
        write-Log "Device Configuration (ADMX): $($ADMXPolicy.DisplayName)"
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text $ADMXPolicy.DisplayName
        $ADMXPolicy.Settings | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2

        $DCPA = Get-ADMXBasedConfigurationProfile_Assignment -ADMXBasedConfigurationProfileId $ADMXPolicy.Id
        Invoke-PrintAssignmentDetail -Assignments $DCPA
    }
    #endregion
    #region Device Management Scripts (PowerShell)
    Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Device Management Scripts"
    $PSScripts = Get-DeviceManagementScript
    foreach($PSScript in $PSScripts){
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text $PSScript.displayName
        $ht2 = @{}
        $PSScript.psobject.properties | ForEach-Object { 
            if($_.Name -ne "scriptContent"){
                $ht2[(Format-MsGraphData $($_.Name))] = "$($_.Value)"
            }
        }
        ($ht2.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2
        $DCPA = Get-DeviceManagementScript_Assignment -DeviceManagementScriptId $ht2.id
        Invoke-PrintAssignmentDetail -Assignments $DCPA
        
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading3 -Text "Script"
        $PSScript.scriptContent | Add-WordText -FilePath $FullDocumentationPath -Size 10 -Italic -FontFamily "Courier New"
    }
    #endregion
    #region AutoPilot Configuration
    Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "AutoPilot Configuration"
    $AutoPilotConfigs = Get-WindowsAutopilotConfig
    foreach($APC in $AutoPilotConfigs){
        write-Log "AutoPilot Config: $($APC.displayName)"
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text $APC.displayName
        $ht2 = @{}
        $APC.psobject.properties | ForEach-Object { 
            $ht2[(Format-MsGraphData $($_.Name))] = if((Format-MsGraphData "$($_.Value)").Length -gt $MaxStringLengthSettings){
                    "$((Format-MsGraphData "$($_.Value)").substring(0, $MaxStringLengthSettings))..."
                } else {
                    "$((Format-MsGraphData "$($_.Value)")) "
                }
        }
        ($ht2.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2
    
    }
    #endregion

    #region Enrollment Configuration
    Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Enrollment Configuration"
    $EnrollmentStatusPage = Get-EnrollmentStatusPage

    foreach($ESP in $EnrollmentStatusPage){
        write-Log "Enrollment Status Page Config: $($ESP.displayName)"
        $ESPtype = $ESP.'@odata.type'
        switch($ESPtype){
            "#microsoft.graph.windows10EnrollmentCompletionPageConfiguration" { $ESPtype = "ESP" }
            "#microsoft.graph.deviceEnrollmentLimitConfiguration" { $ESPtype = "Enrollment Limit" }
            "#microsoft.graph.deviceEnrollmentPlatformRestrictionsConfiguration" { $ESPtype = "Platform Restrictions" }
            "#microsoft.graph.deviceEnrollmentWindowsHelloForBusinessConfiguration" { $ESPtype = "Windows Hello for Business" }
        }
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text "$($ESPtype) - $($ESP.displayName)"
        
        $ht2 = @{}
        $ESP.psobject.properties | ForEach-Object { 
            $ht2[(Format-MsGraphData $($_.Name))] = if((Format-MsGraphData "$($_.Value)").Length -gt $MaxStringLengthSettings){
                    "$((Format-MsGraphData "$($_.Value)").substring(0, $MaxStringLengthSettings))..."
                } else {
                    "$((Format-MsGraphData "$($_.Value)")) "
                }
        }
        ($ht2.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2
        $DCPA = Get-DeviceManagement_DeviceEnrollmentConfigurations_Assignments -deviceEnrollmentConfigurationId $ESP.id
        Invoke-PrintAssignmentDetail -Assignments $DCPA
    }
    #endregion

    #region Apple Push Certificate
    Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Apple Configurations"
    Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text "Apple Push Certificate"
    $APNs = Get-IntuneApplePushNotificationCertificate

    foreach($APN in $APNs){
        write-Log "AutoPilot Config: $($APN.appleIdentifier)"
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading3 -Text $APN.appleIdentifier
        
        $ht2 = @{}
        $APN.psobject.properties | ForEach-Object { 
            $ht2[(Format-MsGraphData $($_.Name))] = if((Format-MsGraphData "$($_.Value)").Length -gt $MaxStringLengthSettings){
                    "$((Format-MsGraphData "$($_.Value)").substring(0, $MaxStringLengthSettings))..."
                } else {
                    "$((Format-MsGraphData "$($_.Value)")) "
                }
        }
        ($ht2.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2
    
    }
    Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text "Apple VPP Tokens"
    $VPPs = Get-IntuneVppToken

    foreach($VPP in $VPPs){
        write-Log "VPP Config: $($VPP.appleId)"
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading3 -Text $VPP.appleId
        
        $ht2 = @{}
        $VPP.psobject.properties | ForEach-Object { 
            $ht2[(Format-MsGraphData $($_.Name))] = if((Format-MsGraphData "$($_.Value)").Length -gt $MaxStringLengthSettings){
                    "$((Format-MsGraphData "$($_.Value)").substring(0, $MaxStringLengthSettings))..."
                } else {
                    "$((Format-MsGraphData "$($_.Value)")) "
                }
        }
        ($ht2.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2
    
    }
    #endregion

    #region Device Categories
    Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Device Categories"
    $Cats = Get-IntuneDeviceCategory
    write-Log "Device Categories: $($Cats.count)"
    foreach($Cat in $Cats){
    Add-WordText -FilePath $FullDocumentationPath -Text (" - " + $Cat.displayName) -Size 10
    }

    #endregion

    #region Exchange Connection
    Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Exchange Connector"
    $exch = Get-IntuneExchangeConnector
    write-Log "Exchange Connector: $($exch.serverName)"
    $ht2 = @{}
    $exch.psobject.properties | ForEach-Object { 
        $ht2[(Format-MsGraphData $($_.Name))] = if((Format-MsGraphData "$($_.Value)").Length -gt $MaxStringLengthSettings){
                "$((Format-MsGraphData "$($_.Value)").substring(0, $MaxStringLengthSettings))..."
            } else {
                "$((Format-MsGraphData "$($_.Value)")) "
            }
    }
    ($ht2.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2

    #endregion

    #region Partner Configuration
    Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Partner Configuration"
    $partnerConfigs = Get-IntuneDeviceManagementPartner
    foreach($partnerConfig in $partnerConfigs){
        write-Log "Partner Config: $($partnerConfig.displayName)"
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text $partnerConfig.displayName
        $ht2 = @{}
        $partnerConfig.psobject.properties | ForEach-Object { 
            $ht2[(Format-MsGraphData $($_.Name))] = if((Format-MsGraphData "$($_.Value)").Length -gt $MaxStringLengthSettings){
                    "$((Format-MsGraphData "$($_.Value)").substring(0, $MaxStringLengthSettings))..."
                } else {
                    "$((Format-MsGraphData "$($_.Value)")) "
                }
        }
        ($ht2.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2
    
    }
    #endregion
    #endregion
    #region Finishing
    ########################################################
    Write-Log "Press Ctrl + A and then F9 to Update the table of contents and other dynamic fields in the Word document."
    Write-Log "End Script $Scriptname"
    #endregion
}
# SIG # Begin signature block
# MIIZwgYJKoZIhvcNAQcCoIIZszCCGa8CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUhcPvPnhgLo0edJVpFlgaRwLp
# kDugghUDMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggWtMIIElaADAgECAhAEP0tn9l4Sf9gdog2gb/SWMA0GCSqGSIb3DQEBBQUAMGUx
# CzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3
# dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEVWIENvZGUgU2lnbmlu
# ZyBDQTAeFw0yMDAzMDYwMDAwMDBaFw0yMzAzMTUxMjAwMDBaMIHOMRMwEQYLKwYB
# BAGCNzwCAQMTAkNIMRowGAYLKwYBBAGCNzwCAQITCVNvbG90aHVybjEdMBsGA1UE
# DwwUUHJpdmF0ZSBPcmdhbml6YXRpb24xGDAWBgNVBAUTD0NIRS0zMTQuNjM5LjUy
# MzELMAkGA1UEBhMCQ0gxEjAQBgNVBAgTCVNvbG90aHVybjERMA8GA1UEBwwIRMOk
# bmlrZW4xFjAUBgNVBAoTDWJhc2VWSVNJT04gQUcxFjAUBgNVBAMTDWJhc2VWSVNJ
# T04gQUcwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCn0xZCT8yT681H
# ZVY8gtUlURKywy8Nfq8uiv/jJJU+/Tf4HHXXJzHo96ZFo/WOWMD3WMWRYRnpj95P
# ZbfLaF+ki/PURRhp9/oT/p5O3zTv4Jqnig7AOeIL5dt9W5Uij9rDOEZhmFpVT08K
# CKhMNMMu7MhBs+uHBlyQ70j5H2IjBjePtEDYcakbv1RNDK5hU+k2UqKZEQSaqt2+
# riewxS2R4RUvZJ5nRraf4pNYqDdem2H0vJ17zHsG+ZB0YFLk/P3i6r4tJEAksYAU
# kuJsFDt0Yz9xM2qmG2Rr4iw7AUTfE5Gx0NNWD/fMWFP/2sD3VkHA8Mz8PAokDfFz
# 21OqYrXPAgMBAAGjggHtMIIB6TAfBgNVHSMEGDAWgBStaQZw/IAbFrOpGJRrlAKG
# XvcnjDAdBgNVHQ4EFgQURdlk/2RkqKDvZs8sol0UhzmJTCowNwYDVR0RBDAwLqAs
# BggrBgEFBQcIA6AgMB4MHENILVNPTE9USFVSTi1DSEUtMzE0LjYzOS41MjMwDgYD
# VR0PAQH/BAQDAgeAMBMGA1UdJQQMMAoGCCsGAQUFBwMDMHMGA1UdHwRsMGowM6Ax
# oC+GLWh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9FVkNvZGVTaWduaW5nLWcxLmNy
# bDAzoDGgL4YtaHR0cDovL2NybDQuZGlnaWNlcnQuY29tL0VWQ29kZVNpZ25pbmct
# ZzEuY3JsMEsGA1UdIAREMEIwNwYJYIZIAYb9bAMCMCowKAYIKwYBBQUHAgEWHGh0
# dHBzOi8vd3d3LmRpZ2ljZXJ0LmNvbS9DUFMwBwYFZ4EMAQMweQYIKwYBBQUHAQEE
# bTBrMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5kaWdpY2VydC5jb20wQwYIKwYB
# BQUHMAKGN2h0dHA6Ly9jYWNlcnRzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEVWQ29k
# ZVNpZ25pbmdDQS5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQUFAAOCAQEA
# GYerL9YA8gW4cx7nWEaDFpN2XnaY4+90Nl8gaj6aeQj6kwIfjWLWAzByDdVNvxSk
# rwXdfo3dkG5DNNI3wPR2SE2iyImDF6zXTThccBqkwE1x1Tb5qfhaA48jf18f8Jbv
# VgvtbZWXph1b+ALyD2911b34Qt6cYmolg19vkmWXZUADRjA11S3VHhhH4GLKeHoE
# 23jSSs69tQPNC1jdS+Rx6yO/Ya14UrDwOrJo1qSn2xTilf9s77mSxRJCpL8Cd1PU
# HPvugUFHLw9nqOQAMUb7cHdDUREs7Brvfcyo0qRx7lyKjIM1d0wGtiBz+8kQJcSC
# dK9S8HGSD3y4R1N++Y8gYTCCBrUwggWdoAMCAQICEA3Q4zdKyVvb+mtDSypI7AYw
# DQYJKoZIhvcNAQEFBQAwbDELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0
# IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0LmNvbTErMCkGA1UEAxMiRGlnaUNl
# cnQgSGlnaCBBc3N1cmFuY2UgRVYgUm9vdCBDQTAeFw0xMjA0MTgxMjAwMDBaFw0y
# NzA0MTgxMjAwMDBaMGUxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJ
# bmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0
# IEVWIENvZGUgU2lnbmluZyBDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoC
# ggEBALkGdBxdtCCqqSGoKkJGqyUgFyXLIo+QoqAxa4MFda+yDnwSSXtqhmSED4Pc
# ZLmxbhYFPhyVuefniG24YoGQedTd9eKW+cO1iCNXShrPcSnpCACPtZjjpzL9rC64
# 9JNT9Ao5Q5Gv1Wvo1J9GvY49q+L5K9TqAEBmJLfof7REdY14mq4xwTfPTh9b+EVK
# 1z/CyZIGZL7eBoqv0OiKsfAsiABvC9yFp0zLBr/WLioybilxr44i8w/Q2JhILagI
# y7aLI8Jj4LZz6299Jk+L9zQ9N4YMt3gn9MKG20NrWvg9PfTosGJWxufteKH7/Xpy
# TzJlxHzDxHegBDIy7Y8/r4bdftECAwEAAaOCA1gwggNUMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoGCCsGAQUFBwMDMH8GCCsG
# AQUFBwEBBHMwcTAkBggrBgEFBQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29t
# MEkGCCsGAQUFBzAChj1odHRwOi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNl
# cnRIaWdoQXNzdXJhbmNlRVZSb290Q0EuY3J0MIGPBgNVHR8EgYcwgYQwQKA+oDyG
# Omh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydEhpZ2hBc3N1cmFuY2VF
# VlJvb3RDQS5jcmwwQKA+oDyGOmh0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydEhpZ2hBc3N1cmFuY2VFVlJvb3RDQS5jcmwwggHEBgNVHSAEggG7MIIBtzCC
# AbMGCWCGSAGG/WwDAjCCAaQwOgYIKwYBBQUHAgEWLmh0dHA6Ly93d3cuZGlnaWNl
# cnQuY29tL3NzbC1jcHMtcmVwb3NpdG9yeS5odG0wggFkBggrBgEFBQcCAjCCAVYe
# ggFSAEEAbgB5ACAAdQBzAGUAIABvAGYAIAB0AGgAaQBzACAAQwBlAHIAdABpAGYA
# aQBjAGEAdABlACAAYwBvAG4AcwB0AGkAdAB1AHQAZQBzACAAYQBjAGMAZQBwAHQA
# YQBuAGMAZQAgAG8AZgAgAHQAaABlACAARABpAGcAaQBDAGUAcgB0ACAAQwBQAC8A
# QwBQAFMAIABhAG4AZAAgAHQAaABlACAAUgBlAGwAeQBpAG4AZwAgAFAAYQByAHQA
# eQAgAEEAZwByAGUAZQBtAGUAbgB0ACAAdwBoAGkAYwBoACAAbABpAG0AaQB0ACAA
# bABpAGEAYgBpAGwAaQB0AHkAIABhAG4AZAAgAGEAcgBlACAAaQBuAGMAbwByAHAA
# bwByAGEAdABlAGQAIABoAGUAcgBlAGkAbgAgAGIAeQAgAHIAZQBmAGUAcgBlAG4A
# YwBlAC4wHQYDVR0OBBYEFK1pBnD8gBsWs6kYlGuUAoZe9yeMMB8GA1UdIwQYMBaA
# FLE+w2kD+L9HAdSYJhoIAu9jZCvDMA0GCSqGSIb3DQEBBQUAA4IBAQCeW5Y6LhKI
# rKsBbaSfdeQBh6OlMte8uql+o9YUF/fCE2t8c48rauUPJllosI4lm2zv+myTkgjB
# Tc9FnpxG1h50oZsUo/oBL0qxAeFyQEgRE2i5Np2RS9fCORIQwcTcu2IUFCphXU84
# fGYfxhv/rb5Pf5Rbc0MAD01zt1HPDvZ3wFvNNIzZYxOqDmER1vKOJ/y0e7i5ESCR
# hnjqDtQo/yrVJDjoN7LslrufvEoWUOFev1F9I6Ayx8GUnnrJwCaizCWHoBJ+dJ8t
# jbHI54S+udHp3rtqTohzceEiOMskh+lzflGy/5jrTn4v4MoO+rNe0boFQqhIn4P2
# P8TKqN9ooFBhMYIEKTCCBCUCAQEweTBlMQswCQYDVQQGEwJVUzEVMBMGA1UEChMM
# RGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQD
# ExtEaWdpQ2VydCBFViBDb2RlIFNpZ25pbmcgQ0ECEAQ/S2f2XhJ/2B2iDaBv9JYw
# CQYFKw4DAhoFAKB4MBgGCisGAQQBgjcCAQwxCjAIoAKAAKECgAAwGQYJKoZIhvcN
# AQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcCARUw
# IwYJKoZIhvcNAQkEMRYEFPxcHR49G23bvdzsgEnJD1ZzidbFMA0GCSqGSIb3DQEB
# AQUABIIBABws0r7Zv8uPMl9eBcsnnutqpLM5MZI0igknf/ixzMMHbA4bp1wWNLSG
# xIDjNid0phaFN8zSJpqtV2u1c8QYIgXiYohflDI5ecglccU4deZufd4eBhwv8nIh
# SVoJniNpYAgfrg+lpyhamoJgHOD3S+fvGsESHL28oZar+p3JNQYaowI1wr2hk8HW
# 9wmwUh5nsfCIT9NVX3oe0LgzTWbWU/3khT69YcqffWNibl1dzVExeWs52V/oV4EW
# mgNkeGti3Ba0wTh9r80KhZb6DUffsiF06ts1L3vIOQ+Y7x9VT/U6pmE0QnZ6Udp2
# 3Vd3SkA1q3QlAPGojXMg/NhZAGE13/ChggILMIICBwYJKoZIhvcNAQkGMYIB+DCC
# AfQCAQEwcjBeMQswCQYDVQQGEwJVUzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9y
# YXRpb24xMDAuBgNVBAMTJ1N5bWFudGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMg
# Q0EgLSBHMgIQDs/0OMj+vzVuBNhqmBsaUDAJBgUrDgMCGgUAoF0wGAYJKoZIhvcN
# AQkDMQsGCSqGSIb3DQEHATAcBgkqhkiG9w0BCQUxDxcNMjAwMzI2MjEwNzE0WjAj
# BgkqhkiG9w0BCQQxFgQUqjIkDcYe1WvYv6iXzRR0wKZw4oAwDQYJKoZIhvcNAQEB
# BQAEggEAYu1kNpgIHrtvU7/S3ivOEzXj84lVaBw1eImCBBlrB1dX8nJsvhsgoG1b
# KnF9THEfZEdajppPF7a8nsW0w/mSPBc1LElWoIA7iqA5qAD3oirXUAEpeJMxRf/M
# ntwWifa93iUbUJ0/P0Qj4c2Oou9U5C+G4ZSHf0jQq+vvn+WNXtYDe4+gryQjkRbs
# TS1WSKmT5EDr16f+RrLnxg6gMDpjn7s2ANW8pxR7wtnP9sCd+N/01bP8q+//6dI5
# MXuLcPJPrOIbhET/PBAoxn6Pp+ZP6TKTxpoQz79Wx8wSZGRWQ7X6mW7UcsQJWKKG
# TPrRdWr8Pfo1H54C2qLAZDb5soJ1fw==
# SIG # End signature block
