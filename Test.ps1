$module = Get-Module -ListAvailable PSScriptAnalyzer
if(-not $module) {
    Write-Host 'PSScriptAnalyzer is not installed, installing it in user scope.'
    Install-Module PSScriptAnalyzer -Scope CurrentUser
}

$result = Invoke-ScriptAnalyzer -Path ./PipelinesAzureAgent -Settings DSC
$result | Format-List Severity,RuleName,Message,ScriptName,Line