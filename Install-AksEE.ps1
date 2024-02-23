<#
  Script for provisioning AKS Edge Essentials with configuration of a proxy requiring TLS termination.
  Example invocation:
  .\Install-AksEE.ps1 `
    -aksEdgeMsiUrl "https://aka.ms/aks-edge/k3s-msi" `
    -InstallDir "C:\Program Files\AksEdge" `
    -VhdxDir "C:\Program Files\AksEdge" `
    -proxyCertName "Microsoft Root Certificate Authority 2011" `
    -InstallTools $true
#>
param(
  # AKS EE MSI URLs are documented here https://learn.microsoft.com/en-us/azure/aks/hybrid/aks-edge-howto-setup-machine#download-aks-edge-essentials
  [string] $aksEdgeMsiUrl = "https://aka.ms/aks-edge/k3s-msi",

  [String] $InstallDir = "C:\Program Files\AksEdge",
  [String] $VhdxDir = "C:\Program Files\AksEdge",
  [String] $proxyCertName = "Microsoft Root Certificate Authority 2011",
  [bool] $InstallTools = $true
)
#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

# This is needed becayse the AKS Edge PS module doesn't honor the $ErrorActionPreference
$PSDefaultParameterValues = @{"*:ErrorAction" = $ErrorActionPreference }
Set-PSDebug -Strict

$startTime = Get-Date
$startTimeString = $($startTime.ToString("yyMMdd-HHmm"))
$transcriptFile = "./aksedgeaio-$startTimeString.log"
Start-Transcript -Path $transcriptFile

if (! [Environment]::Is64BitProcess) {
  throw "[$(Get-Date -Format t)] ERROR: Run this script in a 64 bit PowerShell session."
}

# The Linux Node config is based on the Arc Jumpstart for AIO
# https://github.com/azure/AKS-Edge/blob/main/tools/scripts/AksEdgeQuickStart/AksEdgeQuickStartForAio.ps1#L106-L111
$aksedgeConfig = @"
{
  "SchemaVersion": "1.9",
  "Version": "1.0",
  "DeploymentType": "SingleMachineCluster",
  "Init": {
    "ServiceIPRangeSize": 10
  },
  "Network": {
    "NetworkPlugin": "flannel",
    "Ip4AddressPrefix": null,
    "InternetDisabled": false,
    "SkipDnsCheck": false,
    "Proxy": {
      "Http": null,
      "Https": null,
      "No": "localhost,127.0.0.0/8,192.168.0.0/16,172.17.0.0/16,10.42.0.0/16,10.43.0.0/16,10.96.0.0/12,10.244.0.0/16,.svc"
    }
  },
  "User": {
    "AcceptEula": true,
    "AcceptOptionalTelemetry": true,
    "VolumeLicense": {
      "EnrollmentID": null,
      "PartNumber": null
    }
  },
  "Machines": [
    {
      "LinuxNode": {
        "CpuCount": 4,
        "MemoryInMB": 10240,
        "DataSizeInGB": 40,
        "LogSizeInGB": 5,
        "TimeoutSeconds": 300,
        "TpmPassthrough": false,
        "SecondaryNetworks": [
          {
            "VMSwitchName": null,
            "Ip4Address": null,
            "Ip4GatewayAddress": null,
            "Ip4PrefixLength": null
          }
        ]
      }
    }
  ]
}
"@

# Download AKS EE
if (-not (Get-Module -ListAvailable -Name "AKSEdge")) {
  $aksEdgeMsiFilePath = "./AksEdge-k3s.msi"
  if (-not (Test-Path $aksEdgeMsiFilePath)) {
    Invoke-WebRequest -Uri $aksEdgeMsiUrl -OutFile $aksEdgeMsiFilePath
  }
  else {
    Write-Output "[$(Get-Date -Format t)] INFO: AKS EE k3s installer already found."
  }

  # Install AKS EE
  Write-Output "[$(Get-Date -Format t)] INFO: Installing AKS EE k3s..."
  $msiInstallLog = "./akseek3s-$startTimeString.log"
  Start-Process -FilePath $aksEdgeMsiFilePath -ArgumentList "/quiet /log `"$msiInstallLog`" INSTALLDIR=`"$InstallDir`" VHDXDIR=`"$VhdxDir`"" -Wait
}
else {
  Write-Output "[$(Get-Date -Format t)] INFO: AKS EE k3s is already installed."
}

# k3s cluster
if (-not (Test-AksEdgeDeployment)) {
  Write-Output "[$(Get-Date -Format t)] INFO: Creating AKS EE K3S cluster deployment ..."
  Install-AksEdgeHostFeatures -Force
  New-AksEdgeDeployment -JsonConfigString $aksedgeConfig -Force

  if (-not (Test-AksEdgeDeployment)) {
    throw "[$(Get-Date -Format t)] ERROR: Failed to create AKS EE K3s cluster deployment."
  }
}
else {
  Write-Output "[$(Get-Date -Format t)] INFO: k3s cluster already exists."
}

# Proxy Root CA
$proxyCertFileName = "proxy-root-ca.pem"
$proxyCertLinuxPath = "/etc/pki/ca-trust/source/anchors/$proxyCertFileName"

$proxyCertSubject = Invoke-AksEdgeNodeCommand -NodeType "Linux" -command "test -f $proxyCertLinuxPath && sudo openssl x509 -in $proxyCertLinuxPath -subject || echo ''"

if (-not ($proxyCertSubject -like "*$proxyCertName*")) {
  Write-Output "[$(Get-Date -Format t)] INFO: Updating AKS EE Linux Node with '$proxyCertName'..."

  if (-not (Test-Path "./$proxyCertFileName")) {
    Write-Output "[$(Get-Date -Format t)] INFO: Exporting '$proxyCertName' from Trusted Root Cert Authorities in PEM format."

    $proxyCert = Get-ChildItem -Path "Cert:\LocalMachine\Root" | Where-Object { $_.Subject -like "*$proxyCertName*" }
    if (-not $proxyCert) {
      throw "[$(Get-Date -Format t)] ERROR: '$proxyCertName' not found in the Trusted Root Cert Authorities."
    }

    $proxyCertPem = @(
      '-----BEGIN CERTIFICATE-----'
      [System.Convert]::ToBase64String($proxyCert.RawData, 'InsertLineBreaks')
      '-----END CERTIFICATE-----'
    )

    $proxyCertPem | Out-File -FilePath "./$proxyCertFileName" -Encoding ascii
  }
  else {
    Write-Output "[$(Get-Date -Format t)] INFO: $proxyCertFileName already exists on Windows host. Skipping export."
  }

  Copy-AksEdgeNodeFile -FromFile "./$proxyCertFileName" -ToFile "~/$proxyCertFileName" -PushFile -NodeType Linux
  Invoke-AksEdgeNodeCommand -NodeType "Linux" -command "sudo cp ~/$proxyCertFileName $proxyCertLinuxPath"
  Invoke-AksEdgeNodeCommand -NodeType "Linux" -command "sudo update-ca-trust"
  Invoke-AksEdgeNodeCommand -NodeType "Linux" -command "sudo systemctl restart k3s"
}
else {
  Write-Output "[$(Get-Date -Format t)] INFO: '$proxyCertName' already exists in the AKS EE Linux Node"
}

# Install tools
if ($InstallTools) {
  Write-Output "[$(Get-Date -Format t)] INFO: Installing tools ..."

  Invoke-Expression ((New-Object System.Net.WebClient).DownloadString("https://community.chocolatey.org/install.ps1"))
  choco install k9s flux kubernetes-helm git -y

  if (-not (Test-Path "./AKS-Edge")) {
    Import-Module $env:ChocolateyInstall\helpers\chocolateyProfile.psm1
    refreshenv # To refresh the path so git is available
    git clone https://github.com/Azure/AKS-Edge.git
  }
  else {
    Write-Output "[$(Get-Date -Format t)] INFO: AKS-Edge repo already exists, skipping clone ..."
  }
}
else {
  Write-Output "[$(Get-Date -Format t)] INFO: Skipping tools installation ..."
}

$endTime = Get-Date
$timeSpan = New-TimeSpan -Start $starttime -End $endtime
Write-Output "[$(Get-Date -Format t)] INFO: Deployment is complete. Deployment time was $($timeSpan.Hours) hour and $($timeSpan.Minutes) minutes."
Stop-Transcript