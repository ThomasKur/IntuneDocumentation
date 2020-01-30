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
        $id = $MAM.id
        $MAMA = Get-DeviceAppManagement_AndroidManagedAppProtections_Assignments -androidManagedAppProtectionId $id -androidManagedAppProtectionODataType microsoft.graph.androidManagedAppProtection
        $MAMA = Get-DeviceAppManagement_IosManagedAppProtections_Assignments -iosManagedAppProtectionId $id -iosManagedAppProtectionODataType microsoft.graph.iosManagedAppProtection
        if($MAMA){
            write-Log "Getting MAM Policy assignment..."
            Add-WordText -FilePath $FullDocumentationPath -Heading Heading3 -Text "Assignments"
            if($APPA.count -gt 1){
                $Assignments = @()
                foreach($group in $MAMA){
                    $Assignments += (Get-AADGroup -groupid $group.target.groupId).displayName
                }
                $Assignments | Add-WordText -FilePath $FullDocumentationPath -Size 12
            } else {
                (Get-AADGroup -groupid $MAMA.target.groupId).displayName | Add-WordText -FilePath $FullDocumentationPath -Size 12
            }
        }
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
        if($MAMA){
            write-Log "Getting Mobile Application Configuration assignment..."
            Add-WordText -FilePath $FullDocumentationPath -Heading Heading3 -Text "Assignments"
            if($APPA.count -gt 1){
                $Assignments = @()
                foreach($group in $MAMA){
                    $Assignments += (Get-AADGroup -groupid $group.target.groupId).displayName
                }
                $Assignments | Add-WordText -FilePath $FullDocumentationPath -Size 12
            } else {
                (Get-AADGroup -groupid $MAMA.target.groupId).displayName | Add-WordText -FilePath $FullDocumentationPath -Size 12
            }
        }
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
        if($DCPA){
            write-Log "Getting Compliance Policy assignment..."
            Add-WordText -FilePath $FullDocumentationPath -Heading Heading3 -Text "Assignments"
            if($DCPA.count -gt 1){
                $Assignments = @()
                foreach($group in $DCPA){
                    $Assignments += (Get-AADGroup -groupid $group.target.groupId).displayName
                }
                $Assignments | Add-WordText -FilePath $FullDocumentationPath -Size 12
            } else {
                (Get-AADGroup -groupid $DCPA.target.groupId).displayName | Add-WordText -FilePath $FullDocumentationPath -Size 12
            }
        }
    }
    #endregion
    #region Document T&C
    write-Log "Terms and Conditions"
    $GAndT = Get-IntuneTermsAndConditions
    if($GAndT){
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Terms and Conditions"
        $GAndT | ForEach-Object { $_ | Select-Object -Property id,createdDateTime,lastModifiedDateTime,displayName,title,version } | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Contents -Design LightListAccent2
    }
    #endregion
    #region Document EnrollmentRestrictions
    Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Device Enrollment Restrictions"
    $Restrictions = Get-IntuneDeviceEnrollmentConfiguration
    foreach($restriction in $Restrictions){
        $ht2 = @{}
        $restriction.psobject.properties | ForEach-Object { if($_.Name -ne "@odata.type"){$ht2[(Format-MsGraphData $($_.Name))] = ((Format-MsGraphData "$($_.Value) "))} }
        ($ht2.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2
    }
    #endregion
    #region Document Device Configurations
    Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Device Configuration"
    $DCPs = Get-IntuneDeviceConfigurationPolicy
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
        if($DCPA){
            write-Log "Getting Compliance Policy assignment..."
            Add-WordText -FilePath $FullDocumentationPath -Heading Heading3 -Text "Assignments"
            if($DCPA.count -gt 1){
                $Assignments = @()
                foreach($group in $DCPA){
                    if($null -ne $group.target.groupId){
                        $Assignments += (Get-AADGroup -groupid $group.target.groupId).displayName
                    } else {
                        $Assignments += "$(($group.target.'@odata.type' -replace "#microsoft.graph.",''))"
                    }
                    
                }
                $Assignments | Add-WordText -FilePath $FullDocumentationPath -Size 12
            } else {
                if($null -ne $DCPA.target.groupId){
                    (Get-AADGroup -groupid $DCPA.target.groupId).displayName | Add-WordText -FilePath $FullDocumentationPath  -Size 12
                } else {
                    "$(($DCPA.target.'@odata.type' -replace "#microsoft.graph.",''))" | Add-WordText -FilePath $FullDocumentationPath  -Size 12
                }
                
            }
        }
    }
    $ADMXPolicies = Get-ADMXBasedConfigurationProfile
    foreach($ADMXPolicy in $ADMXPolicies){
        write-Log "Device Configuration (ADMX): $($ADMXPolicy.DisplayName)"
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text $ADMXPolicy.DisplayName
        $ADMXPolicy.Settings | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2
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

    #region Enrollment Status Page Configuration
    Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Enrollment Status Pages"
    $EnrollmentStatusPage = Get-EnrollmentStatusPage

    foreach($ESP in $EnrollmentStatusPage){
        write-Log "Enrollment Status Page Config: $($ESP.displayName)"
        $ESPtype = $ESP.type
        switch($ESPtype){
            "win10EnrollmentCompletionPageConfiguration" { $ESPtype = "ESP" }
            "deviceEnrollmentLimitConfiguration" { $ESPtype = "Enrollment Limit" }
            "deviceEnrollmentPlatformRestrictionsConfiguration" { $ESPtype = "Platform Restrictions" }
            "deviceEnrollmentwinHelloForBusinessConfiguration" { $ESPtype = "Windows Hello for Business" }
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


    #General Settings
    # On Prem Cond Access Get-IntuneConditionalAccessSetting
    # MAM Settings



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