# AKS Edge Essentials with TLS termination proxy

![Build & Test](https://github.com/azure-samples/azure-edge-extensions-aksee-proxy-certs/actions/workflows/build.yaml/badge.svg)

This repository contains PowerShell script that demonstrates how to provision [AKS Edge Essentials (AKS EE)](https://learn.microsoft.com/en-us/azure/aks/hybrid/aks-edge-overview) single node Linux [k3s](https://k3s.io/) cluster with configuration of a proxy requiring TLS termination.

## Features

This project utilizes PowerShell to achieve the following:

* Downloads and installs AKS EE on a Windows host
* Creates a single node Linux k3s cluster with a default configuration
* Exports the specified proxy root CA cert from the Windows host local machine store
* Converts the exported cert to the [PEM format](https://en.wikipedia.org/wiki/Privacy-Enhanced_Mail) and copies it to the AKS EE Linux node
* [Updates the ca trust store](https://www.linux.org/docs/man8/update-ca-trust.html) and restarts the k3s service on the AKS EE Linux node

## Getting Started

### Prerequisites

The requirements for the host machine that runs AKS EE can be found [here](https://learn.microsoft.com/en-us/azure/aks/hybrid/aks-edge-system-requirements#hardware-requirements).

The PowerShell script needs to be run with administrative privileges.

### Installation

```powershell
.\Install-AksEE.ps1 `
  -aksEdgeMsiUrl "https://aka.ms/aks-edge/k3s-msi" `
  -InstallDir "C:\Program Files\AksEdge" `
  -VhdxDir "C:\Program Files\AksEdge" `
  -proxyCertName "Microsoft Root Certificate Authority 2011"
```

For demo purposes the script uses a pre-installed CA cert on the Windows host. In prod environments, you should use your own custom proxy root CA cert, which needs to be imported into the Windows host Local Machine Store->Trusted Root Cert Authorities.

>Note: [Additional steps](https://learn.microsoft.com/en-us/cli/azure/use-cli-effectively?tabs=bash%2Cbash2#work-behind-a-proxy) are required if you intend to use Azure CLI on the Windows host, over a proxy server.

### Uninstallation

`.\Uninstall-AksEE.ps1`
