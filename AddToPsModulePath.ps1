Write-Host 'Adding this module folder to the PSModule path for local testing'
$paths = $ENV:PSModulePath -split ';'
$paths += (Resolve-Path $PSScriptRoot).Path
$paths = $paths | Select-Object -Unique

$ENV:PSModulePath = $paths -join ';'