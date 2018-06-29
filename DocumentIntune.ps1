<#
.DESCRIPTION
This Script documents an Intune Tenand with almostb all settings, which are available over the Graph API.

The Script is using the PSWord and AzureAD Module. Therefore you have to install them first.

.EXAMPLE


.NOTES
Author: Thomas Kurth/baseVISION
Co-Author: jflieben
Date:   30.6.2017

History
    001: First Version
    002: SetRegistryKey Function now allows to set empty values
    003: Change CreateFolder Function to first create folder and then write the log. Otherwise whe function can fail, when the logfile folder doesn't exist.
    004: Improved Log Action
    005: Version is now taken from Variable, Log can be written to Windows Event, 
         ScriptName does no longer contain Script FileName, which is now available in $CurrentFileName 
    006: ScriptPath not allways read correctly. Sometimes it was a relative path.
    007: Better formating and Option to specify the Save As location
    008: Update to support the current Graph API

ExitCodes:
    99001: Could not Write to LogFile
    99002: Could not Write to Windows Log
    99003: Could not Set ExitMessageRegistry

#>
[CmdletBinding()]
Param(
)
## Manual Variable Definition
########################################################
$DebugPreference = "Continue"
$ScriptVersion = "001"
$ScriptName = "DocumentIntune"

$LogFilePathFolder     = "C:\Windows\Logs"
$FallbackScriptPath    = "C:\Windows" # This is only used if the filename could not be resolved(IE running in ISE)

# Log Configuration
$DefaultLogOutputMode  = "Console" # "Console-LogFile","Console-WindowsEvent","LogFile-WindowsEvent","Console","LogFile","WindowsEvent","All"
$DefaultLogWindowsEventSource = $ScriptName
$DefaultLogWindowsEventLog = "CustomPS"

$MaxStringLengthSettings = 50
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

function Get-AuthToken {

<#
.SYNOPSIS
This function is used to authenticate with the Graph API REST interface
.DESCRIPTION
The function authenticate with the Graph API Interface with the tenant name
.EXAMPLE
Get-AuthToken
Authenticates you with the Graph API interface
.NOTES
NAME: Get-AuthToken
#>

[cmdletbinding()]

param
(
    [Parameter(Mandatory=$true)]
    $User
)

$userUpn = New-Object "System.Net.Mail.MailAddress" -ArgumentList $User

$tenant = $userUpn.Host



# Getting path to ActiveDirectory Assemblies
# If the module count is greater than 1 find the latest version

    if($AadModule.count -gt 1){

        $Latest_Version = ($AadModule | select version | Sort-Object)[-1]

        $aadModule = $AadModule | ? { $_.version -eq $Latest_Version.version }

            # Checking if there are multiple versions of the same module found

            if($AadModule.count -gt 1){

            $aadModule = $AadModule | select -Unique

            }

        $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
        $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"

    }

    else {

        $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
        $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"

    }

[System.Reflection.Assembly]::LoadFrom($adal) | Out-Null

[System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null

$clientId = "d1ddf0e4-d672-4dae-b554-9d5bdfd93547"
 
$redirectUri = "urn:ietf:wg:oauth:2.0:oob"
 
$resourceAppIdURI = "https://graph.microsoft.com"
 
$authority = "https://login.windows.net/$Tenant"
 
    try {

    $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority

    # https://msdn.microsoft.com/en-us/library/azure/microsoft.identitymodel.clients.activedirectory.promptbehavior.aspx
    # Change the prompt behaviour to force credentials each time: Auto, Always, Never, RefreshSession

    $platformParameters = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "Auto"

    $userId = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier" -ArgumentList ($User, "OptionalDisplayableId")

    $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI,$clientId,$redirectUri,$platformParameters,$userId).Result

        # If the accesstoken is valid then create the authentication header

        if($authResult.AccessToken){

        # Creating header for Authorization token

        $authHeader = @{
            'Content-Type'='application/json'
            'Authorization'="Bearer " + $authResult.AccessToken
            'ExpiresOn'=$authResult.ExpiresOn
            }

        return $authHeader

        } else {
            Write-Log "Authorization Access Token is null, please re-run authentication..." -Type Error
            break
        }

    }

    catch {

    write-Log "Error occured $($_.Exception.ItemName)" -Exception  $_.Exception -Type Error
    break

    }

}

