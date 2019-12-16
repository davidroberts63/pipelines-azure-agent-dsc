[DscResource()]
class PipelinesAzureAgent {
    [DscProperty(Key)]
    [String] $Name

    [DscProperty(Mandatory)]
    [String] $DevOpsInstanceURL

    [DscProperty(Mandatory)]
    [String] $DevOpsInstanceName

    [DscProperty(Mandatory)]
    [String] $PoolName

    [DscProperty()]
    [String] $AgentRootPath = 'C:\'

    [DscProperty()]
    [String] $CertificateBundlePath

    [DscProperty(Mandatory)]
    [String] $Authentication

    [DscProperty()]
    [PSCredential] $Token

    [DscProperty()]
    [String] $AgentDownloadUrl

    [PipelinesAzureAgent] Get()
    {
        # Assume an empty (non-existent) agent.
        $result = [PipelinesAzureAgent]::new()

        Write-Verbose "Getting list of existing agents."
        $agents = Get-CimInstance -ClassName win32_Service -Filter "Name LIKE 'vstsagent.%'"
        Write-Verbose "Found $($agents.Name -join ',')"

        $thisOne = $agents | Where-Object {
            # Windows service name is 'vstsagent.[devops instance name].[agent name]
            $parts = $_.Name -split '\.'
            return $parts[1] -eq $DevOpsInstanceName -and $parts[2] -eq $Name
        }

        if($thisOne) {
            Write-Verbose 'Found this agent'
            Write-Verbose 'Getting agent config data'

            # Determining the folder path where the agent exe and config data resides.
            # Take out double quotes because service PathName property can be enclosed
            # in double quotes (which honestly is annoying in a string variable).
            $base = Split-Path $thisOne.PathName.Replace('"','') -Parent
            $parent = Split-Path $base -Parent

            # Get some of the config data from that agent install and populate the
            # result to get it to match the installed agent as much as possible.
            $agentConfigPath = Join-Path $parent '.agent'
            $config = ConvertFrom-Json (Get-Content -Path $agentConfigPath | Out-String)

            $result.DevOpsInstanceURL = $config.serverUrl
            $result.Name = $config.agentName
        }

        return $result
    }

    [bool] Test()
    {
        # For now simple name check. But should expand this to also include other
        # properties such as server url.
        $state = $this.Get()
        return $state.Name -eq $this.Name
    }

    [void] Set()
    {
        # Some environments may not have newer TLS enabled by default, so force it here.
        $agentZipPath = (Join-Path $ENV:TEMP ([System.GUID]::NewGuid().Guid)) + '.zip'
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        Write-Verbose 'Downloading agent'
        Invoke-WebRequest $this.AgentDownloadUrl -OutFile $agentZipPath

        Write-Verbose 'Extracting agent'
        $agentPath = Join-Path $this.AgentRootPath $this.Name
        Expand-Archive -LiteralPath $agentZipPath -DestinationPath $agentPath -Force
        Remove-Item $agentZipPath -Force

        Write-Verbose 'Configuring agent'
        $cmdArgs = @(
            '--sslcacert', $this.CertificateBundlePath,
            '--url', $this.DevOpsInstanceURL,
            '--pool', "`"$($this.PoolName)`"",
            '--replace',
            '--agent', $this.Name,
            '--auth', $this.Authentication,
            '--runAsService',
            '--unattended'
        )

        $cmdArgs | ConvertTo-Json | Out-String | Write-Verbose
        $cmdArgs += '--token', $this.Token.GetNetworkCredential().Password # Exclude sensitive data from logs.
        $cmdArgs += '2>&1' # Redirect the errors to the standard output for capturing and logging.

        $outputLogPath = (Join-Path $ENV:TEMP ([System.GUID]::NewGuid().Guid)) + '.txt'
        Start-Process -FilePath $AgentPath/config.cmd -ArgumentList $cmdArgs -Wait -NoNewWindow -RedirectStandardOutput $outputLogPath
        Get-Content -Path $outputLogPath | Write-Verbose
        Remove-Item $outputLogPath
    }
}