[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$AzSubscriptionId,
    [Parameter(Mandatory = $true)]
    [string]$AzResourceGroup,
    [Parameter(Mandatory = $true)]
    [string]$AzZoneName,
    [string]$SetVerification,
    [switch]$SetSPF,
    [switch]$SetMX,
    [string]$SetDKIM1,
    [string]$SetDKIM2,
    [string]$SetDKIM3,
    [switch]$SetDMARC,
    [switch]$CreateDnsZone,
    [string]$CreateLocation='eastus'
)

#requires -Modules @{ ModuleName="Az.Dns"; ModuleVersion="1.1.2" }
Set-StrictMode -Version 'Latest'
$ErrorActionPreference = 'Stop'

$script:VerificationKey = 'protonmail-verification'
$script:SpfKey = 'v'
$script:SpfValue = 'spf1 include:_spf.protonmail.ch mx ~all'
$script:Mx10Value = 'mail.protonmail.ch'
$script:Mx20Value = 'mailsec.protonmail.ch'
$script:Dkim1Key = 'protonmail._domainkey'
$script:Dkim2Key = 'protonmail2._domainkey'
$script:Dkim3Key = 'protonmail3._domainkey'
$script:DmarcName = '_dmarc'
$script:DmarcKey = 'v'
$script:DmarcValue = "DMARC1; p=none"
$script:dnsZone = $null
$script:txt = $null
$script:mx = $null
$script:dkim1 = $null
$script:dkim2 = $null
$script:dkim3 = $null
$script:dmarc = $null

function Get-ProtonMailDnsObjects {
    try {
        Select-AzSubscription -SubscriptionId $AzSubscriptionId -ErrorAction Stop | Out-Null
    }
    catch {
        throw
    }
    
    $script:dnsZone = Get-AzDnsZone -Name $AzZoneName -ResourceGroup $AzResourceGroup -ErrorAction SilentlyContinue
    if (!$dnsZone) {
        if (!$CreateDnsZone) {
            Write-Error "DNS zone not found: $AzSubscriptionId/$AzResourceGroup/$AzZoneName"
            return $null
        }
        $group = Get-AzResourceGroup -Name $AzResourceGroup -ErrorAction SilentlyContinue
        if (!$group) {
            $group = New-AzResourceGroup -Name $AzResourceGroup -Location $CreateLocation -ErrorAction Stop
        }
        $dnsZone = New-AzDnsZone -Name $AzZoneName -ResourceGroupName $AzResourceGroup -ErrorAction Stop
        $script:SetSPF = $true
        $script:SetMX = $true
        $script:SetDMARC= $true
    }
    
    $script:txt = Get-AzDnsRecordSet -Zone $dnsZone -RecordType TXT -Name '@' -ErrorAction SilentlyContinue
    $script:mx = Get-AzDnsRecordSet -Zone $dnsZone -RecordType MX -Name '@'  -ErrorAction SilentlyContinue
    $script:dkim1 = Get-AzDnsRecordSet -Zone $dnsZone -RecordType CNAME -Name $Dkim1Key  -ErrorAction SilentlyContinue
    $script:dkim2 = Get-AzDnsRecordSet -Zone $dnsZone -RecordType CNAME -Name $Dkim2Key -ErrorAction SilentlyContinue
    $script:dkim3 = Get-AzDnsRecordSet -Zone $dnsZone -RecordType CNAME -Name $DKim3Key  -ErrorAction SilentlyContinue
    $script:dmarc = Get-AzDnsRecordSet -Zone $dnsZone -RecordType TXT -Name $DmarcName  -ErrorAction SilentlyContinue

    Write-Verbose "Zone=$($dnsZone | Out-String)"
    Write-Verbose "TXT=$($txt | Out-String)"
    Write-Verbose "MX=$($mx | Out-String)"
    Write-Verbose "DKIM1=$($dkim1 | Out-String)"
    Write-Verbose "DKIM1=$($dkim2 | Out-String)"
    Write-Verbose "DKIM1=$($dkim3 | Out-String)"
    Write-Verbose "DMARC=$($dmarc | Out-String)"
}

function Get-ProtonMailDnsSettings() {
 
    $verification = ""
    $spf = ""
    
    if ($txt) {
        $verification = $txt.Records.Value | Where-Object { $_.StartsWith("$VerificationKey=") }
        $spf = $txt.Records.Value | Where-Object { $_.StartsWith("$SpfKey=") }
    }
    
    $mxRecords = @()
    if ($mx) {
        foreach ($mxRecord in $mx.Records) {
            $mxRecords += "$($mxRecord.Exchange) [$($mxRecord.Preference )]"
        }
    }
    for ($count = 2 - $mxRecords.Length; $count -gt 0; $count--) {
        $mxRecords += ""
    }
    
    $dkimCnames = @() 
    foreach ($dkim in $dkim1, $dkim2, $dkim3) {
        if ($dkim) { 
            $dkimCnames += $dkim.Records[0].Cname
        }
        else {
            $dkimCnames += ""
        }
    }
    
    $dmarcRecordValue = ""
    if ($dmarc) {
        $dmarcRecordValue = $dmarc.Records[0].Value
    }
    
    [PSCustomObject]@{
        Domain       = $AzZoneName
        Verificaiton = $verification
        SPF          = $spf
        MX1          = $mxRecords[0]
        MX2          = $mxRecords[1]
        DKIM1        = $dkimCnames[0]
        DKIM2        = $dkimCnames[1]
        DKIM3        = $dkimCnames[2]
        DMARC        = $dmarcRecordValue
    }
}

