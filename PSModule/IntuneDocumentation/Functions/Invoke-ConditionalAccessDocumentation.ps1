Function Invoke-ConditionalAccessDocumentation(){
    <#
    .DESCRIPTION
    This Script documents an Conditional Access with almost all settings, which are available over the Graph API.
    
    The Script is using the PSWord and Microsoft.Graph.Intune Module. Therefore you have to install them first.

    .PARAMETER FullDocumentationPath
        Path including filename where the documentation should be created. The filename has to end with .docx.
        Note:
        If there is already a file present, the documentation witt be added at the end of the existing document.

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

    .EXAMPLE Non interactive
    Invoke-ConditionalAccessDocumentation -FullDocumentationPath c:\temp\IntuneDoc.docx  -ClientId d5cf6364-82f7-4024-9ac1-73a9fd2a6ec3 -ClientSecret S03AESdMlhLQIPYYw/cYtLkGkQS0H49jXh02AS6Ek0U= -Tenant d873f16a-73a2-4ccf-9d36-67b8243ab99a

    .NOTES
    Author: Thomas Kurth/baseVISION
    Date:   26.7.2020

    History
        See Release Notes in Github.

    #>
    [alias("Invoke-CADocumentation")]
    [CmdletBinding()]
    Param(
        [ValidateScript({
            if($_ -notmatch "(\.docx)"){
                throw "The file specified in the path argument must be of type docx"
            }
            return $true 
        })]
        [Parameter(ParameterSetName = "NonInteractive")]
        [System.IO.FileInfo]$FullDocumentationPath = ".\IntuneDocumentation.docx",

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
    $ScriptName = "DocumentCA"
    $Script:NewTranslationFiles = @()
    if($UseTranslationBeta){
        $Script:UseTranslation = $true
    } else {
        $Script:UseTranslation = $false
    }

    #region Initialization
    ########################################################
    Write-Log "Start Script $Scriptname"
    #region Authentication
    
    $authority = "https://login.windows.net/$Tenant"
    Update-MSGraphEnvironment -AppId $ClientId -Quiet
    Update-MSGraphEnvironment -AuthUrl $authority -Quiet
    Connect-MSGraph -ClientSecret $ClientSecret -Quiet
    
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
        Update-WordText -FilePath $FullDocumentationPath -ReplacingText "SYSTEM" -NewText "Conditional Access"
        try{
            $org = Invoke-MSGraphRequest -Url /organization
            Update-WordText -FilePath $FullDocumentationPath -ReplacingText "TENANT" -NewText $org.value.displayName
        } catch{
            Update-WordText -FilePath $FullDocumentationPath -ReplacingText "TENANT" -NewText ""
        }
    }
    #endregion
    #region Document Conditional Access
    $ResultCAPolicies = @()
    $CAPolicies = Get-ConditionalAccess
    foreach($CAPolicy in $CAPolicies){
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text $CAPolicy.displayName
        $ResultCAPolicy = New-Object -Type PSObject
        $ResultCAPolicy | Add-Member Noteproperty "M_Id" $CAPolicy.id
        $ResultCAPolicy | Add-Member Noteproperty "M_DisplayName" $CAPolicy.displayName
        $ResultCAPolicy | Add-Member Noteproperty "M_Created" $CAPolicy.createdDateTime
        $ResultCAPolicy | Add-Member Noteproperty "M_Modified" $CAPolicy.modifiedDateTime
        $ResultCAPolicy | Add-Member Noteproperty "M_State" $CAPolicy.state
        $ResultCAPolicy | Add-Member Noteproperty "C_SignInRiskLevel" ($CAPolicy.conditions.signInRiskLevels -join ",")
        $ResultCAPolicy | Add-Member Noteproperty "C_ClientAppTypes" ($CAPolicy.conditions.clientAppTypes -join ",")
        $ResultCAPolicy | Add-Member Noteproperty "C_PlatformsInclude" ($CAPolicy.conditions.platforms.includePlatforms -join ",")
        $ResultCAPolicy | Add-Member Noteproperty "C_PlatformsExclude" ($CAPolicy.conditions.platforms.excludePlatforms -join ",")
        $ResultCAPolicy | Add-Member Noteproperty "C_LocationsInclude" ($CAPolicy.conditions.locations.includeLocations -join ",")
        $ResultCAPolicy | Add-Member Noteproperty "C_LocationsExclude" ($CAPolicy.conditions.locations.excludeLocations -join ",")
        $ResultCAPolicy | Add-Member Noteproperty "C_DeviceStates" ($CAPolicy.conditions.deviceStates -join ",")
        $ResultCAPolicy | Add-Member Noteproperty "C_Devices" ($CAPolicy.conditions.devices -join ",")
        
        # Application Condition
        $IncludeApps = @()
        foreach($app in $CAPolicy.conditions.applications.includeApplications){
            $IncludeApps += Get-AzureADApplicationName -AppId $app
        }
        $ResultCAPolicy | Add-Member Noteproperty "C_ApplicationsInclude" ($IncludeApps -join [System.Environment]::NewLine)

        $ExcludeApps = @()
        foreach($app in $CAPolicy.conditions.applications.excludeApplications){
            $ExcludeApps += Get-AzureADApplicationName -AppId $app
        }
        $ResultCAPolicy | Add-Member Noteproperty "C_ApplicationsExclude" ($ExcludeApps -join [System.Environment]::NewLine)

        $ResultCAPolicy | Add-Member Noteproperty "C_ApplicationsIncludeUserActions" ($CAPolicy.conditions.applications.includeUserActions -join ",")

        #User Conditions
        $IncludeUsers = @()
        foreach($user in $CAPolicy.conditions.users.includeUsers){
            $IncludeUsers += Get-AzureADUser -UserId $user
        }
        $ResultCAPolicy | Add-Member Noteproperty "C_UsersInclude" ($IncludeUsers -join [System.Environment]::NewLine)

        $ExcludeUsers = @()
        foreach($user in $CAPolicy.conditions.users.excludeUsers){
            $ExcludeUsers += Get-AzureADUser -UserId $user
        }
        $ResultCAPolicy | Add-Member Noteproperty "C_UsersExclude" ($ExcludeUsers -join [System.Environment]::NewLine)

        # Group Conditions
        $IncludeGroups = @()
        foreach($group in $CAPolicy.conditions.users.includeGroups){
            $IncludeGroups += (Get-AADGroup -groupid $group).displayName
        }
        $ResultCAPolicy | Add-Member Noteproperty "C_UsersIncludeGroups" ($IncludeGroups -join [System.Environment]::NewLine)

        $ExcludeApps = @()
        foreach($group in $CAPolicy.conditions.users.excludeGroups){
            $ExcludeGroups += (Get-AADGroup -groupid $group).displayName
        }
        $ResultCAPolicy | Add-Member Noteproperty "C_UsersExcludeGroups" ($ExcludeGroups -join [System.Environment]::NewLine)

        # Role Conditions
        $IncludeRoles = @()
        foreach($role in $CAPolicy.conditions.users.includeRoles){
            $IncludeRoles += Get-AzureADRole -RoleId $role
        }
        $ResultCAPolicy | Add-Member Noteproperty "C_UsersIncludeRoles" ($IncludeRoles -join [System.Environment]::NewLine)

        $ExcludeApps = @()
        foreach($role in $CAPolicy.conditions.users.excludeRoles){
            $ExcludeRoles += Get-AzureADRole -RoleId $role
        }
        $ResultCAPolicy | Add-Member Noteproperty "C_UsersExcludeRoles" ($ExcludeRoles -join [System.Environment]::NewLine)

        $ResultCAPolicy | Add-Member Noteproperty "G_Operator" $CAPolicy.grantControls.operator
        $ResultCAPolicy | Add-Member Noteproperty "G_BuiltInControls" ($CAPolicy.grantControls.builtInControls -join ",")
        $ResultCAPolicy | Add-Member Noteproperty "G_CustomControls" ($CAPolicy.grantControls.customAuthenticationFactors -join ",")
        $ResultCAPolicy | Add-Member Noteproperty "G_TermsOfUse" ($CAPolicy.grantControls.termsOfUse -join ",")
        $ResultCAPolicy | Add-Member Noteproperty "S_ApplicationEnforcedRestriction" ($CAPolicy.sessionControls.applicationEnforcedRestrictions.isEnabled)
        $ResultCAPolicy | Add-Member Noteproperty "S_CloudAppSecurity" ($CAPolicy.sessionControls.cloudAppSecurity.isEnabled)
        $ResultCAPolicy | Add-Member Noteproperty "S_CloudAppSecurityType" ($CAPolicy.sessionControls.cloudAppSecurity.cloudAppSecurityTyp)
        $ResultCAPolicy | Add-Member Noteproperty "S_PersistentBrowser" ($CAPolicy.sessionControls.persistentBrowser.isEnabled)
        $ResultCAPolicy | Add-Member Noteproperty "S_PersistentBrowserMode" ($CAPolicy.sessionControls.persistentBrowser.mode)
        $ResultCAPolicy | Add-Member Noteproperty "S_SignInFrequency" ($CAPolicy.sessionControls.signInFrequency.isEnabled)
        $ResultCAPolicy | Add-Member Noteproperty "S_SignInFrequencyTimeframe" ("" + $CAPolicy.sessionControls.signInFrequency.value +" "+ $CAPolicy.sessionControls.signInFrequency.type)
        
        $ResultCAPolicies += $ResultCAPolicy

        Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text Metadata
        $ht2 = @{}
        $ResultCAPolicy.psobject.properties | Where-Object { $_.Name -like "M_*" } | ForEach-Object { $ht2[($_.Name.Replace("M_",""))] = ($(if($null -eq $_.Value){""}else{$_.Value})) }
        ($ht2.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2 

        Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text Conditions
        $ht2 = @{}
        $ResultCAPolicy.psobject.properties | Where-Object { $_.Name -like "C_*" } | ForEach-Object { $ht2[($_.Name.Replace("C_",""))] = ($(if($null -eq $_.Value){""}else{$_.Value})) }
        ($ht2.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2 
        
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text "Grant Controls"
        $ht2 = @{}
        $ResultCAPolicy.psobject.properties | Where-Object { $_.Name -like "G_*" } | ForEach-Object { $ht2[($_.Name.Replace("G_",""))] = ($(if($null -eq $_.Value){""}else{$_.Value})) }
        ($ht2.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2 
        
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text "Session Controls"
        $ht2 = @{}
        $ResultCAPolicy.psobject.properties | Where-Object { $_.Name -like "S_*" } | ForEach-Object { $ht2[($_.Name.Replace("S_",""))] = ($(if($null -eq $_.Value){""}else{$_.Value})) }
        ($ht2.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2 
    
    }
    $CsvPath = $FullDocumentationPath -replace "docx","csv"
    $ResultCAPolicies | Invoke-TransposeObject | Export-Csv -Path $CsvPath -Delimiter ";" -NoTypeInformation -Force


    #endregion

    #endregion
    #region Finishing
    ########################################################
    Write-Log "Press Ctrl + A and then F9 to Update the table of contents and other dynamic fields in the Word document."
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