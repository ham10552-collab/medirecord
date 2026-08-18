# MediRecord deploy script: builds, copies to temp, verifies, then swaps into place.
# Usage: powershell -ExecutionPolicy Bypass -File deploy.ps1
$ErrorActionPreference = 'Stop'

$flutter = "C:\Users\abbas\flutter_sdk\bin\flutter.bat"
$env:JAVA_HOME = "C:\Users\abbas\jdk17"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"

$project = "C:\Users\abbas\OneDrive\Documents\Default Project\medirecord"
$release = Join-Path $project "build\windows\x64\runner\Release"
$target = "G:\MediRecord"
$temp = "G:\MediRecord.staging"
$backup = "G:\MediRecord.previous"

Write-Host "==> Building Windows release..."
Push-Location $project
& $flutter build windows --release --obfuscate --split-debug-info="$(Join-Path $project 'build\symbols')"
if ($LASTEXITCODE -ne 0) { throw "Build failed" }
Pop-Location

Write-Host "==> Stopping running app..."
Get-Process medirecord -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

Write-Host "==> Copying to staging (verified)..."
if (Test-Path $temp) { Remove-Item $temp -Recurse -Force }
robocopy $release $temp /MIR /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw "robocopy staging failed ($LASTEXITCODE)" }

# Verify critical files are non-zero and valid
$checks = @(
  @{ file = "data\flutter_assets\FontManifest.json"; min = 50 },
  @{ file = "data\flutter_assets\fonts\MaterialIcons-Regular.otf"; min = 1000000 },
  @{ file = "medirecord.exe"; min = 1000000 }
)
foreach ($c in $checks) {
  $p = Join-Path $temp $c.file
  if (-not (Test-Path $p)) { throw "Missing file: $($c.file)" }
  $len = (Get-Item $p).Length
  if ($len -lt $c.min) { throw "File too small ($len bytes): $($c.file)" }
  Write-Host "  OK $($c.file) ($len bytes)"
}

Write-Host "==> Swapping into place..."
if (Test-Path $backup) { Remove-Item $backup -Recurse -Force }
if (Test-Path $target) { [System.IO.Directory]::Move($target, $backup) }
[System.IO.Directory]::Move($temp, $target)
if (Test-Path $backup) { Remove-Item $backup -Recurse -Force }

Write-Host "==> Launching..."
Start-Process (Join-Path $target "medirecord.exe")
Start-Sleep -Seconds 6
if (Get-Process medirecord -ErrorAction SilentlyContinue) {
  Write-Host "DEPLOY OK - app running"
} else {
  Write-Host "WARNING: app did not stay running"
}
