#requires -RunAsAdministrator
param(
    [string]$Distribution = 'Ubuntu',
    [switch]$SkipUbuntuInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Enable-FeatureIfNeeded {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FeatureName
    )

    $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName
    if ($feature.State -ne 'Enabled') {
        Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -All -NoRestart | Out-Null
        return $true
    }

    return $false
}

$rebootRequired = $false
$rebootRequired = (Enable-FeatureIfNeeded -FeatureName 'Microsoft-Windows-Subsystem-Linux') -or $rebootRequired
$rebootRequired = (Enable-FeatureIfNeeded -FeatureName 'VirtualMachinePlatform') -or $rebootRequired

wsl --set-default-version 2

$installedDistributions = @(wsl --list --quiet) | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
$installedUbuntuDistribution = $installedDistributions | Where-Object { $_ -like 'Ubuntu*' } | Select-Object -First 1

if (-not $SkipUbuntuInstall -and $null -eq $installedUbuntuDistribution) {
    wsl --install --distribution $Distribution --no-launch
    $rebootRequired = $true
}

Enable-PSRemoting -SkipNetworkProfileCheck -Force
Set-Service -Name WinRM -StartupType Automatic

Write-Host ''
Write-Host 'Bootstrap completato.'
Write-Host 'Passi successivi:'
Write-Host '1. Riavvia Windows se richiesto dalle feature WSL.'
Write-Host '2. Avvia la distro Ubuntu almeno una volta e completa la creazione dell''utente Linux.'
Write-Host '3. Installa Ansible dentro WSL Ubuntu e lancia il playbook da li.'
Write-Host '4. Le applicazioni Windows saranno installate dal playbook Ansible via winget, non da questo bootstrap.'
Write-Host ''
Write-Host ('WSL distro Ubuntu rilevata: {0}' -f $(if ($null -ne $installedUbuntuDistribution) { $installedUbuntuDistribution } else { 'nessuna, verra installata ' + $Distribution }))
Write-Host ('Riavvio consigliato: {0}' -f $(if ($rebootRequired) { 'yes' } else { 'no' }))
