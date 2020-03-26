$ModulePath = ".\PSModule\IntuneDocumentation"
$Icon = "https://github.com/ThomasKur/IntuneDocumentation/raw/master/Logo/IntuneDocumentationLogo.png"
$License = "https://github.com/ThomasKur/IntuneDocumentation/blob/master/LICENSE"
#region UI 
$yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Description."
$no = New-Object System.Management.Automation.Host.ChoiceDescription "&No","Description."
$cancel = New-Object System.Management.Automation.Host.ChoiceDescription "&Cancel","Description."
$options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no, $cancel)

$title = "Version History" 
$message = "Have you updated the Release Notes for the new Version?"
$result = $host.ui.PromptForChoice($title, $message, $options, 1)
switch ($result) {
    0{

    }
    1{
        Write-Error "Canceled Publishing Process" -ErrorAction Stop
    }
    2{
        Write-Error "Canceled Publishing Process" -ErrorAction Stop
    }
}
#endregion

#region Code Analyzer
Import-Module -Name PSScriptAnalyzer -Force
$ScriptAnalyzerResult = Invoke-ScriptAnalyzer -Path $ModulePath -Recurse -ErrorAction Stop -ExcludeRule @("PSAvoidTrailingWhitespace")

if($ScriptAnalyzerResult){
    $ScriptAnalyzerResult
    Write-Error "Scripts contains errors. PSScriptAnalyzer provided results above."
}
#endregion

#region Build Manifest
$ExportableFunctions = (Get-ChildItem -Path "$ModulePath\Functions" -Filter '*.ps1').BaseName
$ReleaseNotes = ((Get-Content ".\ReleaseNotes.md" -Raw) -split "##")
$ReleaseNote = ($ReleaseNotes[1] + "`n`n To see the complete history, checkout the Release Notes on Github")

#Update Version
$ModuelManifestTest = Test-ModuleManifest -Path "$ModulePath\IntuneDocumentation.psd1" -ErrorAction Stop
$CurrentVersion = $ModuelManifestTest.Version
$SuggestedNewVersion = [Version]::new($CurrentVersion.Major,$CurrentVersion.Minor,$CurrentVersion.Build + 1)
$title = "Increment Version" 
$message = "Would you like to increase Module Version from $($CurrentVersion) to $($SuggestedNewVersion)?"
$result = $host.ui.PromptForChoice($title, $message, $options, 1)
switch ($result) {
    0{
        Write-Information "You selected yes to increase the version. Updating Mnaifest..."
        Update-ModuleManifest -Path "$ModulePath\IntuneDocumentation.psd1" `
            -FunctionsToExport $ExportableFunctions `
            -ReleaseNotes $ReleaseNote `
            -RequiredModules @("Microsoft.Graph.Intune","PSWord") `
            -IconUri $Icon `
            -ModuleVersion $SuggestedNewVersion
    }
    1{
        Write-Host "You selected no. The version will not be increased."
        Update-ModuleManifest -Path "$ModulePath\IntuneDocumentation.psd1" `
            -FunctionsToExport $ExportableFunctions `
            -ReleaseNotes $ReleaseNote `
            -RequiredModules @("Microsoft.Graph.Intune","PSWord") `
            -IconUri $Icon `
            -ModuleVersion $CurrentVersion
    }
    2{
        Write-Error "Canceled Publishing Process" -ErrorAction Stop
    }
}
Test-ModuleManifest -Path "$ModulePath\IntuneDocumentation.psd1" -ErrorAction Stop
#endregion

#region Sign Scripts
    Copy-Item -Path $ModulePath -Destination $env:TEMP -Recurse -Force
    $cert = get-item Cert:\CurrentUser\My\* -CodeSigningCert | Out-GridView -OutputMode Single
    $PSFiles = Get-ChildItem -Path $env:TEMP\IntuneDocumentation -Recurse | Where-Object {$_.Extension -eq ".ps1" -or $_.Extension -eq ".psm1"}
    foreach($PSFile in $PSFiles){
        Set-AuthenticodeSignature -Certificate $cert -TimestampServer http://timestamp.verisign.com/scripts/timstamp.dll -FilePath ($PSFile.FullName) -Verbose
    }
#endregion
$PSGallerAPIKey = Read-Host "Insert PSGallery API Key"
Publish-Module -Path $env:TEMP\IntuneDocumentation -NuGetApiKey $PSGallerAPIKey -IconUri $Icon -LicenseUri $License -Verbose
