<#
  Script for uninstalling AKS EE
  Example invocation:
  .\Uninstall-AksEE.ps1
#>

#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

# This is needed becayse the AKS Edge PS module doesn't honor the $ErrorActionPreference
$PSDefaultParameterValues = @{"*:ErrorAction" = $ErrorActionPreference}
Set-PSDebug -Strict

if (! [Environment]::Is64BitProcess) {
    throw "[$(Get-Date -Format t)] ERROR: Run this script in a 64 bit PowerShell session."
}

if (Get-Module -ListAvailable -Name "AKSEdge") {
    if (Test-AksEdgeDeployment) {
        Remove-AksEdgeDeployment -Force
    }
    else {
        Write-Output "[$(Get-Date -Format t)] INFO: k3s cluster is not deployed."
    }
}
else {
    Write-Output "[$(Get-Date -Format t)] INFO: AKS EE PS Module not found."
}

$aksEEProductName = "AKS Edge Essentials - K3s"
Write-Output "[$(Get-Date -Format t)] INFO: Detecting installation of '$aksEEProductName'..."

$aksEEProduct = Get-CimInstance -ClassName Win32_Product | Where-Object { $_.Name -eq $aksEEProductName }

if ($aksEEProduct) {
    Write-Output "[$(Get-Date -Format t)] INFO: Found '$aksEEProduct'. Uninstalling now..."
    Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $($aksEEProduct.IdentifyingNumber) /qn" -Wait -NoNewWindow
    Write-Output "[$(Get-Date -Format t)] INFO: Uninstallation of '$aksEEProductName' completed successfully."
}
else {
    Write-Output "[$(Get-Date -Format t)] INFO: '$aksEEProductName' is not installed."
}