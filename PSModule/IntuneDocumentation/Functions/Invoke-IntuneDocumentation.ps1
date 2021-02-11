Function Invoke-IntuneDocumentation(){
    <#
    .DESCRIPTION
    This Script documents an Intune Tenant with almost all settings, which are available over the Graph API.
    NOTE: This no longer does Conditional Access
    The Script is using the PSWord and Microsoft.Graph.Intune Module. Therefore you have to install them first.



    .PARAMETER FullDocumentationPath
        Path including filename where the documentation should be created. The filename has to end with .docx.
        Note:
        If there is already a file present, the documentation will be added at the end of the existing document.

    .PARAMETER UseTranslationBeta
        When using this parameter the API names will be translated to the labels used in the Intune Portal. 
        Note:
        These Translations need to be created manually, only a few are translated yet. If you are willing 
        to support this project. You can do this by translating the json files which are mentioned to you when 
        you generate the documentation in your tenant. 

    .PARAMETER ClientSecret
        If the client secret is set, app-only authentication will be performed using the client ID specified by 
        the AppId environment parameter.

    .PARAMETER ClientId
        The client id of the application registration with the required permissions.

    .PARAMETER Tenant
        Name of your tenant in form of "kurcontoso.onmicrosoft.com" or the TenantId
    

    .EXAMPLE Interactive
    Invoke-IntuneDocumentation -FullDocumentationPath c:\temp\IntuneDoc.docx

    .EXAMPLE Non interactive
    Invoke-IntuneDocumentation -FullDocumentationPath c:\temp\IntuneDoc.docx  -ClientId d5cf6364-82f7-4024-9ac1-73a9fd2a6ec3 -ClientSecret S03AESdMlhLQIPYYw/cYtLkGkQS0H49jXh02AS6Ek0U= -Tenant d873f16a-73a2-4ccf-9d36-67b8243ab99a

    .NOTES
    Author: Thomas Kurth/baseVISION
    Co-Author: jflieben
    Co-Author: Robin Dadswell
    Date:   26.7.2020

    History
        See Release Notes in Github.

    #>
    [CmdletBinding()]
    Param(
        [ValidateScript({
            if($_ -notmatch "(\.(docx|md)$)"){
                throw "The file specified in the path argument must be of type docx or md"
            }
            return $true 
        })]
        [Parameter(ParameterSetName = "NonInteractive")]
        [Parameter(ParameterSetName = "Default")]
        [System.IO.FileInfo]$FullDocumentationPath = ".\IntuneDocumentation.docx",

        [Parameter(ParameterSetName = "Default")]
        [Parameter(ParameterSetName = "NonInteractive")]
        [switch]$UseTranslationBeta,

        [Parameter(Mandatory = $true, ParameterSetName = "NonInteractive")]
        [String]$ClientId,

        [Parameter(Mandatory = $true, ParameterSetName = "NonInteractive")]
        [String]$ClientSecret,

        [Parameter(Mandatory = $true, ParameterSetName = "NonInteractive")]
        [String]$Tenant

    )
    ## Manual Variable Definition
    ########################################################
    #$DebugPreference = "Continue"
    $ScriptName = "DocumentIntune"
    $Script:NewTranslationFiles = @()
    if($UseTranslationBeta){
        $Script:UseTranslation = $true
    } else {
        $Script:UseTranslation = $false
    }
    $format = if($FullDocumentationPath -match "(\.md)"){ "md" } else { "docx" }

    #region Initialization
    ########################################################
    Write-Log "Start Script $Scriptname"
    #region Authentication
    if($PsCmdlet.ParameterSetName -eq "NonInteractive"){
        $authority = "https://login.windows.net/$Tenant"
        Update-MSGraphEnvironment -AppId $ClientId -Quiet
        Update-MSGraphEnvironment -AuthUrl $authority -Quiet
        Connect-MSGraph -ClientSecret $ClientSecret -Quiet
    } else { 
        Connect-MSGraph
    }
    #endregion
    #region Main Script
    ########################################################
    #region Save Path

    #endregion
    #region CopyTemplate
    if((Test-Path -Path $FullDocumentationPath)){
        Write-Log "File already exists, does not use built-in template." -Type Warn
    } else {
        Copy-Item "$PSScriptRoot\..\Data\Template.$format" -Destination $FullDocumentationPath
        Update-Text -format $format -SearchText "DATE" -NewText (Get-Date -Format "HH:mm dd.MM.yyyy")
        Update-Text -format $format -SearchText "SYSTEM" -NewText "Intune"
        try{
            $org = Invoke-MSGraphRequest -Url /organization
            Update-Text -format $format -SearchText "TENANT" -NewText $org.value.displayName
        } catch{
            Update-Text -format $format -SearchText "TENANT" -NewText ""
        }
        
    }
    #endregion
    #region Document Apps
    $Intune_Apps = @()
    $AppGroups = @()
    Get-MobileAppsBeta | ForEach-Object  {
        $App_Assignment = Get-IntuneMobileAppAssignment -mobileAppId $_.id
        if($App_Assignment){
            $Intune_App = New-Object -Type PSObject
            $Intune_App | Add-Member Noteproperty "Publisher" $_.publisher
            $Intune_App | Add-Member Noteproperty "DisplayName" $_.displayName
            $Intune_App | Add-Member Noteproperty "Type" (Format-MsGraphData $_.'@odata.type')
            $Assignments = @()
            $newline = if ($format -eq 'md') { '<br>' } else { "`n" }
            foreach($Assignment in $App_Assignment) {
                if($null -ne $Assignment.target.groupId){
                    $AppGroups += $Assignment.target.groupId
                    $Assignments += "$((Get-AADGroup -groupid $Assignment.target.groupId).displayName)$newline - Intent:$($Assignment.intent)"
                } else {
                    $Assignments += "$(($Assignment.target.'@odata.type' -replace "#microsoft.graph.",''))$newline - Intent:$($Assignment.intent)"
                }
            }
            $Intune_App | Add-Member Noteproperty "Assignments" ($Assignments -join $newline)
            $Intune_Apps += $Intune_App
        }
    } 
    if($null -ne $Intune_Apps){
        Add-Header -level 1 -format $format -Text "Applications"
        Add-Table -InputObject ($Intune_Apps | Sort-Object Publisher,DisplayName) -format $format -AutoFitStyle Contents
        if($null -ne $AppGroups){
            Add-Header -level 1 -format $format -Text "Groups used to assign apps"
            Invoke-PrintGroup -GroupIds $AppGroups
        }
    }

    #endregion
    #region Document App protection policies
    $MAMs = Get-IntuneAppProtectionPolicy | Where-Object { $_.'@odata.type' -notlike "*AppConfiguration" }

    if($null -ne $MAMs){
        Add-Header -level 1 -format $format -Text "App Protection Policies"
        foreach($MAM in $MAMs){
            write-Log "App Protection Policy: $($MAM.displayName)"
            Add-Header -level 2 -format $format -Text $MAM.displayName
            if($MAM.'@odata.type' -eq "#microsoft.graph.mdmWindowsInformationProtectionPolicy"){
                $MAM.protectedApps = $MAM.protectedApps.displayName -join ", "
            }
            Invoke-PrintTable -Properties $MAM.psobject.properties -TypeName $MAM.'@odata.type'
            if($MAM.'@odata.type' -eq "#microsoft.graph.iosManagedAppProtection"){
                $MAMA = Get-MAM_iOS_Assignment -policyId $MAM.id
            }
            if($MAM.'@odata.type' -eq "#microsoft.graph.androidManagedAppProtection"){
                $MAMA = Get-MAM_Android_Assignment -policyId $MAM.id
            }
            if($MAM.'@odata.type' -eq "#microsoft.graph.mdmWindowsInformationProtectionPolicy"){
                $MAMA = Get-MAM_Windows_Assignment -policyId $MAM.id
            }
            Invoke-PrintAssignmentDetail -Assignments $MAMA
        }
    }
    #endregion
    #region Document App configuration policies
    $MACs = Get-IntuneAppProtectionPolicy | Where-Object { $_.'@odata.type' -like "*AppConfiguration" }
    if($null -ne $MACs){
        Add-Header -level 1 -format $format -Text "App Configuration Policies"
        foreach($MAC in $MACs){
            write-Log "App Configuration Policy: $($MAC.displayName)"
            Add-Header -level 2 -format $format -Text $MAC.displayName
            Invoke-PrintTable -Properties $MAC.psobject.properties -TypeName $MAC.'@odata.type'
            $MACA = Get-ManagedAppConfig_Assignment -policyId $MAC.id
            Invoke-PrintAssignmentDetail -Assignments $MACA
        }
    }
    #endregion
    #region Document Compliance Policies
    $DCPs = Get-IntuneDeviceCompliancePolicy
    if($null -ne $DCPs){
        Add-Header -level 1 -format $format -Text "Compliance Policies"
        foreach($DCP in $DCPs){
            write-Log "Device Compliance Policy: $($DCP.displayName)"
            Add-Header -level 2 -format $format -Text $DCP.displayName
            if([String]::IsNullOrWhiteSpace($DCP.'@odata.type') -eq $false){
                Invoke-PrintTable -Properties $DCP.psobject.properties -TypeName $DCP.'@odata.type'
                $id = $DCP.id
                $DCPA = Get-IntuneDeviceCompliancePolicyAssignment -deviceCompliancePolicyId $id
                Invoke-PrintAssignmentDetail -Assignments $DCPA
            }
            
        }
    }
    #endregion
    #region Security Baselines
    $SBs = Get-SecBaselinesBeta
    if($null -ne $SBs){
        Add-Header -level 1 -format $format -Text "Security Baselines"
        foreach($SB in $SBs){
            write-Log "Security Baselines Policy: $($SB.displayName)"
            Add-Header -level 2 -format $format -Text $SB.Name
            # $SB.Settings | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2 
            Invoke-PrintTable -Properties $SB.Settings -TypeName $SB.'@odata.type'
            Invoke-PrintAssignmentDetail -Assignments $SB.Assignments
        }
    }
    #endregion
    #region Document T&C
    write-Log "Terms and Conditions"
    $GAndTs = Get-IntuneTermsAndConditions
    if($null -ne $GAndTs){
        Add-Header -level 1 -format $format -Text "Terms and Conditions"
        foreach($GAndT in $GAndTs){
            Add-Header -level 2 -format $format -Text $GAndT.displayName
            Add-Table -InputObject ($GAndT | Select-Object -Property id,@{Name="Created at";Expression={$_.createdDateTime}},@{Name="Modified at";Expression={$_.lastModifiedDateTime}},@{Name="Displayname";Expression={$_.displayName}},@{Name="Title";Expression={$_.title}},@{Name="Version";Expression={$_.version}}) -format $format -AutoFitStyle Contents
            $DCPA = Get-DeviceManagement_TermsAndConditions_Assignments -termsAndConditionId $GAndT.id
            Invoke-PrintAssignmentDetail -Assignments $DCPA
        }
    }
    #endregion
    
    #region Document Device Configurations
    Add-Header -level 1 -format $format -Text "Device Configuration"
    $DCPs = Get-ConfigurationProfileBeta
    foreach($DCP in $DCPs){
        write-Log "Device Compliance Policy: $($DCP.displayName)"
        Add-Header -level 2 -format $format -Text $DCP.displayName
        Invoke-PrintTable -Properties $DCP.psobject.properties -TypeName $DCP.'@odata.type'
        $id = $DCP.id
        $DCPA = Get-IntuneDeviceConfigurationPolicyAssignment -deviceConfigurationId $id
        Invoke-PrintAssignmentDetail -Assignments $DCPA
    }
    $ADMXPolicies = Get-ADMXBasedConfigurationProfile
    foreach($ADMXPolicy in $ADMXPolicies){
        write-Log "Device Configuration (ADMX): $($ADMXPolicy.DisplayName)"
        Add-Header -level 2 -format $format -Text $ADMXPolicy.DisplayName
        Add-Table -InputObject $ADMXPolicy.Settings -format $format

        $DCPA = Get-ADMXBasedConfigurationProfile_Assignment -ADMXBasedConfigurationProfileId $ADMXPolicy.Id
        Invoke-PrintAssignmentDetail -Assignments $DCPA
    }
    #endregion
    #region Device Management Scripts (PowerShell)
    Add-Header -level 1 -format $format -Text "Device Management Scripts"
    $PSScripts = Get-DeviceManagementScript
    foreach($PSScript in $PSScripts){
        Add-Header -level 2 -format $format -Text $PSScript.displayName
        $ht2 = @{}
        $PSScript.psobject.properties | ForEach-Object { 
            if($_.Name -ne "scriptContent"){
                $ht2[(Format-MsGraphData $($_.Name))] = "$($_.Value)"
            }
        }
        Add-Table -InputObject ($ht2.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) -format $format
        $DCPA = Get-DeviceManagementScript_Assignment -DeviceManagementScriptId $ht2.id
        Invoke-PrintAssignmentDetail -Assignments $DCPA
        
        Add-Header -level 3 -format $format -Text "Script"
        Add-ScriptText -format $format -Text ($PSScript.scriptContent -replace "`0", "")
    }
    #endregion
    #region AutoPilot Configuration
    $AutoPilotConfigs = Get-WindowsAutopilotConfig
    if($null -ne $AutoPilotConfigs){
        Add-Header -level 1 -format $format -Text "AutoPilot Configuration"
        
        foreach($APC in $AutoPilotConfigs){
            write-Log "AutoPilot Config: $($APC.displayName)"
            Add-Header -level 2 -format $format -Text $APC.displayName
            Invoke-PrintTable -Properties $APC.psobject.properties  -TypeName $APC.'@odata.type'
        }
    }
    #endregion

    #region Enrollment Configuration
    $EnrollmentStatusPage = Get-EnrollmentStatusPage
    if($null -ne $EnrollmentStatusPage){
        Add-Header -level 1 -format $format -Text "Enrollment Configuration"
        foreach($ESP in $EnrollmentStatusPage){
            write-Log "Enrollment Status Page Config: $($ESP.displayName)"
            $ESPtype = $ESP.'@odata.type'
            switch($ESPtype){
                "#microsoft.graph.windows10EnrollmentCompletionPageConfiguration" { $ESPtype = "ESP" }
                "#microsoft.graph.deviceEnrollmentLimitConfiguration" { $ESPtype = "Enrollment Limit" }
                "#microsoft.graph.deviceEnrollmentPlatformRestrictionsConfiguration" { $ESPtype = "Platform Restrictions" }
                "#microsoft.graph.deviceEnrollmentWindowsHelloForBusinessConfiguration" { $ESPtype = "Windows Hello for Business" }
            }
            Add-Header -level 2 -format $format -Text "$($ESPtype) - $($ESP.displayName)"
            
            Invoke-PrintTable -Properties $ESP.psobject.properties -TypeName $ESP.'@odata.type'
            $DCPA = Get-DeviceManagement_DeviceEnrollmentConfigurations_Assignments -deviceEnrollmentConfigurationId $ESP.id
            Invoke-PrintAssignmentDetail -Assignments $DCPA
        }
    }
    #endregion

    #region Custom Roles
    $CustomRoles = Get-DeviceManagement_RoleDefinitions | Where-Object { $_.isBuiltin -eq $false }
    if($null -ne $CustomRoles){
        Add-Header -level 1 -format $format -Text "Custom Roles"
        foreach($CustomRole in $CustomRoles){
            write-Log "Custom role: $($CustomRole.displayName)"
            Add-Header -level 2 -format $format -Text $CustomRole.displayName
            Add-Text -format $format -Text $CustomRole.rolePermissions.resourceActions.allowedResourceActions -Size 11
        }
    }
    #endregion

    #region Apple Push Certificate
    try{ 
        $VPPs = Get-IntuneVppToken -ErrorAction SilentlyContinue
        $APNs = Get-IntuneApplePushNotificationCertificate -ErrorAction SilentlyContinue
    } catch {
        Write-Log "Failed to load AppleAPN or VPP information"
    }
    Add-Header -level 1 -format $format -Text "Apple Configurations"
    Add-Header -level 2 -format $format -Text "Apple Push Certificate"
    foreach($APN in $APNs){
        write-Log "APN Config: $($APN.appleIdentifier)"
        Add-Header -level 3 -format $format -Text $APN.appleIdentifier
        Invoke-PrintTable -Properties $APN.psobject.properties -TypeName "applePushNotificationCertificate"
    }
    Add-Header -level 2 -format $format -Text "Apple VPP Tokens"
    foreach($VPP in $VPPs){
        write-Log "VPP Config: $($VPP.appleId)"
        Add-Header -level 3 -format $format -Text $VPP.appleId
        Invoke-PrintTable -Properties $VPP.psobject.properties -TypeName "appleVPPCertificate"
    }
    #endregion

    #region Device Categories
    $Cats = Get-IntuneDeviceCategory
    if($null -ne $Cats){
        Add-Header -level 1 -format $format -Text "Device Categories"
        write-Log "Device Categories: $($Cats.count)"
        foreach($Cat in $Cats){
            Add-Text -format $format -Text (" - " + $Cat.displayName)
        }
    }
    #endregion

    #region Exchange Connection
    $exch = Get-IntuneExchangeConnector
    if($null -ne $exch){
        Add-Header -level 1 -format $format -Text "Exchange Connector"
        write-Log "Exchange Connector: $($exch.serverName)"
        Invoke-PrintTable -Properties $exch.psobject.properties -TypeName "ExchangeConnector"
    }
    #endregion

    #region Partner Configuration
    $partnerConfigs = Get-IntuneDeviceManagementPartner
    if($null -ne $partnerConfigs){
        Add-Header -level 1 -format $format -Text "Partner Connections"
        
        foreach($partnerConfig in $partnerConfigs){
            write-Log "Partner Config: $($partnerConfig.displayName)"
            Add-Header -level 2 -format $format -Text $partnerConfig.displayName
            Invoke-PrintTable -Properties $partnerConfig.psobject.properties -TypeName "PartnerConfiguration"
        }
    }
    #endregion
    #endregion
    #region Finishing
    ########################################################
    if ($format -eq 'docx') {
        Write-Log "Press Ctrl + A and then F9 to Update the table of contents and other dynamic fields in the Word document."
    }
    if($Script:NewTranslationFiles.Count -gt 0 -and $Script:UseTranslation){
        Write-Log "You used the option to translate API properties. Some of the configurations of your tenant could not be translated because translations are missing." -Type Warn
        foreach($file in ($Script:NewTranslationFiles | Select-Object -Unique)){
            Write-Log " - $($file.Replace('Internal\..\',''))" -Type Warn
        }
        Write-Log "You can support the project by translating and submitting the files as issue on the project page. Then it will be included for the future." -Type Warn
        Write-Log "Follow the guide here https://github.com/ThomasKur/IntuneDocumentation/blob/master/AddTranslation.md" -Type Warn
    }
    
    Write-Log "End Script $Scriptname"
    #endregion
}
