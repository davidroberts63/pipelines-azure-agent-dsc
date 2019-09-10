param(
    [Parameter(ParameterSetName='local', Mandatory=$true)]
    [switch]
    $Locally,

    [Parameter(ParameterSetName='public', Mandatory=$true)]
    [switch]
    $PowerShellGallery
)

$ErrorActionPreference = "STOP"

Import-Module PowerShellGet -ErrorAction SilentlyContinue
$powershellGet = Get-Module PowerShellGet
if(-not $powershellGet) {
    Write-Warning "Could not find the PowerShellGet module. 'Install-Module PowerShellGet' first."
} elseif($powershellGet.Version -lt "1.6.0") {
    Write-Warning "PowerShellGet 1.6.0 and greater is required. 'Install-Module PowerShellGet -Force' first."
    exit 1
}

if($Locally) {
    Write-Host "Publishing locally"
    $name = "LocalPipelinesAzureAgent"
    $path = "$PSScriptRoot\localgallery"

    if((Test-Path $path)) {
        Remove-Item $path -Recurse -Force | Out-Null
    }
    New-Item -Type Directory $path -Force | Out-Null
    Register-PSRepository -Name $name -SourceLocation $path -PublishLocation $path -InstallationPolicy Trusted
    Publish-Module -Path $PSScriptRoot\pipelinesazureagent -Repository $name
    Unregister-PSRepository -Name $name

    Write-Host "Published locally to $path"
}

if ($PowerShellGallery) {
    Publish-Module -Path $PSScriptRoot\pipelinesazureagent -NuGetApiKey $ENV:PowerShellGalleryApiKey
}