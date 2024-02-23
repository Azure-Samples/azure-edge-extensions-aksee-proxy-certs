# AKS Edge Essentials with TLS termination proxy

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

### Installation

`.\Install-AksEE.ps1`

### Uninstallation

`.\Uninstall-AksEE.ps1`
