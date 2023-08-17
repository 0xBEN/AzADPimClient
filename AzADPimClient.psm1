$powershellGetCheck = Get-Module PowerShellGet -ListAvailable
if (-not $powershellGetCheck.RepositorySourceLocation) {
    try {
        Install-Module PowerShellGet -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        New-Variable -Name PowerShellGetRestartRequired -Value $true -Option Constant -Scope Global
        do 
        {
            $prompt = Read-Host 'A new version of PowerShellGet was installed and PowerShell must be restarted. Enter YES to exit'
        }
        until ($prompt -ceq 'YES')
    }
    catch {
        throw $_
    }
}
if ($PowerShellGetRestartRequired) {
    throw 'A new version of PowerShellGet was installed and PowerShell must be restarted.'
}

if (-not (Get-Module -ListAvailable -Name AzureADPreview)) {     
    Install-Module AzureADPreview -Scope CurrentUser -AllowClobber -Force # Install AzureADPreview
}
else {
    if (Get-Module AzureAD) { Remove-Module AzureAD -Force } # We only want the cmdlets from AzureADPreview
    if (-not (Get-Module AzureADPreview)) { Import-Module AzureADPreview }
}

$directorySeparator = [System.IO.Path]::DirectorySeparatorChar
$moduleName = $PSScriptRoot.Split($directorySeparator)[-1]
$moduleManifest = $PSScriptRoot + $directorySeparator + $moduleName + '.psd1'
$publicFunctionsPath = $PSScriptRoot + $directorySeparator + 'Public' + $directorySeparator + 'ps1'
$privateFunctionsPath = $PSScriptRoot + $directorySeparator + 'Private' + $directorySeparator + 'ps1'
$currentManifest = Test-ModuleManifest $moduleManifest

$aliases = @()
$publicFunctions = Get-ChildItem -Path $publicFunctionsPath | Where-Object {$_.Extension -eq '.ps1'}
$privateFunctions = Get-ChildItem -Path $privateFunctionsPath | Where-Object {$_.Extension -eq '.ps1'}
$publicFunctions | ForEach-Object { . $_.FullName }
$privateFunctions | ForEach-Object { . $_.FullName }

$publicFunctions | ForEach-Object { # Export all of the public functions from this module

    # The command has already been sourced in above. Query any defined aliases.
    $alias = Get-Alias -Definition $_.BaseName -ErrorAction SilentlyContinue
    if ($alias) {
        $aliases += $alias
        Export-ModuleMember -Function $_.BaseName -Alias $alias
    }
    else {
        Export-ModuleMember -Function $_.BaseName
    }

}

$functionsAdded = $publicFunctions | Where-Object {$_.BaseName -notin $currentManifest.ExportedFunctions.Keys}
$functionsRemoved = $currentManifest.ExportedFunctions.Keys | Where-Object {$_ -notin $publicFunctions.BaseName}
$aliasesAdded = $aliases | Where-Object {$_ -notin $currentManifest.ExportedAliases.Keys}
$aliasesRemoved = $currentManifest.ExportedAliases.Keys | Where-Object {$_ -notin $aliases}

if ($functionsAdded -or $functionsRemoved -or $aliasesAdded -or $aliasesRemoved) {

    try {

        $updateModuleManifestParams = @{}
        $updateModuleManifestParams.Add('Path', $moduleManifest)
        $updateModuleManifestParams.Add('ErrorAction', 'Stop')
        if ($aliases.Count -gt 0) { $updateModuleManifestParams.Add('AliasesToExport', $aliases) }
        if ($publicFunctions.Count -gt 0) { $updateModuleManifestParams.Add('FunctionsToExport', $publicFunctions.BaseName) }

        Update-ModuleManifest @updateModuleManifestParams

    }
    catch {

        $_ | Write-Error

    }

}

# Module data cache   
$moduleDataCachePath = "~/Documents/WindowsPowerShell/Cache/$moduleName"
Set-Variable `
-Name AzureADPIMModuleCache `
-Scope Script `
-Option Constant `
-Value $moduleDataCachePath `
-Description "Base path for storing cache files used by this module" `
-ErrorAction SilentlyContinue

if (-not (Test-Path $moduleDataCachePath)) { 
    New-Item `
    -ItemType Directory `
    -Path $moduleDataCachePath `
    -Force | 
    Out-Null
}