Function Get-IntuneApplication(){

<#
.SYNOPSIS
This function is used to get applications from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets any applications added
.EXAMPLE
Get-IntuneApplication
Returns any applications configured in Intune
.NOTES
NAME: Get-IntuneApplication
#>

[cmdletbinding()]

param
(
    $Name
)

    $graphApiVersion = "Beta"
    $Resource = "deviceAppManagement/mobileApps"

    try {
        if($Name){
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value | Where-Object { ($_.'displayName').contains("$Name") -and (!($_.'@odata.type').Contains("managed")) -and (!($_.'@odata.type').Contains("#microsoft.graph.iosVppApp")) }
        } else {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value | Where-Object { (!($_.'@odata.type').Contains("managed")) -and (!($_.'@odata.type').Contains("#microsoft.graph.iosVppApp")) }
        }
    } catch {
        $ex = $_.Exception
        Write-Log "Request to $Uri failed with HTTP Status $([int]$ex.Response.StatusCode) $($ex.Response.StatusDescription)" -Type Error
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Log "Response content:`n$responseBody" -Type Error
        Write-Log "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)" -Type Error
    }

}

Function Get-ApplicationAssignment(){

<#
.SYNOPSIS
This function is used to get an application assignment from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets an application assignment
.EXAMPLE
Get-ApplicationAssignment
Returns an Application Assignment configured in Intune
.NOTES
NAME: Get-ApplicationAssignment
#>

[cmdletbinding()]

param
(
    $ApplicationId
)

$graphApiVersion = "Beta"
$Resource = "deviceAppManagement/mobileApps/$ApplicationId/assignments"

    try {

        if(!$ApplicationId){

        write-host "No Application Id specified, specify a valid Application Id" -f Red
        break

        }

        else {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value

        }

    }

    catch {

    $ex = $_.Exception
    $errorResponse = $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Host "Response content:`n$responseBody" -f Red
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    write-host
    break

    }

}


Function Get-AADGroup(){
<#
.SYNOPSIS
This function is used to get AAD Groups from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets any Groups registered with AAD
.EXAMPLE
Get-AADGroup
Returns all users registered with Azure AD
.NOTES
NAME: Get-AADGroup
#>

[cmdletbinding()]

param
(
    $GroupName,
    $id,
    [switch]$Members
)

    # Defining Variables
    $graphApiVersion = "v1.0"
    $Group_resource = "groups"

    try {
        if($id){
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)?`$filter=id eq '$id'"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
        } elseif($GroupName -eq "" -or $GroupName -eq $null){
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
        } else {
            if(!$Members){
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)?`$filter=displayname eq '$GroupName'"
                (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
            } elseif($Members){

            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)?`$filter=displayname eq '$GroupName'"
            $Group = (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value

                if($Group){
                    $GID = $Group.id
                    $Group.displayName
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)/$GID/Members"
                    (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
                }
            }
        }
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

Function Get-DeviceCompliancePolicy(){

<#
.SYNOPSIS
This function is used to get device compliance policies from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets any device compliance policies
.EXAMPLE
Get-DeviceCompliancePolicy
Returns any device compliance policies configured in Intune
.EXAMPLE
Get-DeviceCompliancePolicy -Android
Returns any device compliance policies for Android configured in Intune
.EXAMPLE
Get-DeviceCompliancePolicy -iOS
Returns any device compliance policies for iOS configured in Intune
.NOTES
NAME: Get-DeviceCompliancePolicy
#>

[cmdletbinding()]

param
(
    $Name,
    [switch]$Android,
    [switch]$iOS,
    [switch]$Win10
)

    $graphApiVersion = "Beta"
    $Resource = "deviceManagement/deviceCompliancePolicies"

    try {

        $Count_Params = 0

        if($Android.IsPresent){ $Count_Params++ }
        if($iOS.IsPresent){ $Count_Params++ }
        if($Win10.IsPresent){ $Count_Params++ }
        if($Name.IsPresent){ $Count_Params++ }

        if($Count_Params -gt 1){
            write-Log "Multiple parameters set, specify a single parameter -Android -iOS or -Win10 against the function" -Type Error
        } elseif($Android){
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value | Where-Object { ($_.'@odata.type').contains("android") }
        } elseif($iOS){
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value | Where-Object { ($_.'@odata.type').contains("ios") }
        } elseif($Win10){
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value | Where-Object { ($_.'@odata.type').contains("windows10CompliancePolicy") }
        } elseif($Name){
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value | Where-Object { ($_.'displayName').contains("$Name") }
        } else { 
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
        }

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

Function Get-DeviceCompliancePolicyAssignment(){

<#
.SYNOPSIS
This function is used to get device compliance policy assignment from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets a device compliance policy assignment
.EXAMPLE
Get-DeviceCompliancePolicyAssignment -id $id
Returns any device compliance policy assignment configured in Intune
.NOTES
NAME: Get-DeviceCompliancePolicyAssignment
#>

[cmdletbinding()]

param
(
    [Parameter(Mandatory=$true,HelpMessage="Enter id (guid) for the Device Compliance Policy you want to check assignment")]
    $id
)

$graphApiVersion = "Beta"
$DCP_resource = "deviceManagement/deviceCompliancePolicies"

    try {

    $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id/assignments"
    (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value

    }

    catch {

    $ex = $_.Exception
    $errorResponse = $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Host "Response content:`n$responseBody" -f Red
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    write-host
    break

    }

}


