<#
.DESCRIPTION
This Script documents an Intune Tenand with almostb all settings, which are available over the Graph API.

The Script is using the PSWord and Microsoft.Graph.Intune Module. Therefore you have to install them first.

.EXAMPLE


.NOTES
Author: Thomas Kurth/baseVISION
Co-Author: jflieben
Date:   28.7.2019

History
    001: First Version
    002: SetRegistryKey Function now allows to set empty values
    003: Change CreateFolder Function to first create folder and then write the log. Otherwise whe function can fail, when the logfile folder doesn't exist.
    004: Improved Log Action
    005: Version is now taken from Variable, Log can be written to Windows Event, 
         ScriptName does no longer contain Script FileName, which is now available in $CurrentFileName 
    006: ScriptPath not allways read correctly. Sometimes it was a relative path.
    007: Better formating and Option to specify the Save As location
    008: Jos Lieben: Fixed a few things and added Conditional Access Policies
    009: Thomas Kurth: Adding AutoPilot Information
    010: Thomas Kurth: Complete rewriting and using the Intune PowerShell module
         Added Partner Information
    011: Thomas Kurth: Added new sections:
            - Enrollment Page Configuration
            - Apple Push Certificate
            - Apple VPP
            - Device Categories
            - Exchange Connector


ExitCodes:
    99001: Could not Write to LogFile
    99002: Could not Write to Windows Log
    99003: Could not Set ExitMessageRegistry

#>
[CmdletBinding()]
Param()
## Manual Variable Definition
########################################################
$DebugPreference = "Continue"
$ScriptVersion = "011"
$ScriptName = "DocumentIntune"

$LogFilePathFolder     = Join-Path -Path $Env:TEMP -ChildPath $ScriptName

# Log Configuration
$DefaultLogOutputMode  = "Console" # "Console-LogFile","Console-WindowsEvent","LogFile-WindowsEvent","Console","LogFile","WindowsEvent","All"
$DefaultLogWindowsEventSource = $ScriptName
$DefaultLogWindowsEventLog = "CustomPS"

$MaxStringLengthSettings = 350
$DocumentName = "DocumentIntune.docx"
$DateTimeRegex = "\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{7}Z" 
 
#region Functions
########################################################

function Write-Log {
    <#
    .DESCRIPTION
    Write text to a logfile with the current time.

    .PARAMETER Message
    Specifies the message to log.

    .PARAMETER Type
    Type of Message ("Info","Debug","Warn","Error").

    .PARAMETER OutputMode
    Specifies where the log should be written. Possible values are "Console","LogFile" and "Both".

    .PARAMETER Exception
    You can write an exception object to the log file if there was an exception.

    .EXAMPLE
    Write-Log -Message "Start process XY"

    .NOTES
    This function should be used to log information to console or log file.
    #>
    param(
        [Parameter(Mandatory=$true,Position=1)]
        [String]
        $Message
    ,
        [Parameter(Mandatory=$false)]
        [ValidateSet("Info","Debug","Warn","Error")]
        [String]
        $Type = "Debug"
    ,
        [Parameter(Mandatory=$false)]
        [ValidateSet("Console-LogFile","Console-WindowsEvent","LogFile-WindowsEvent","Console","LogFile","WindowsEvent","All")]
        [String]
        $OutputMode = $DefaultLogOutputMode
    ,
        [Parameter(Mandatory=$false)]
        [Exception]
        $Exception
    )
    
    $DateTimeString = Get-Date -Format "yyyy-MM-dd HH:mm:sszz"
    $Output = ($DateTimeString + "`t" + $Type.ToUpper() + "`t" + $Message)
    if($Exception){
        $ExceptionString =  ("[" + $Exception.GetType().FullName + "] " + $Exception.Message)
        $Output = "$Output - $ExceptionString"
    }

    if ($OutputMode -eq "Console" -OR $OutputMode -eq "Console-LogFile" -OR $OutputMode -eq "Console-WindowsEvent" -OR $OutputMode -eq "All") {
        if($Type -eq "Error"){
            Write-Error $output
        } elseif($Type -eq "Warn"){
            Write-Warning $output
        } elseif($Type -eq "Debug"){
            Write-Debug $output
        } else{
            Write-Verbose $output -Verbose
        }
    }
    
    if ($OutputMode -eq "LogFile" -OR $OutputMode -eq "Console-LogFile" -OR $OutputMode -eq "LogFile-WindowsEvent" -OR $OutputMode -eq "All") {
        try {
            Add-Content $LogFilePath -Value $Output -ErrorAction Stop
        } catch {
            exit 99001
        }
    }

    if ($OutputMode -eq "Console-WindowsEvent" -OR $OutputMode -eq "WindowsEvent" -OR $OutputMode -eq "LogFile-WindowsEvent" -OR $OutputMode -eq "All") {
        try {
            New-EventLog -LogName $DefaultLogWindowsEventLog -Source $DefaultLogWindowsEventSource -ErrorAction SilentlyContinue
            switch ($Type) {
                "Warn" {
                    $EventType = "Warning"
                    break
                }
                "Error" {
                    $EventType = "Error"
                    break
                }
                default {
                    $EventType = "Information"
                }
            }
            Write-EventLog -LogName $DefaultLogWindowsEventLog -Source $DefaultLogWindowsEventSource -EntryType $EventType -EventId 1 -Message $Output -ErrorAction Stop
        } catch {
            exit 99002
        }
    }
}

