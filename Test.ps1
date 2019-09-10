# Analyze(aka lint) then test

$result = Invoke-ScriptAnalyzer -Path ./PipelinesAzureAgent -Settings DSC
$result | Format-List Severity,RuleName,Message,ScriptName,Line