Function Get-TermsAndConditions(){

<#
.SYNOPSIS
This function is used to get the Get Terms And Conditions intune resource from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets the Terms and Conditions Intune Resource
.EXAMPLE
Get-TermsAndConditions
Returns the Organization resource configured in Intune
.NOTES
NAME: Get-TermsAndConditions
#>

[cmdletbinding()]

param
(
    $Name
)
    $graphApiVersion = "Beta"
    $resource = "deviceManagement/termsAndConditions"
    try {

        if($Name){
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value | Where-Object { ($_.'displayName').contains("$Name") }
        } else {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
        }
    } catch {
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Log "Response content:`n$responseBody" -Type Error
        Write-Log "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"  -Type Error
    }

}

Function Get-DeviceEnrollmentConfigurations(){
    
<#
.SYNOPSIS
This function is used to get Deivce Enrollment Configurations from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets Device Enrollment Configurations
.EXAMPLE
Get-DeviceEnrollmentConfigurations
Returns Device Enrollment Configurations configured in Intune
.NOTES
NAME: Get-DeviceEnrollmentConfigurations
#>
    
    [cmdletbinding()]
    
    $graphApiVersion = "Beta"
    $Resource = "deviceManagement/deviceEnrollmentConfigurations"
        
        try {
            
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
    
        }
        
        catch {
    
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        write-host
        break
    
        }
    
    }


