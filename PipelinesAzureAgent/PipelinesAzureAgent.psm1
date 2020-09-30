[DscResource()]
class PipelinesAzureAgent {
    [DscProperty(Key)]
    [String] $Name

    [DscProperty(Mandatory, Key)]
    [String] $DevOpsInstanceURL

    [DscProperty(Mandatory)]
    [String] $DevOpsInstanceName

    [DscProperty(Mandatory, Key)]
    [String] $PoolName

    [DscProperty()]
    [String] $AgentRootPath = 'C:\'

    [DscProperty()]
    [String] $CertificateBundlePath

    [DscProperty(Mandatory)]
    [String] $Authentication

    [DscProperty()]
    [PSCredential] $Token

    [DscProperty(Mandatory)]
    [String] $AgentDownloadUrl

    [DscProperty()]
    [Boolean] $RunAsService

    [DscProperty()]
    [Boolean] $RunAsAutoLogon

    [DscProperty()]
    [PScredential] $WindowsLogonAccount

    [PipelinesAzureAgent] Get()
    {
        $result = [PipelinesAzureAgent]::new()

        Write-Verbose "Getting list of existing agents."
        $agents = Get-CimInstance -ClassName win32_Service -Filter "Name LIKE 'vstsagent.%'"
        Write-Verbose "Found $($agents.Name -join ',')"

        $thisOne = $agents | Where-Object {
            $parts = $_.Name -split '\.' # Windows service name is 'vstsagent.[devops instance name].[agent name]
            return $parts[1] -eq $DevOpsInstanceName -and $parts[2] -eq $PoolName -and $parts[3] -eq $Name
        }

        if($thisOne) {
            Write-Verbose 'Found this agent'
            Write-Verbose 'Getting agent config data'
            # Agent configuration data is in [Path to agent folder]\.agent file. It is a hidden file.
            $base = Split-Path $thisOne.PathName.Replace('"','') -Parent
            $parent = Split-Path $base -Parent
            $agentConfigPath = Join-Path $parent '.agent'
            $config = ConvertFrom-Json (Get-Content -Path $agentConfigPath | Out-String)

            $result.DevOpsInstanceURL = $config.serverUrl
            $result.Name = $config.agentName
        }

        return $result
    }

    [bool] Test()
    {
        $state = $this.Get()
        return $state.Name -eq $this.Name
    }

    [void] Set()
    {
        $agentZipPath = (Join-Path $ENV:TEMP ([System.GUID]::NewGuid().Guid)) + '.zip'
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
        Write-Verbose 'Downloading agent'
        Invoke-WebRequest $this.AgentDownloadUrl -OutFile $agentZipPath

        Write-Verbose 'Extracting agent'
        $agentPath = Join-Path $this.AgentRootPath $this.Name
        Expand-Archive -LiteralPath $agentZipPath -DestinationPath $agentPath -Force
        Remove-Item $agentZipPath -Force

        Write-Verbose 'Building configuration arguments'
        $cmdArgs = @(
            '--url', $this.DevOpsInstanceURL,
            '--pool', "`"$($this.PoolName)`"",
            '--replace',
            '--agent', $this.Name,
            '--auth', $this.Authentication,
            '--unattended'
        )

        if($this.CertificateBundlePath) {
            $cmdArgs += '--sslcacert', $this.CertificateBundlePath
        }
        if($this.WindowsLogonAccount) {
            $cmdArgs += '--windowsLogonAccount', $this.WindowsLogonAccount.Username
        }
        if($this.RunAsService) {
            $cmdArgs += '--runAsService'
        }
        if($this.RunAsAutoLogon) {
            $cmdArgs += '--runAsAutoLogon'
        }

        $cmdArgs | ConvertTo-Json | Out-String | Write-Verbose

        # Exclude sensitive data from logs.
        if($this.Authentication -eq 'pat') {
            $cmdArgs += '--token', $this.Token.GetNetworkCredential().Password
        }
        if($this.WindowsLogonAccount) {
            $cmdArgs += '--windowsLogonPassword', $this.WindowsLogonAccount.GetNetworkCredential().Password
        }
        # End of sensitive data exclusion from logs.

        $cmdArgs += '2>&1' # Redirect the errors to the standard output for capturing and logging.

        Write-Verbose 'Configuring agent'
        $outputLogPath = (Join-Path $ENV:TEMP ([System.GUID]::NewGuid().Guid)) + '.txt'
        Start-Process -FilePath $AgentPath/config.cmd -ArgumentList $cmdArgs -Wait -NoNewWindow -RedirectStandardOutput $outputLogPath
        Get-Content -Path $outputLogPath | Write-Verbose
        Remove-Item $outputLogPath
    }
}