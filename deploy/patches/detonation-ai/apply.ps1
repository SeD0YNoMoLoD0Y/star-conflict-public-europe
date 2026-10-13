param(
    [Parameter(Mandatory = $true)][string]$ServerDir
)

$ErrorActionPreference = "Stop"
$exe = Join-Path $ServerDir "cloud\DedicatedServer.exe"
$manifestPath = Join-Path $PSScriptRoot "patches.json"

function Convert-HexBytes([string]$Hex) {
    if (($Hex.Length % 2) -ne 0) { throw "Invalid hexadecimal patch data" }
    $result = New-Object byte[] ($Hex.Length / 2)
    for ($i = 0; $i -lt $result.Length; $i++) {
        $result[$i] = [Convert]::ToByte($Hex.Substring($i * 2, 2), 16)
    }
    return $result
}

if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) {
    throw "DedicatedServer.exe not found at '$exe'"
}
if (Get-Process -Name DedicatedServer -ErrorAction SilentlyContinue) {
    throw "DedicatedServer.exe is running. Stop battle servers before applying the patch."
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$inputHash = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
if ($inputHash -eq $manifest.outputSha256) {
    Write-Host "$($manifest.name) is already installed."
    return
}
if ($inputHash -ne $manifest.inputSha256) {
    throw "Unsupported DedicatedServer.exe SHA-256: $inputHash. Expected $($manifest.inputSha256)."
}

$bytes = [IO.File]::ReadAllBytes($exe)
if ($bytes.Length -ne [int64]$manifest.fileLength) {
    throw "Unsupported DedicatedServer.exe length: $($bytes.Length)"
}

foreach ($patch in $manifest.patches) {
    $offset = [int]$patch.offset
    $original = Convert-HexBytes $patch.original
    $replacement = Convert-HexBytes $patch.replacement
    if ($original.Length -ne $replacement.Length) {
        throw "Patch length mismatch at offset 0x$($offset.ToString('X'))"
    }
    for ($i = 0; $i -lt $original.Length; $i++) {
        if ($bytes[$offset + $i] -ne $original[$i]) {
            throw "Original bytes mismatch at offset 0x$(($offset + $i).ToString('X'))"
        }
    }
    [Array]::Copy($replacement, 0, $bytes, $offset, $replacement.Length)
}

$backup = "$exe.before-detonation-ai-$((Get-Date).ToString('yyyyMMdd-HHmmss')).bak"
Copy-Item -LiteralPath $exe -Destination $backup
[IO.File]::WriteAllBytes($exe, $bytes)

$outputHash = (Get-FileHash -LiteralPath $exe -Algorithm SHA256).Hash
if ($outputHash -ne $manifest.outputSha256) {
    Copy-Item -LiteralPath $backup -Destination $exe -Force
    throw "Patched hash mismatch; the original file was restored."
}

Write-Host "Installed $($manifest.name)."
Write-Host "Backup: $backup"
Write-Host "SHA-256: $outputHash"