Function Get-Organization(){
<#
.SYNOPSIS
This function is used to get the Organization intune resource from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets the Organization Intune Resource
.EXAMPLE
Get-Organization
Returns the Organization resource configured in Intune
.NOTES
NAME: Get-Organization
#>
[cmdletbinding()]
    $graphApiVersion = "Beta"
    $resource = "organization"
    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($resource)"
        (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
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

Function Get-DeviceConfigurationPolicy(){

<#
.SYNOPSIS
This function is used to get device configuration policies from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets any device configuration policies
.EXAMPLE
Get-DeviceConfigurationPolicy
Returns any device configuration policies configured in Intune
.NOTES
NAME: Get-DeviceConfigurationPolicy
#>

[cmdletbinding()]

param
(
    $name
)
    $graphApiVersion = "Beta"
    $DCP_resource = "deviceManagement/deviceConfigurations"
    try {
        if($Name){
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value | Where-Object { ($_.'displayName').contains("$Name") }
        } else {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
        }
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

Function Get-DeviceConfigurationPolicyAssignment(){

<#
.SYNOPSIS
This function is used to get device configuration policy assignment from the Graph API REST interface
.DESCRIPTION
The function connects to the Graph API Interface and gets a device configuration policy assignment
.EXAMPLE
Get-DeviceConfigurationPolicyAssignment $id guid
Returns any device configuration policy assignment configured in Intune
.NOTES
NAME: Get-DeviceConfigurationPolicyAssignment
#>

[cmdletbinding()]

param
(
    [Parameter(Mandatory=$true,HelpMessage="Enter id (guid) for the Device Configuration Policy you want to check assignment")]
    $id
)

$graphApiVersion = "Beta"
$DCP_resource = "deviceManagement/deviceConfigurations"

    try {

    $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id/groupAssignments"
    (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value

    }

    catch {

    $ex = $_.Exception
    $errorResponse = $ex.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($errorResponse)
    $reader.BaseStream.Position = 0
    $reader.DiscardBufferedData()
    $responseBody = $reader.ReadToEnd();
    Write-Host "Response content:`n$responseBody" -f Red
    Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    write-host
    break

    }

}


Function Format-MsGraphData(){
    <#
.SYNOPSIS
This function CLeansup Values Returned By Microsoft Graph
.DESCRIPTION
This function CLeansup Values Returned By Microsoft Graph
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

# Try get actual ScriptName
try{
    $CurrentFileNameTemp = $MyInvocation.MyCommand.Name
    If($CurrentFileNameTemp -eq $null -or $CurrentFileNameTemp -eq ""){
        $CurrentFileName = "NotExecutedAsScript"
    } else {
        $CurrentFileName = $CurrentFileNameTemp
    }
} catch {
    $CurrentFileName = $LogFilePathScriptName
}
$LogFilePath = "$LogFilePathFolder\{0}_{1}_{2}.log" -f ($ScriptName -replace ".ps1", ''),$ScriptVersion,(Get-Date -uformat %Y%m%d%H%M)
# Try get actual ScriptPath
try{
    try{ 
        $ScriptPathTemp = Split-Path $MyInvocation.MyCommand.Path
    } catch {

    }
    if([String]::IsNullOrWhiteSpace($ScriptPathTemp)){
        $ScriptPathTemp = Split-Path $MyInvocation.InvocationName
    }

    If([String]::IsNullOrWhiteSpace($ScriptPathTemp)){
        $ScriptPath = $FallbackScriptPath
    } else {
        $ScriptPath = $ScriptPathTemp
    }
} catch {
    $ScriptPath = $FallbackScriptPath
}

#endregion

#region Initialization
########################################################

New-Folder $LogFilePathFolder
Write-Log "Start Script $Scriptname"

#region Loading Modules
    Write-Log "Checking for AzureAD module..."
    $AadModule = Get-Module -Name "AzureAD" -ListAvailable
    if ($AadModule -eq $null) {
        Write-Log "AzureAD PowerShell module not found, looking for AzureADPreview"
        $AadModule = Get-Module -Name "AzureADPreview" -ListAvailable
    }

    if ($AadModule -eq $null) {
        write-Log "AzureAD Powershell module not installed..." -Type Warn
        write-Log "Install by running 'Install-Module AzureAD' or 'Install-Module AzureADPreview' from an elevated PowerShell prompt" -Type Warn
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

# Checking if authToken exists before running authentication
if($global:authToken){
    # Setting DateTime to Universal time to work in all timezones
    $DateTime = (Get-Date).ToUniversalTime()

    # If the authToken exists checking when it expires
    $TokenExpires = ($authToken.ExpiresOn.datetime - $DateTime).Minutes

    if($TokenExpires -le 0){
        write-Log "Authentication Token expired $TokenExpires minutes ago" -Type Warn
        # Defining User Principal Name if not present
        if($User -eq $null -or $User -eq ""){
            $User = Read-Host -Prompt "Please specify your user principal name for Azure Authentication"
        }

        $global:authToken = Get-AuthToken -User $User
    }
} else {
    # Authentication doesn't exist, calling Get-AuthToken function
    if($User -eq $null -or $User -eq ""){
        $User = Read-Host -Prompt "Please specify your user principal name for Azure Authentication"
    }

    # Getting the authorization token
    $global:authToken = Get-AuthToken -User $User
}
#endregion
#endregion

#region Main Script
########################################################

#region Save Path
try{
    $SaveFileDialog = New-Object windows.forms.savefiledialog   
    $SaveFileDialog.initialDirectory = $ScriptPath  
    $SaveFileDialog.title = "Save File to Disk (If File exists, content will be appended)"   
    $SaveFileDialog.filter = "Word Document (*.docx)|*.docx" 
    $SaveFileDialog.ShowHelp = $True   
    Write-Log "Where would you like to create documentation file?... (see File Save Dialog)"
    $result = $SaveFileDialog.ShowDialog()    
    if($result -eq "OK")    {    
        Write-Log "Selected File and Location: $($SaveFileDialog.filename )" 
        $FullDocumentationPath = $SaveFileDialog.filename
    } 
    else { 
        Write-Log "File Save Dialog Cancelled! Using Default Path: $ScriptPath\$DocumentName" -Type Warn
        $FullDocumentationPath = "$ScriptPath\$DocumentName"
    } 
    $SaveFileDialog.Dispose()
} catch {
    Write-Log "File Save Dialog Cancelled! Using Default Path: $ScriptPath\$DocumentName" -Type Warn
}
#endregion


#region Document Apps

    $Intune_Apps = @()
    Get-IntuneApplication | foreach {
        $App_Assignment = Get-ApplicationAssignment -ApplicationId $_.id
        if($App_Assignment){
            $Intune_App = New-Object -TypeName PSObject
            $Intune_App | Add-Member Noteproperty "Publisher" $_.publisher
            $Intune_App | Add-Member Noteproperty "DisplayName" $_.displayName
            $Intune_App | Add-Member Noteproperty "Type" (Format-MsGraphData $_.'@odata.type')
            $Assignments = @()
            foreach($Assignment in $App_Assignment) {
                $Assignments += "$((Get-AADGroup -id $Assignment.target.groupId).displayName)`n - Intent:$($Assignment.intent)"
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
    $DCPs = Get-DeviceCompliancePolicy
    foreach($DCP in $DCPs){

        write-Log "Device Compliance Policy: $($DCP.displayName)"
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text $DCP.displayName
        
        $ht2 = @{}
        $DCP.psobject.properties | Foreach { $ht2[(Format-MsGraphData $($_.Name))] = (Format-MsGraphData $($_.Value)) }
        ($ht2.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2 

        $id = $DCP.id
        $DCPA = Get-DeviceCompliancePolicyAssignment -id $id

        if($DCPA){
            write-Log "Getting Compliance Policy assignment..."
            Add-WordText -FilePath $FullDocumentationPath -Heading Heading3 -Text "Assignments"
            
            if($DCPA.count -gt 1){
                $Assignments = @()
                foreach($group in $DCPA){
                    $Assignments += (Get-AADGroup -id $group.target.groupId).displayName
                }
                $Assignments | Add-WordText -FilePath $FullDocumentationPath -Size 12
            } else {
                (Get-AADGroup -id $DCPA.target.groupId).displayName | Add-WordText -FilePath $FullDocumentationPath -Size 12
            }
            
        }
    }

#endregion
#region Document T&C
    write-Log "Terms and Conditions"
    $GAndT = Get-TermsAndConditions 
    if($GAndT){
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Terms and Conditions"
        $GAndT | ForEach-Object { $_ | Select-Object -Property id,createdDateTime,modifiedDateTime,displayName,title,version }| Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Contents -Design LightListAccent2
    }
#endregion
#region Document EnrollmentRestrictions

    
    Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Device Enrollment Restrictions"
    $Restrictions = Get-DeviceEnrollmentConfigurations
    $ht2 = @{}
    $Restrictions.psobject.properties | Foreach { if($_.Name -ne "@odata.context"){$ht2[(Format-MsGraphData $($_.Name))] = ((Format-MsGraphData "$($_.Value) "))} }
    ($ht2.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2

#endregion
#region Document Device Configurations

    Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Device Configuration"
    $DCPs = Get-DeviceConfigurationPolicy

    foreach($DCP in $DCPs){

        write-Log "Device Compliance Policy: $($DCP.displayName)"
        Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text $DCP.displayName
        
        $ht2 = @{}
        $DCP.psobject.properties | Foreach { 
            $ht2[(Format-MsGraphData $($_.Name))] = if((Format-MsGraphData "$($_.Value)").Length -gt $MaxStringLengthSettings){
                    "$((Format-MsGraphData "$($_.Value)").substring(0, $MaxStringLengthSettings))..."
                } else {
                    "$((Format-MsGraphData "$($_.Value)")) "
                }
        }
        ($ht2.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2

        $id = $DCP.id
        $DCPA = Get-DeviceConfigurationPolicyAssignment -id $id

        if($DCPA){
            write-Log "Getting Compliance Policy assignment..."
            Add-WordText -FilePath $FullDocumentationPath -Heading Heading3 -Text "Assignments"
            
            if($DCPA.count -gt 1){
                $Assignments = @()
                foreach($group in $DCPA){
                    $Assignments += (Get-AADGroup -id $group.targetGroupId).displayName
                }
                $Assignments | Add-WordText -FilePath $FullDocumentationPath -Size 12
            } else {
                $Assignments += (Get-AADGroup -id $DCPA.targetGroupId).displayName | Add-WordText -FilePath $FullDocumentationPath  -Size 12
            }
            
        }
    }

#endregion

#endregion

#region Finishing
########################################################

Write-Log "End Script $Scriptname"

#endregion
