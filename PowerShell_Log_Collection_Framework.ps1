#requires -Version 5.1
<#
.SYNOPSIS
    PowerShell Support Evidence Framework.
.DESCRIPTION
    Read-only support evidence reporter for Windows systems.
#>
[CmdletBinding()]
param([int]$Hours=24,[string]$OutputPath)
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
if([string]::IsNullOrWhiteSpace($OutputPath)){$OutputPath=Join-Path ([Environment]::GetFolderPath('Desktop')) 'Support_Evidence_Reports'}
$root=Join-Path $OutputPath "Evidence_$env:COMPUTERNAME`_$stamp"
New-Item -Path $root -ItemType Directory -Force|Out-Null
function Export-Data{param($Name,$Data)$Data|Export-Csv (Join-Path $root "$Name.csv") -NoTypeInformation -Encoding UTF8;$Data|ConvertTo-Json -Depth 6|Set-Content (Join-Path $root "$Name.json") -Encoding UTF8}
$os=Get-CimInstance Win32_OperatingSystem
$summary=[PSCustomObject]@{Computer=$env:COMPUTERNAME;OS=$os.Caption;Build=$os.BuildNumber;LastBoot=$os.LastBootUpTime;Generated=Get-Date;Hours=$Hours}
Export-Data 'system_summary' @($summary)
$start=(Get-Date).AddHours(-1*$Hours)
$system=Get-WinEvent -FilterHashtable @{LogName='System';StartTime=$start;Level=1,2,3} -ErrorAction SilentlyContinue|Select-Object -First 200 TimeCreated,Id,ProviderName,LevelDisplayName,Message
$application=Get-WinEvent -FilterHashtable @{LogName='Application';StartTime=$start;Level=1,2,3} -ErrorAction SilentlyContinue|Select-Object -First 200 TimeCreated,Id,ProviderName,LevelDisplayName,Message
$system|Export-Csv (Join-Path $root 'system_events.csv') -NoTypeInformation -Encoding UTF8
$application|Export-Csv (Join-Path $root 'application_events.csv') -NoTypeInformation -Encoding UTF8
$top=($system+$application)|Group-Object ProviderName|Sort-Object Count -Descending|Select-Object -First 20 Count,Name
Export-Data 'top_event_providers' $top
$html="<h1>Support Evidence - $env:COMPUTERNAME</h1><p>Generated $(Get-Date)</p><h2>Summary</h2>$(@($summary)|ConvertTo-Html -Fragment)<h2>Top Providers</h2>$($top|ConvertTo-Html -Fragment)"
$html|ConvertTo-Html -Title 'Support Evidence'|Set-Content (Join-Path $root 'support_evidence.html') -Encoding UTF8
Write-Host "Reports saved to: $root" -ForegroundColor Green