function Set-ProtonMailDKimRecord(
    [Microsoft.Azure.Commands.Dns.DnsRecordSet]$RecordSet,
    [Parameter(Mandatory=$true)]
    [string]$CName,
    [Parameter(Mandatory=$true)]
    [string]$Value) {

    $cnameRecord = New-AzDnsRecordConfig -Cname $Value
    
    if ($RecordSet) {
        $RecordSet.Records.Clear()
        $RecordSet.Records.Add($cnameRecord)
        Set-AzDnsRecordSet -RecordSet $RecordSet -Overwrite
    }
    else {
        $RecordSet = New-AzDnsRecordSet -ZoneName $AzZoneName -ResourceGroupName $AzResourceGroup -Name $CName -RecordType CNAME -DnsRecords $cnameRecord -Ttl 3600
    }

    $RecordSet
}

function Set-ProtonMailTxtValue(
    [Microsoft.Azure.Commands.Dns.DnsRecordSet]$RecordSet,
    [string]$Name='@',
    [Parameter(Mandatory=$true)]
    [string]$Key,
    [Parameter(Mandatory=$true)]
    [string]$Value
) {
    $txtRecord = New-AzDnsRecordConfig -Value "$Key=$Value"

    if ($RecordSet) {
        $records = @($recordSet.Records)
        $records | Where-Object { $_.Value.StartsWith("$Key=") } | ForEach-Object { 
            $recordSet.Records.Remove($_)
        }
        $recordSet.Records.Add($txtRecord)
        Set-AzDnsRecordSet -RecordSet $RecordSet -Overwrite
    }
    else {
        $RecordSet = New-AzDnsRecordSet -ZoneName $AzZoneName -ResourceGroupName $AzResourceGroup -Name $Name -RecordType TXT -DnsRecords $txtRecord -Ttl 3600
    }

    $RecordSet
}


Get-ProtonMailDnsObjects
$settings = Get-ProtonMailDnsSettings
Write-Verbose "Current settings $($settings | Format-List | Out-String)"

if ($SetVerification) {
    Write-Verbose "Setting TXT @ $VerificationKey=$SetVerification"
    $txt = Set-ProtonMailTxtValue -RecordSet $txt -Key $VerificationKey -Value $SetVerification
}

if ($SetSPF) {
    Write-Verbose "Setting TXT @ $SpfKey=$SpfValue"
    $txt = Set-ProtonMailTxtValue -RecordSet $txt -Key $SpfKey -Value $SpfValue
}

if ($SetMX) {
    if ($mx) {
        Remove-AzDnsRecordSet -RecordSet $mx
    }
    $mx10 = New-AzDnsRecordConfig -Exchange $Mx10Value -Preference 10
    $mx20 = New-AzDnsRecordConfig -Exchange $Mx20Value -Preference 20
    $mx = New-AzDnsRecordSet -ZoneName $AzZoneName -ResourceGroupName $AzResourceGroup -Name '@' -RecordType MX -DnsRecords $mx10,$mx20 -Ttl 3600
}

if ($SetDKIM1) {
    Write-Verbose "Setting CNAME $Dkim1Key = $SetDKIM1"
    $dkim1 = Set-ProtonMailDKimRecord -RecordSet $dkim1 -CName $Dkim1Key -Value $SetDKIM1
}

if ($SetDKIM2) {
    Write-Verbose "Setting CNAME $Dkim2Key = $SetDKIM2"
    $dkim2 = Set-ProtonMailDKimRecord -RecordSet $dkim2 -CName $Dkim2Key -Value $SetDKIM2
}

if ($SetDKIM3) {
    Write-Verbose "Setting CNAME $Dkim3Key = $SetDKIM3"
    $dkim3 = Set-ProtonMailDKimRecord -RecordSet $dkim3 -CName $Dkim3Key -Value $SetDKIM3
}

if ($SetDMARC) {
    Write-Verbose "Setting TXT $DmarcName $DmarcKey=$DmarcValue"
    $dmarc = Set-ProtonMailTxtValue -RecordSet $dmarc -Name $DmarcName -Key $DmarcKey -Value $DmarcValue
}

Get-ProtonMailDnsObjects
Get-ProtonMailDnsSettings
