param(
  [string]$AvdId = "Pixel_8"
)

powershell -NoProfile -ExecutionPolicy Bypass -File "$PSScriptRoot\start_emulator.ps1" -AvdId $AvdId
if ($LASTEXITCODE -ne 0) {
  Write-Error "No se pudo iniciar el emulador."
  exit 1
}

$devicesOutput = flutter devices
$match = [regex]::Match($devicesOutput, "(emulator-\d+)")
if (-not $match.Success) {
  Write-Error "No se encontró un emulador Android conectado en 'flutter devices'."
  exit 1
}

$deviceId = $match.Groups[1].Value
Write-Host "Launching app on $deviceId ..."
flutter run -d $deviceId
