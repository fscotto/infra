#requires -RunAsAdministrator
param(
    [string]$Distribution = 'Ubuntu',
    [switch]$SkipUbuntuInstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-OrCreate-WinRMHttpsCertificate {
    $dnsName = $env:COMPUTERNAME
    $existingCertificate = Get-ChildItem -Path Cert:\LocalMachine\My |
        Where-Object { $_.Subject -eq "CN=$dnsName" } |
        Sort-Object NotAfter -Descending |
        Select-Object -First 1

    if ($null -ne $existingCertificate) {
        return $existingCertificate
    }

    return New-SelfSignedCertificate `
        -DnsName $dnsName `
        -CertStoreLocation 'Cert:\LocalMachine\My' `
        -FriendlyName 'WinRM HTTPS Listener' `
        -KeyAlgorithm RSA `
        -KeyLength 2048 `
        -HashAlgorithm SHA256 `
        -NotAfter (Get-Date).AddYears(5)
}

function Ensure-WinRMHttpsListener {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CertificateThumbprint
    )

    $listener = Get-ChildItem -Path WSMan:\localhost\Listener |
        Where-Object {
            $_.Keys -match 'Transport=HTTPS'
        } |
        Select-Object -First 1

    if ($null -eq $listener) {
        try {
            New-WSManInstance -ResourceURI winrm/config/Listener `
                -SelectorSet @{ Transport = 'HTTPS'; Address = '*' } `
                -ValueSet @{ Hostname = $env:COMPUTERNAME; CertificateThumbprint = $CertificateThumbprint } | Out-Null
            return $true
        }
        catch {
            $existingHttpsListener = Get-ChildItem -Path WSMan:\localhost\Listener |
                Where-Object {
                    $_.Keys -match 'Transport=HTTPS'
                } |
                Select-Object -First 1

            if ($null -ne $existingHttpsListener) {
                return $false
            }

            throw
        }
    }

    return $false
}

function Test-WinRMHttpsListener {
    $listener = Get-ChildItem -Path WSMan:\localhost\Listener |
        Where-Object {
            $_.Keys -match 'Transport=HTTPS'
        } |
        Select-Object -First 1

    return $null -ne $listener
}

function Ensure-LocalAccountTokenFilterPolicy {
    $registryPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System'
    $propertyName = 'LocalAccountTokenFilterPolicy'
    $currentValue = Get-ItemProperty -Path $registryPath -Name $propertyName -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $propertyName -ErrorAction SilentlyContinue

    if ($currentValue -ne 1) {
        New-ItemProperty -Path $registryPath -Name $propertyName -Value 1 -PropertyType DWord -Force | Out-Null
        return $true
    }

    return $false
}

function Ensure-CurrentUserInRemoteManagementGroup {
    $groupName = 'Utenti gestione remota'
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $members = @(Get-LocalGroupMember -Name $groupName -ErrorAction Stop | Select-Object -ExpandProperty Name)

    if ($members -contains $currentUser) {
        return @{ Changed = $false; User = $currentUser; Group = $groupName }
    }

    Add-LocalGroupMember -Group $groupName -Member $currentUser -ErrorAction Stop
    return @{ Changed = $true; User = $currentUser; Group = $groupName }
}

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

$winrmCertificate = Get-OrCreate-WinRMHttpsCertificate
$httpsListenerChanged = Ensure-WinRMHttpsListener -CertificateThumbprint $winrmCertificate.Thumbprint
$rebootRequired = (Ensure-LocalAccountTokenFilterPolicy) -or $rebootRequired
$remoteManagementGroupState = Ensure-CurrentUserInRemoteManagementGroup

$httpsFirewallRule = Get-NetFirewallRule -DisplayName 'WinRM HTTPS (5986)' -ErrorAction SilentlyContinue
if ($null -eq $httpsFirewallRule) {
    New-NetFirewallRule -DisplayName 'WinRM HTTPS (5986)' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 5986 | Out-Null
}

if (-not (Test-WinRMHttpsListener)) {
    throw 'WinRM HTTPS listener was not created successfully. Verify certificate creation and WSMan listener configuration.'
}

Write-Host ''
Write-Host 'Bootstrap completato.'
Write-Host 'Passi successivi:'
Write-Host '1. Riavvia Windows se richiesto dalle feature WSL.'
Write-Host '2. Avvia la distro Ubuntu almeno una volta e completa la creazione dell''utente Linux.'
Write-Host '3. Installa Ansible dentro WSL Ubuntu e lancia il playbook da li.'
Write-Host '4. Le applicazioni Windows saranno installate dal playbook Ansible via winget, non da questo bootstrap.'
Write-Host ''
Write-Host ('WSL distro Ubuntu rilevata: {0}' -f $(if ($null -ne $installedUbuntuDistribution) { $installedUbuntuDistribution } else { 'nessuna, verra installata ' + $Distribution }))
Write-Host ('PSRP transport consigliato: https://{0}:5986/wsman' -f $env:COMPUTERNAME)
Write-Host ('Certificato WinRM HTTPS: {0}' -f $winrmCertificate.Thumbprint)
Write-Host ('Utente aggiunto a Utenti gestione remota: {0}' -f $remoteManagementGroupState.User)
Write-Host ('Listener HTTPS creato in questo run: {0}' -f $(if ($httpsListenerChanged) { 'yes' } else { 'no' }))
Write-Host ('Riavvio consigliato: {0}' -f $(if ($rebootRequired) { 'yes' } else { 'no' }))
