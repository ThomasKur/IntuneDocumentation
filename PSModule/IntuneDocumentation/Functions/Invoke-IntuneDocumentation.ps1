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
    #$DebugPreference = "Continue"
    $ScriptName = "DocumentIntune"
    

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
            $Intune_App = New-Object -Type PSObject
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
    if($null -ne $Intune_Apps){
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Applications"
        $Intune_Apps | Sort-Object Publisher,DisplayName | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Contents -Design LightListAccent2
    }
    #endregion
    #region Document App protection policies
    $MAMs = Get-IntuneAppProtectionPolicy
    if($null -ne $MAMs){
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "App Protection Policies"
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
    }
    #endregion
    #region Document App configuration policies
    $MACs = Get-DeviceAppManagement_MobileAppConfigurations
    if($null -ne $MACs){
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "App Configuration Policies"
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
    }
    #endregion
    #region Document Compliance Policies
    $DCPs = Get-IntuneDeviceCompliancePolicy
    if($null -ne $DCPs){
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Compliance Policies"
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
    }
    #endregion
    #region Document T&C
    write-Log "Terms and Conditions"
    $GAndTs = Get-IntuneTermsAndConditions
    if($null -ne $GAndTs){
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Terms and Conditions"
        foreach($GAndT in $GAndTs){
            Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text $GAndT.displayName
            $GAndT | Select-Object -Property id,@{Name="Created at";Expression={$_.createdDateTime}},@{Name="Modified at";Expression={$_.lastModifiedDateTime}},@{Name="Displayname";Expression={$_.displayName}},@{Name="Title";Expression={$_.title}},@{Name="Version";Expression={$_.version}}  | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Contents -Design LightListAccent2
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
        Invoke-PrintTable -Properties $DCP.psobject.properties -TypeName $DCP.'@odata.type'
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
    $AutoPilotConfigs = Get-WindowsAutopilotConfig
    if($null -ne $AutoPilotConfigs){
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "AutoPilot Configuration"
        
        foreach($APC in $AutoPilotConfigs){
            write-Log "AutoPilot Config: $($APC.displayName)"
            Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text $APC.displayName
            Invoke-PrintTable -Properties $APC.psobject.properties  -TypeName $APC.'@odata.type'
        }
    }
    #endregion

    #region Enrollment Configuration
    $EnrollmentStatusPage = Get-EnrollmentStatusPage
    if($null -ne $EnrollmentStatusPage){
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Enrollment Configuration"
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
            
            Invoke-PrintTable -Properties $ESP.psobject.properties -TypeName $ESP.'@odata.type'
            $DCPA = Get-DeviceManagement_DeviceEnrollmentConfigurations_Assignments -deviceEnrollmentConfigurationId $ESP.id
            Invoke-PrintAssignmentDetail -Assignments $DCPA
        }
    }
    #endregion

    #region Apple Push Certificate
    $VPPs = Get-IntuneVppToken
    $APNs = Get-IntuneApplePushNotificationCertificate
    Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Apple Configurations"
    Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text "Apple Push Certificate"
    foreach($APN in $APNs){
        write-Log "AutoPilot Config: $($APN.appleIdentifier)"
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading3 -Text $APN.appleIdentifier
        Invoke-PrintTable -Properties $APN.psobject.properties -TypeName "applePushNotificationCertificate"
    }
    Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text "Apple VPP Tokens"
    foreach($VPP in $VPPs){
        write-Log "VPP Config: $($VPP.appleId)"
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading3 -Text $VPP.appleId
        Invoke-PrintTable -Properties $VPP.psobject.properties -TypeName "appleVPPCertificate"
    }
    #endregion

    #region Device Categories
    $Cats = Get-IntuneDeviceCategory
    if($null -ne $Cats){
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Device Categories"
        write-Log "Device Categories: $($Cats.count)"
        foreach($Cat in $Cats){
            Add-WordText -FilePath $FullDocumentationPath -Text (" - " + $Cat.displayName) -Size 10
        }
    }
    #endregion

    #region Exchange Connection
    $exch = Get-IntuneExchangeConnector
    if($null -ne $exch){
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Exchange Connector"
        write-Log "Exchange Connector: $($exch.serverName)"
        Invoke-PrintTable -Properties $exch.psobject.properties -TypeName "ExchangeConnector"
    }
    #endregion

    #region Partner Configuration
    $partnerConfigs = Get-IntuneDeviceManagementPartner
    if($null -ne $partnerConfigs){
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Partner Connections"
        
        foreach($partnerConfig in $partnerConfigs){
            write-Log "Partner Config: $($partnerConfig.displayName)"
            Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text $partnerConfig.displayName
            Invoke-PrintTable -Properties $partnerConfig.psobject.properties -TypeName "PartnerConfiguration"
        }
    }
    #endregion
    #endregion
    #region Finishing
    ########################################################
    Write-Log "Press Ctrl + A and then F9 to Update the table of contents and other dynamic fields in the Word document."
    Write-Log "End Script $Scriptname"
    #endregion
}