# One-time setup of the Star Conflict (Unofficial Server) on a Windows VPS.
# Run as Administrator:  powershell -ExecutionPolicy Bypass -File setup.ps1 -PublicIp <VPS IPv4>
param(
    [Parameter(Mandatory = $true)][string]$PublicIp,
    [string]$SteamGameDir = "C:\Program Files (x86)\Steam\steamapps\common\star conflict",
    [string]$ServerDir    = "C:\SC\server",
    [string]$DbDir        = "C:\SC\db",
    [string]$BackupDir    = "C:\SC\backups"
)
$ErrorActionPreference = "Stop"
$kit = $PSScriptRoot

if (-not (Test-Path "$SteamGameDir\cloud\Hub.exe")) { throw "Game not found in '$SteamGameDir'. Install Star Conflict via Steam first or pass -SteamGameDir." }

# 1. Copy the game out of Steam, so Steam updates/verification never touch the server
Write-Host "Copying game to $ServerDir ..."
New-Item -ItemType Directory -Force $ServerDir, $DbDir, $BackupDir | Out-Null
robocopy $SteamGameDir $ServerDir /E /COPY:DAT /R:1 /W:1 /MT:16 /NFL /NDL /NP | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy failed with code $LASTEXITCODE" }

# 2. Our changes on top of stock: tutorial premium (50 years) and flood threshold
Copy-Item "$kit\files\*" $ServerDir -Recurse -Force

# Apply the server-only Detonation bot fixes to the supported stock binary.
# The patcher verifies both input and output SHA-256 and keeps a local backup.
& "$kit\patches\detonation-ai\apply.ps1" -ServerDir $ServerDir

# 3. Advertise the public address to clients (cloud.xml defaults to 127.0.0.1)
$cloudXml = "$ServerDir\cloud\data\cloud.xml"
(Get-Content $cloudXml) -replace 'address="127\.0\.0\.1:3850"', "address=`"${PublicIp}:3850`"" | Set-Content $cloudXml -Encoding ASCII
if (-not (Select-String -Path $cloudXml -Pattern ([regex]::Escape("${PublicIp}:3850")) -Quiet)) { throw "Failed to set address in cloud.xml" }

# 4. Firewall: allow only what game clients need, explicitly block internal ports
Get-NetFirewallRule -DisplayName "SC *" -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName "SC allow client TCP" -Direction Inbound -Protocol TCP -LocalPort 3801,3802,3815 -Action Allow | Out-Null
New-NetFirewallRule -DisplayName "SC allow battles UDP" -Direction Inbound -Protocol UDP -LocalPort 35000-35050 -Action Allow | Out-Null
New-NetFirewallRule -DisplayName "SC block internal TCP" -Direction Inbound -Protocol TCP -LocalPort 3850,9001,2222,27017 -Action Block | Out-Null
New-NetFirewallRule -DisplayName "SC block internal UDP" -Direction Inbound -Protocol UDP -LocalPort 3850,9001,2222,27017 -Action Block | Out-Null

# 5. Daily database backup at 05:00, keeps the last 14
$action  = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$kit\backup.ps1`" -ServerDir `"$ServerDir`" -BackupDir `"$BackupDir`""
$trigger = New-ScheduledTaskTrigger -Daily -At 5am
Register-ScheduledTask -TaskName "SC daily backup" -Action $action -Trigger $trigger -RunLevel Highest -Force | Out-Null

Write-Host ""
Write-Host "Done. Start the server with:  powershell -ExecutionPolicy Bypass -File `"$kit\start.ps1`""
Write-Host "Clients connect to: $PublicIp port 3801 (login screen -> 'server')"
