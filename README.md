# pipelines-azure-agent-dsc

DSC resource for installing and configuring an Azure Pipelines agent.

## Example usage

PipelinesAzureAgent FirstAgent
{
    Authentication = 'pat'
    DevOpsInstanceName = 'Contoso'
    DevOpsInstanceURL = 'https://dev.azure.com/contoso'
    Name = 'ServerAgent01'
    PoolName = 'SelfHostedPool'
    AgentDownloadUrl = 'https://vstsagentpackage.azureedge.net/agent/2.158.0/vsts-agent-win-x64-2.158.0.zip'
    Token = $credentialWithYourToken
}

## Attributes

* [String] Name
* [String] DevOpsInstanceURL
* [String] DevOpsInstanceName
* [String] PoolName
* [String] AgentRootPath = 'C:\'
* [String] CertificateBundlePath
* [String] Authentication
* [PSCredential] Token
* [String] AgentDownloadUrl
