$scriptPath = split-path -parent $MyInvocation.MyCommand.Definition
import-module "$scriptPath\IntuneDocumentation\IntuneDocumentation.psm1" -force
Connect-MSGraph -ForceInteractive
$rand = Get-Random -Minimum 0 -Maximum 100
Invoke-IntuneDocumentation -FullDocumentationPath "C:\temp\docu$rand.docx" -UseTranslationBeta
Write-Host "Created Documentation C:\temp\docu$rand.docx"5