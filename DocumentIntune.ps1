<#
.DESCRIPTION
This Script documents an Intune Tenand with almostb all settings, which are available over the Graph API.

The Script is using the PSWord and AzureAD Module. Therefore you have to install them first.

.EXAMPLE


.NOTES
Author: Thomas Kurth/baseVISION
Co-Author: jflieben
Date:   4.7.2018

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
$ScriptVersion = "008"
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

function get-graphTokenForIntune(){
    <#
      .SYNOPSIS
      Retrieve special graph token to interact with the beta (and normal) Intune endpoint
      .DESCRIPTION
      this function wil also, if needed, register the well known microsoft ID for intune PS management
      .EXAMPLE
      $token = get-graphTokenForIntune -Username you@domain.com -Password Welcome01
      .PARAMETER Username
      the UPN of a user with global admin permissions
      .PARAMETER Password
      Password of Username
      .NOTES
      author: Jos Lieben
      blog: www.lieben.nu
      created: 12/6/2018
      requires: get-azureRMtoken.ps1
    #>    
    Param(
        [Parameter(Mandatory=$true)]$User,
        [Parameter(Mandatory=$true)]$Password
    )
    $userUpn = New-Object "System.Net.Mail.MailAddress" -ArgumentList $User
    $tenant = $userUpn.Host
    $AadModule = Get-Module -Name "AzureAD" -ListAvailable
    if ($AadModule -eq $null) {$AadModule = Get-Module -Name "AzureADPreview" -ListAvailable}
    if ($AadModule -eq $null) {
        write-error "AzureAD Powershell module not installed...install this module into your automation account (add from the gallery) and rerun this runbook" -erroraction Continue
        Throw
    }
    if($AadModule.count -gt 1){
        $Latest_Version = ($AadModule | select version | Sort-Object)[-1]
        $aadModule = $AadModule | ? { $_.version -eq $Latest_Version.version }
        if($AadModule.count -gt 1){$aadModule = $AadModule | select -Unique}
    }

    $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
    $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"

    [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
    [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null
    $clientId = "d1ddf0e4-d672-4dae-b554-9d5bdfd93547"
    $redirectUri = "urn:ietf:wg:oauth:2.0:oob"
    $resourceAppIdURI = "https://graph.microsoft.com"
    $authority = "https://login.microsoftonline.com/$Tenant"

    try {
        $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
        $platformParameters = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "Auto"
        $userId = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier" -ArgumentList ($User, "OptionalDisplayableId")
        $userCredentials = new-object Microsoft.IdentityModel.Clients.ActiveDirectory.UserPasswordCredential -ArgumentList $userUpn,$Password
        $authResult = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContextIntegratedAuthExtensions]::AcquireTokenAsync($authContext, $resourceAppIdURI, $clientid, $userCredentials);
        if($authResult.Exception -and $authResult.Exception.ToString() -like "*Send an interactive authorization request*"){
            try{
                #Intune Powershell has not yet been authorized, let's try to do this on the fly;
                $apiToken = get-azureRMToken -Username $User -Password $Password
                $header = @{
                'Authorization' = 'Bearer ' + $apiToken
                'X-Requested-With'= 'XMLHttpRequest'
                'x-ms-client-request-id'= [guid]::NewGuid()
                'x-ms-correlation-id' = [guid]::NewGuid()}
                $url = "https://main.iam.ad.ext.azure.com/api/RegisteredApplications/d1ddf0e4-d672-4dae-b554-9d5bdfd93547/Consent?onBehalfOfAll=true" #this is the Microsoft Intune Powershell app ID managed by Microsoft
                Invoke-RestMethod -Uri $url -Headers $header -Method POST -ErrorAction Stop
                $authResult = [Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContextIntegratedAuthExtensions]::AcquireTokenAsync($authContext, $resourceAppIdURI, $clientid, $userCredentials);
            }catch{
                Throw "You have not yet authorized Powershell, visit https://login.microsoftonline.com/$Tenant/oauth2/authorize?client_id=d1ddf0e4-d672-4dae-b554-9d5bdfd93547&response_type=code&redirect_uri=urn%3Aietf%3Awg%3Aoauth%3A2.0%3Aoob&response_mode=query&resource=https%3A%2F%2Fgraph.microsoft.com%2F&state=12345&prompt=admin_consent using a global administrator"
            }
        }
        $authResult = $authResult.Result
        if(!$authResult.AccessToken){
            Throw "access token is null!"
        }else{
            return $authResult.AccessToken
        }
    }catch {
        write-error "Failed to retrieve access token from Azure" -erroraction Continue
        write-error $_ -erroraction Stop
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
    $graphHeader = @{
        'Authorization' = 'Bearer ' + $authToken
        'X-Requested-With'= 'XMLHttpRequest'
        'x-ms-client-request-id'= [guid]::NewGuid()
        'x-ms-correlation-id' = [guid]::NewGuid()}
    try {
        if($Name){
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"

            (Invoke-RestMethod -Uri $uri -Headers $graphHeader -Method Get).Value | Where-Object { ($_.'displayName').contains("$Name") -and (!($_.'@odata.type').Contains("managed")) -and (!($_.'@odata.type').Contains("#microsoft.graph.iosVppApp")) }
        } else {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri -Headers $graphHeader -Method Get).Value | Where-Object { (!($_.'@odata.type').Contains("managed")) -and (!($_.'@odata.type').Contains("#microsoft.graph.iosVppApp")) }
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
    $graphHeader = @{
        'Authorization' = 'Bearer ' + $authToken
        'X-Requested-With'= 'XMLHttpRequest'
        'x-ms-client-request-id'= [guid]::NewGuid()
        'x-ms-correlation-id' = [guid]::NewGuid()}
    $graphApiVersion = "Beta"
    $Resource = "deviceAppManagement/mobileApps/$ApplicationId/?`$expand=categories,assignments&_=1530020353167"
    try {

        if(!$ApplicationId){
            write-Log "No Application Id specified, specify a valid Application Id" -Type Error
            break
        } else {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri -Headers $graphHeader -Method Get).Assignments
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
    $graphHeader = @{
        'Authorization' = 'Bearer ' + $authToken
        'X-Requested-With'= 'XMLHttpRequest'
        'x-ms-client-request-id'= [guid]::NewGuid()
        'x-ms-correlation-id' = [guid]::NewGuid()}
    try {
        if($id){
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)?`$filter=id eq '$id'"

            (Invoke-RestMethod -Uri $uri -Headers $graphHeader -Method Get).Value
        } elseif($GroupName -eq "" -or $GroupName -eq $null){
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)"
            (Invoke-RestMethod -Uri $uri -Headers $graphHeader -Method Get).Value
        } else {
            if(!$Members){
                $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)?`$filter=displayname eq '$GroupName'"
                (Invoke-RestMethod -Uri $uri -Headers $graphHeader -Method Get).Value
            } elseif($Members){

            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)?`$filter=displayname eq '$GroupName'"
            $Group = (Invoke-RestMethod -Uri $uri -Headers $graphHeader -Method Get).Value


                if($Group){
                    $GID = $Group.id
                    $Group.displayName
                    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Group_resource)/$GID/Members"

                    (Invoke-RestMethod -Uri $uri -Headers $graphHeader -Method Get).Value
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
    $graphHeader = @{
        'Authorization' = 'Bearer ' + $authToken
        'X-Requested-With'= 'XMLHttpRequest'
        'x-ms-client-request-id'= [guid]::NewGuid()
        'x-ms-correlation-id' = [guid]::NewGuid()}
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

            (Invoke-RestMethod -Uri $uri -Headers $graphHeader -Method Get).Value | Where-Object { ($_.'@odata.type').contains("android") }
        } elseif($iOS){
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri -Headers $graphHeader -Method Get).Value | Where-Object { ($_.'@odata.type').contains("ios") }
        } elseif($Win10){
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri -Headers $graphHeader -Method Get).Value | Where-Object { ($_.'@odata.type').contains("windows10CompliancePolicy") }
        } elseif($Name){
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri -Headers $graphHeader -Method Get).Value | Where-Object { ($_.'displayName').contains("$Name") }
        } else { 
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri -Headers $graphHeader -Method Get).Value
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

Function Get-AADUserDetails(){
    Param(
        $userGuid
    )
    $header = @{
    'Authorization' = 'Bearer ' + $rmToken
    'X-Requested-With'= 'XMLHttpRequest'
    'x-ms-client-request-id'= [guid]::NewGuid()
    'x-ms-correlation-id' = [guid]::NewGuid()}
    $url = "https://main.iam.ad.ext.azure.com/api/UserDetails/$userGuid"
    Write-Output (Invoke-RestMethod -Uri $url -Headers $header -Method GET -ErrorAction Stop)
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
    $graphHeader = @{
        'Authorization' = 'Bearer ' + $authToken
        'X-Requested-With'= 'XMLHttpRequest'
        'x-ms-client-request-id'= [guid]::NewGuid()
        'x-ms-correlation-id' = [guid]::NewGuid()}
    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id/assignments"
        (Invoke-RestMethod -Uri $uri -Headers $graphHeader -Method Get).Value
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
    $graphHeader = @{
        'Authorization' = 'Bearer ' + $authToken
        'X-Requested-With'= 'XMLHttpRequest'
        'x-ms-client-request-id'= [guid]::NewGuid()
        'x-ms-correlation-id' = [guid]::NewGuid()}    
    try {

        if($Name){
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($resource)"

            (Invoke-RestMethod -Uri $uri -Headers $graphHeader -Method Get).Value | Where-Object { ($_.'displayName').contains("$Name") }
        } else {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($resource)"
            (Invoke-RestMethod -Uri $uri -Headers $graphHeader -Method Get).Value
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


Function Get-DeviceEnrollmentRestrictions(){
    <#
    .SYNOPSIS
    This function is used to get device enrollment restrictions resource from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets the device enrollment restrictions Resource
    .EXAMPLE
    Get-DeviceEnrollmentRestrictions -id $id
    Returns device enrollment restrictions configured in Intune
    .NOTES
    NAME: Get-DeviceEnrollmentRestrictions
    #>
    [cmdletbinding()]
    param
    (
        $id
    )
    $graphApiVersion = "Beta"
    $Resource = "deviceManagement/deviceEnrollmentConfigurations"
    $graphHeader = @{
        'Authorization' = 'Bearer ' + $authToken
        'X-Requested-With'= 'XMLHttpRequest'
        'x-ms-client-request-id'= [guid]::NewGuid()
        'x-ms-correlation-id' = [guid]::NewGuid()}       
    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($resource)"
        (Invoke-RestMethod -Uri $uri -Headers $graphHeader -Method Get).Value
    } catch {
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEnd();
        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
    
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
    $graphHeader = @{
        'Authorization' = 'Bearer ' + $authToken
        'X-Requested-With'= 'XMLHttpRequest'
        'x-ms-client-request-id'= [guid]::NewGuid()
        'x-ms-correlation-id' = [guid]::NewGuid()}     
    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($resource)"

        (Invoke-RestMethod -Uri $uri -Headers $graphHeader -Method Get).Value
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
    $graphHeader = @{
        'Authorization' = 'Bearer ' + $authToken
        'X-Requested-With'= 'XMLHttpRequest'
        'x-ms-client-request-id'= [guid]::NewGuid()
        'x-ms-correlation-id' = [guid]::NewGuid()}       
    $graphApiVersion = "Beta"
    $DCP_resource = "deviceManagement/deviceConfigurations"
    try {
        if($Name){
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"

            (Invoke-RestMethod -Uri $uri -Headers $graphHeader -Method Get).Value | Where-Object { ($_.'displayName').contains("$Name") }
        } else {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)"
            (Invoke-RestMethod -Uri $uri -Headers $graphHeader -Method Get).Value
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
    $graphHeader = @{
        'Authorization' = 'Bearer ' + $authToken
        'X-Requested-With'= 'XMLHttpRequest'
        'x-ms-client-request-id'= [guid]::NewGuid()
        'x-ms-correlation-id' = [guid]::NewGuid()}
    $graphApiVersion = "Beta"
    $DCP_resource = "deviceManagement/deviceConfigurations"
    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($DCP_resource)/$id/assignments"
        (Invoke-RestMethod -Uri $uri -Headers $graphHeader -Method Get).Value
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
    [cmdletbinding()]
    $graphApiVersion = "Beta"
    $resource = "deviceManagement/windowsAutopilotDeploymentProfiles"
    $graphHeader = @{
        'Authorization' = 'Bearer ' + $authToken
        'X-Requested-With'= 'XMLHttpRequest'
        'x-ms-client-request-id'= [guid]::NewGuid()
        'x-ms-correlation-id' = [guid]::NewGuid()}     
    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($resource)"

        (Invoke-RestMethod -Uri $uri -Headers $graphHeader -Method Get).Value
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

function get-azureRMToken(){
    <#
      .SYNOPSIS
      Retrieve special Azure RM token to use for the main.iam.ad.ext.azure.com endpoint
      .DESCRIPTION
      The Azure RM token can be used for various actions that are not possible using Powershell cmdlets. This is experimental and should be used with caution!
      .EXAMPLE
      $token = get-azureRMToken -Username you@domain.com -Password Welcome01
      .PARAMETER Username
      the UPN of a user with sufficient permissions to call the endpoint (this depends on what you'll use the token for)
      .PARAMETER Password
      Password of Username
      .NOTES
      filename: get-azureRMToken.ps1
      author: Jos Lieben
      blog: www.lieben.nu
      created: 12/6/2018
    #>
    Param(
        [Parameter(Mandatory=$true)]$Username,
        [Parameter(Mandatory=$true)]$Password
    )
    $secpasswd = ConvertTo-SecureString $Password -AsPlainText -Force
    $mycreds = New-Object System.Management.Automation.PSCredential ($Username, $secpasswd)
    $res = login-azurermaccount -Credential $mycreds
    $context = Get-AzureRmContext
    $tenantId = $context.Tenant.Id
    $refreshToken = @($context.TokenCache.ReadItems() | where {$_.tenantId -eq $tenantId -and $_.ExpiresOn -gt (Get-Date)})[0].RefreshToken
    $body = "grant_type=refresh_token&refresh_token=$($refreshToken)&resource=74658136-14ec-4630-ad9b-26e160ff0fc6"
    $apiToken = Invoke-RestMethod "https://login.windows.net/$tenantId/oauth2/token" -Method POST -Body $body -ContentType 'application/x-www-form-urlencoded'
    return $apiToken.access_token
}
function get-conditionalAccessPolicySettings(){
    <#
      .SYNOPSIS
      Retrieve conditional access policy settings from Intune
      .DESCRIPTION
      Retrieves all conditional access policies from Intune (if policyId is omitted) and outputs their settings
      .EXAMPLE
      $policies = get-conditionalAccessPolicySettings
      .EXAMPLE
      $policy = get-conditionalAccessPolicySettings -policyId 533ceb01-3603-48cb-8586-56a60153939d
      .PARAMETER policyId
      GUID of the policy you wish to return, if left empty, all policies will be returned
      .NOTES
      filename: get-conditionalAccessPolicySettings.ps1
      author: Jos Lieben
      blog: www.lieben.nu
      created: 12/6/2018
      requires: global azure rm token
    #>
    Param(
        $policyId #if not specified, return all policies
    )

    $header = @{
    'Authorization' = 'Bearer ' + $rmToken
    'X-Requested-With'= 'XMLHttpRequest'
    'x-ms-client-request-id'= [guid]::NewGuid()
    'x-ms-correlation-id' = [guid]::NewGuid()}
    if(!$policyId){
        $url = "https://main.iam.ad.ext.azure.com/api/Policies/Policies?top=100&nextLink=null&appId=&includeBaseline=true"
        $policies = @(Invoke-RestMethod -Uri $url -Headers $header -Method GET -ErrorAction Stop).items
        foreach($policy in $policies){
            get-conditionalAccessPolicySettings -Username $Username -Password $Password -policyId $policy.policyId
        }
    }else{
        $url = "https://main.iam.ad.ext.azure.com/api/Policies/$policyId"
        try{
            $policy = Invoke-RestMethod -Uri $url -Headers $header -Method GET -ErrorAction Stop
            Write-Output $policy
        }catch{}
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

$LogFilePath = "$LogFilePathFolder\{0}_{1}_{2}.log" -f ($ScriptName -replace ".ps1", ''),$ScriptVersion,(Get-Date -uformat %Y%m%d%H%M)

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
$credentials = Get-Credential -Message "Please enter Office 365 / Azure global admin credentials"
$user = $credentials.GetNetworkCredential().UserName
$password = $credentials.GetNetworkCredential().Password

$Global:authToken = get-graphTokenForIntune -User  $user -Password $password
$Global:rmToken = get-azureRMToken -Username $user -Password $password

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
    $GAndT | ForEach-Object { $_ | Select-Object -Property id,createdDateTime,modifiedDateTime,displayName,title,version } | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Contents -Design LightListAccent2
}
#endregion
#region Document EnrollmentRestrictions

$Org = Get-Organization
$id = $Org.id

Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Device Enrollment Restrictions"
$Restrictions = (Get-DeviceEnrollmentRestrictions -id $id)

foreach($restriction in $Restrictions){

    $ht2 = @{}
    $restriction.psobject.properties | Foreach { if($_.Name -ne "@odata.context"){$ht2[(Format-MsGraphData $($_.Name))] = ((Format-MsGraphData "$($_.Value) "))} }
    ($ht2.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2
}
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
                $Assignments += (Get-AADGroup -id $group.target.groupId).displayName
            }
            $Assignments | Add-WordText -FilePath $FullDocumentationPath -Size 12
        } else {
            $Assignments += (Get-AADGroup -id $DCPA.target.groupId).displayName | Add-WordText -FilePath $FullDocumentationPath  -Size 12
        }
        
    }
}

#endregion

#region Conditional Access

Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "Conditional Access Configuration"
$CAPs = get-conditionalAccessPolicySettings
foreach($CAP in $CAPs){
    write-Log "Conditional Access Policy: $($CAP.policyName)"
    Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text $CAP.policyName
    
    $ht2 = @{}
    $CAP.psobject.properties | Foreach { 
        $ht2[(Format-MsGraphData $($_.Name))] = if((Format-MsGraphData "$($_.Value)").Length -gt $MaxStringLengthSettings){
                "$((Format-MsGraphData "$($_.Value)").substring(0, $MaxStringLengthSettings))..."
            } else {
                "$((Format-MsGraphData "$($_.Value)")) "
            }
    }
    ($ht2.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2

    Add-WordText -FilePath $FullDocumentationPath -Heading Heading3 -Text "Assignments (include)"
    $Assignments = @()
    foreach($assignment in $CAP.usersV2.included.groupIds){        
        $Assignments += (Get-AADGroup -id $assignment).displayName
    }
    foreach($assignment in $CAP.usersV2.included.userIds){        
        $Assignments += (Get-AADUserDetails -userGuid $assignment).displayName
    }
    $Assignments | Add-WordText -FilePath $FullDocumentationPath -Size 12  
      
    Add-WordText -FilePath $FullDocumentationPath -Heading Heading3 -Text "Assignments (exclude)"
    $Assignments = @()
    foreach($assignment in $CAP.usersV2.excluded.groupIds){        
        $Assignments += (Get-AADGroup -id $assignment).displayName
    }
    foreach($assignment in $CAP.usersV2.excluded.userIds){        
        $Assignments += (Get-AADUserDetails -userGuid $assignment).displayName
    }
    $Assignments | Add-WordText -FilePath $FullDocumentationPath -Size 12        
}


#endregion

#region AutoPilot Configuration

Add-WordText -FilePath $FullDocumentationPath -Heading Heading1 -Text "AutoPilot Configuration"
$AutoPilotConfigs = Get-WindowsAutopilotConfig

foreach($APC in $AutoPilotConfigs){
    write-Log "AutoPilot Config: $($APC.displayName)"
    Add-WordText -FilePath $FullDocumentationPath -Heading Heading2 -Text $APC.displayName
    
    $ht2 = @{}
    $APC.psobject.properties | Foreach { 
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