function New-Folder{
    <#
    .DESCRIPTION
    Creates a Folder if it's not existing.

    .PARAMETER Path
    Specifies the path of the new folder.

    .EXAMPLE
    CreateFolder "c:\temp"

    .NOTES
    This function creates a folder if doesn't exist.
    #>
    param(
        [Parameter(Mandatory=$True,Position=1)]
        [string]$Path
    )
	# Check if the folder Exists

	if (Test-Path $Path) {
		Write-Log "Folder: $Path Already Exists"
	} else {
		New-Item -Path $Path -type directory | Out-Null
		Write-Log "Creating $Path"
	}
}

Function Get-WindowsAutopilotConfig(){
    <#
    .SYNOPSIS
    This function is used to get the AutoPilot configuration from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets the AutoPilot Configuration
    .EXAMPLE
    Get-WindowsAutopilotConfig
    Returns the AutoPilot Configuration configured in Intune
    .NOTES
    NAME: Get-WindowsAutopilotConfig
    #>

    try {
        $uri = "https://graph.microsoft.com/Beta/deviceManagement/windowsAutopilotDeploymentProfiles"
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

Function Get-EnrollmentStatusPage(){
    <#
    .SYNOPSIS
    This function is used to get the Enrollment Status Page configuration from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets the Enrollment Status Page Configuration
    .EXAMPLE
    Get-EnrollmentStatusPage
    Returns the Enrollment Status Page Configuration configured in Intune
    .NOTES
    NAME: Get-EnrollmentStatusPage
    #>

    try {
        $uri = "https://graph.microsoft.com/Beta/deviceManagement/deviceEnrollmentConfigurations"
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

Function Format-MsGraphData(){
    <#
    .SYNOPSIS
    This function Cleansup Values Returned By Microsoft Graph
    .DESCRIPTION
    This function Cleansup Values Returned By Microsoft Graph
    .EXAMPLE
    Format-MsGraphData -Value "@Odata.Type"
    Returns "Type"
    .NOTES
    NAME: Format-MsGraphData
    #>
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory=$false)]
        [AllowEmptyString()]
        [AllowNull()]
        [String]$Value
    )
    $Value = $Value -replace "#microsoft.graph.",""
    $Value = $Value -replace "windows","win"
    $Value = $Value -replace "StoreforBusiness","SfB"
    $Value = $Value -replace "@odata.",""
    if($Value -ne $null -and $Value -match "@{*"){
        $Value = $Value -replace "@{",""
        $Value = $Value -replace "}",""
        $Value = $Value -replace ";",""
    }
    if($Value -match $DateTimeRegex){
        try{
            [DateTime]$Date = ([DateTime]::Parse($Value))
            $Value = "$($Date.ToShortDateString()) $($Date.ToShortTimeString())"
        } catch {
        
        }
    }
    return $value
}

#endregion

#region Dynamic Variables and Parameters
########################################################

$LogFilePath = "$LogFilePathFolder\{0}_{1}_{2}.log" -f ($ScriptName -replace ".ps1", ''),$ScriptVersion,(Get-Date -uformat %Y%m%d%H%M)

#endregion

#region Initialization
########################################################

New-Folder $LogFilePathFolder
Write-Log "Start Script $Scriptname"

#region Loading Modules

Write-Log "Checking for Intune module..."
$IntuneModule = Get-Module -Name "Microsoft.Graph.Intune" -ListAvailable
if ($IntuneModule -eq $null) {
    write-Log "Intune Powershell module not installed..." -Type Warn
    write-Log "Install by running 'Install-Module Microsoft.Graph.Intune' from an elevated PowerShell prompt" -Type Warn
    write-Log "Script can't continue..." -Type Warn
    exit
}
Write-Log "Checking for PSWord module..."
$PSWordModule = Get-Module -Name "PSWord" -ListAvailable
if ($PSWordModule -eq $null) {
    write-Log "PSWord Powershell module not installed..." -Type Warn
    write-Log "Install by running 'Install-Module PSWord' from an elevated PowerShell prompt" -Type Warn
    write-Log "Script can't continue..." -Type Warn
    exit
}
    
#endregion
#region Authentication
Connect-MSGraph


#endregion
#endregion

#region Main Script
########################################################

#region Save Path
try{
    $SaveFileDialog = New-Object windows.forms.savefiledialog
    $SaveFileDialog.initialDirectory = $LogFilePathFolder 
    $SaveFileDialog.title = "Save File to Disk (If File exists, content will be appended)"   
    $SaveFileDialog.filter = "Word Document (*.docx)|*.docx" 
    $SaveFileDialog.ShowHelp = $True   
    Write-Log "Where would you like to create documentation file?... (see File Save Dialog)"
    $result = $SaveFileDialog.ShowDialog()    
    if($result -eq "OK")    {    
        Write-Log "Selected File and Location: $($SaveFileDialog.filename )" 
        $FullDocumentationPath = $SaveFileDialog.filename
    } 
    else { 
        Write-Log "File Save Dialog Cancelled! Using Default Path: $LogFilePathFolder\$DocumentName" -Type Warn
        $FullDocumentationPath = "$LogFilePathFolder\$DocumentName"
    } 
    $SaveFileDialog.Dispose()
} catch {
    Write-Log "File Save Dialog Cancelled! Using Default Path: $LogFilePathFolder\$DocumentName" -Type Warn

}
#endregion


#region Document Apps


$Intune_Apps = @()
Get-IntuneMobileApp | foreach {
    $App_Assignment = Get-IntuneMobileAppAssignment -mobileAppId $_.id
    if($App_Assignment){
        $Intune_App = New-Object -TypeName PSObject
        $Intune_App | Add-Member Noteproperty "Publisher" $_.publisher
        $Intune_App | Add-Member Noteproperty "DisplayName" $_.displayName
        $Intune_App | Add-Member Noteproperty "Type" (Format-MsGraphData $_.'@odata.type')
        $Assignments = @()
        foreach($Assignment in $App_Assignment) {
            $Assignments += "$((Get-AADGroup -groupid $Assignment.target.groupId).displayName)`n - Intent:$($Assignment.intent)"

        }
        $Intune_App | Add-Member Noteproperty "Assignments" ($Assignments -join "`n")
        $Intune_Apps += $Intune_App
    }
} 
Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Applications"
$Intune_Apps | Sort-Object Publisher,DisplayName | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Contents -Design LightListAccent2

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
    $GAndT | ForEach-Object { $_ | Select-Object -Property id,createdDateTime,modifiedDateTime,displayName,title,version } | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Contents -Design LightListAccent2
}
#endregion
#region Document EnrollmentRestrictions

Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Device Enrollment Restrictions"
$Restrictions = Get-IntuneDeviceEnrollmentConfiguration

foreach($restriction in $Restrictions){

    $ht2 = @{}
    $restriction.psobject.properties | Foreach { if($_.Name -ne "@odata.type"){$ht2[(Format-MsGraphData $($_.Name))] = ((Format-MsGraphData "$($_.Value) "))} }
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
                $Assignments += (Get-AADGroup -groupid $group.target.groupId).displayName
            }
            $Assignments | Add-WordText -FilePath $FullDocumentationPath -Size 12
        } else {
            $Assignments += (Get-AADGroup -groupid $DCPA.target.groupId).displayName | Add-WordText -FilePath $FullDocumentationPath  -Size 12
        }
        
    }
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
    Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text $ESP.displayName
    
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
Add-WordText -FilePath $FullDocumentationPath -Text " - " + $Cat.displayName -Size 10
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

Write-Log "End Script $Scriptname"

#endregion
