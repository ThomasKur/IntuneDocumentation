Function Invoke-PrintTableTranslate(){
<#
    .SYNOPSIS
    This function is used to print the configuration with translation to the word file.
    .EXAMPLE
    Invoke-TableTranslate -Properties $p -TypeName $t
    Prints the information from the Config Array
    .NOTES
    NAME: Invoke-TableTranslate
    #>
    param(
        [Parameter(Mandatory=$true)]
        $Properties,
        [Parameter(Mandatory=$true)]
        [String]$TypeName
    )
    $MaxStringLengthSettings = 350
    $ht = @{}
    $TranslationFile = "$PSScriptRoot\..\Data\LabelTranslation\$TypeName.json"

    $translateJson = Get-Content $TranslationFile -ErrorAction SilentlyContinue
    if($null -eq $translateJson){
        $translateJson = "{}"
    }
    $translation = $translateJson | ConvertFrom-Json

    foreach($p in $Properties) {   
        if([String]::IsNullOrWhiteSpace($translation."$($p.Name)")){
            $TranslationValue = switch($p.Name){
                "displayName" { "Displayname" }
                "lastModifiedDateTime" { "Modified at" }
                "@odata.type" { "OData Type" }
                "supportsScopeTags" { "Support for Scope Tags" }
                "roleScopeTagIds" {  "Role Scopes Tags" }
                "deviceManagementApplicabilityRuleOsEdition" {  "Applicability OS Edition" }
                "deviceManagementApplicabilityRuleOsVersion" {  "Applicability OS Version" }
                "deviceManagementApplicabilityRuleDeviceMode" {  "Applicability Device Mode" }
                "createdDateTime" {  "Created at" }
                "description" {  "Description" }
                "version" {  "Version" }
                "id" {'ID'}
                default { '' }   
            }
            if([String]::IsNullOrWhiteSpace($TranslationValue)){
                $Section = " "
            } else {
                $Section = "Metadata"
            }

            if($p.TypeNameOfValue -eq "System.Boolean"){
                $TranslationObject = New-Object PSObject -Property @{
                    Name = $TranslationValue
                    Section = $Section
                    DataType = $p.TypeNameOfValue
                    ValueTrue = "Block"
                    ValueFalse = "Not Configured"
                }
            } else {
                $TranslationObject = New-Object PSObject -Property @{
                    Name = $TranslationValue
                    Section = $Section
                    DataType = $p.TypeNameOfValue
                }
            }
            #Only use translated value if not empty
            if([String]::IsNullOrWhiteSpace($TranslationValue)){
                $Name = Convert-CamelCaseToDisplayName -Value $p.Name
            } else {
                $Name = $TranslationValue
            }
            $translation | Add-Member Noteproperty -Name $p.Name -Value $TranslationObject -Force 
            $translation | ConvertTo-Json | Out-File -FilePath $TranslationFile -Force
            #Variable set for user information in main function
            $Script:NewTranslationFiles += $TranslationFile
        } else { 
            #Only use translated value if not empty  
            if([String]::IsNullOrWhiteSpace($translation."$($p.Name)".Name)){
                $Name = $p.Name
            } else {
                $Name = $translation."$($p.Name)".Name
            }
            
        }
        
        # Value
        if($p.TypeNameOfValue -eq "System.Boolean"){
            if([String]::IsNullOrWhiteSpace($translation."$($p.Name)".Name)){
                $Value = $p.Value
            } else {
                if($p.Value -eq $true){
                    $Value = $translation."$($p.Name)".ValueTrue
                } else {
                    $Value = $translation."$($p.Name)".ValueFalse
                }
            }
        } else {
            if((Format-MsGraphData "$($p.Value)").Length -gt $MaxStringLengthSettings){
                $Value = "$((Format-MsGraphData "$($p.Value)").substring(0, $MaxStringLengthSettings))..."
            } else {
                $Value = "$((Format-MsGraphData "$($p.Value)")) "
            }
        }
        if($null -eq $Value){
            $Value = ""
        } elseif ($format -eq 'md') {
            # Markdown has rendering issues with new lines in a table
            $Value = ($Value -replace ('\r\n', '')) -replace ('\n','')
            # some oma setting values are in xml format, wrap this part to avoid rendering issues
            $pattern = [regex]'(.*)value=<(.*)'
            if ($Value -match $pattern) {
                $Value = $pattern.Replace($Value, '$1value=<code><$2</code>', 1)
            }
        }
        $ht[$Name] = $Value
    }
    Add-Table -InputObject ($ht.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) -format $format
}