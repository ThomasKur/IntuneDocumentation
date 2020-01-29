$functionFolders = @('Functions', 'Internal')

# Importing all the Functions required for the module from the subfolders.
ForEach ($folder in $functionFolders) {
    $folderPath = Join-Path -Path $PSScriptRoot -ChildPath $folder
    If (Test-Path -Path $folderPath)
    {
        Write-Verbose -Message "Importing from $folder"
        $functions = Get-ChildItem -Path $folderPath -Filter '*.ps1'
        ForEach ($function in $functions)
        {
            Write-Verbose -Message "  Loading $($function.FullName)"
            . ($function.FullName)
        }
    } else {
         Write-Warning "Path $folderPath not found. Some parts of the module will not work."
    }
}

$PSWord = Get-Module -Name PSWord
if($PSWord){
    Write-Verbose -Message "PSWord module is loaded."
} else {
    Write-Warning -Message "PSWord module is not loaded, trying to import it."
    Import-Module -Name PSWord
}

$PSModuleIntune = Get-Module -Name Microsoft.Graph.Intune
if($PSModuleIntune){
    Write-Verbose -Message "Intune PowerShell module is loaded."
} else {
    Write-Warning -Message "Intune PowerShell module is not loaded, trying to import it."
    Import-Module -Name Microsoft.Graph.Intune
}