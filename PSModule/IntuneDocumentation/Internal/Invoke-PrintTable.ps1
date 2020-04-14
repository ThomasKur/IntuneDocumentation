Function Invoke-PrintTable(){
    <#
    .SYNOPSIS
    This function is used to print the assignment information to the word file.
    .DESCRIPTION
    This function is used to print the assignment information to the word file. It also gets group names.
    .EXAMPLE
    Invoke-PrintAssignmentDetail -Assignments $assignment
    Prints the information from the Assignents Array
    .NOTES
    NAME: Invoke-TranslatePropertyName
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
            $Name = Format-MsGraphData $($p.Name)
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
            if($p.TypeNameOfValue -eq "System.Boolean"){
                $TranslationObject = New-Object PSObject -Property @{
                    Name = $TranslationValue
                    Section = " "
                    DataType = $p.TypeNameOfValue
                    ValueTrue = "Block"
                    ValueFalse = "Not Configured"
                }
            } else {
                $TranslationObject = New-Object PSObject -Property @{
                    Name = $TranslationValue
                    Section = " "
                    DataType = $p.TypeNameOfValue
                }
            }

            $translation | Add-Member Noteproperty -Name $p.Name -Value $TranslationObject -Force 
            $translation | ConvertTo-Json | Out-File -FilePath $TranslationFile -Force
        } else {   
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
        }
        $ht[$Name] = $Value
    }
    ($ht.GetEnumerator() | Sort-Object -Property Name | Select-Object Name,Value) | Add-WordTable -FilePath $FullDocumentationPath -AutoFitStyle Window -Design LightListAccent2
}