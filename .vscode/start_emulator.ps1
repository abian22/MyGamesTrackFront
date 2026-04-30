param(
  [string]$AvdId = "Pixel_8",
  [int]$TimeoutSeconds = 120,
  [string]$AppId = "com.example.mygamestrack"
)

Write-Host "Starting emulator: $AvdId"

# Launch emulator (may take a while)
flutter emulators --launch $AvdId 2>&1 | Write-Host

$adb = "C:\Users\abian\AppData\Local\Android\Sdk\platform-tools\adb.exe"
if (-not (Test-Path $adb)) {
  $adb = "adb"
}

$start = [DateTime]::UtcNow
while (([DateTime]::UtcNow - $start).TotalSeconds -lt $TimeoutSeconds) {
  $adbDevices = & $adb devices 2>$null
  $flutterDevices = flutter devices 2>$null

  # AVD name (Pixel_8) often differs from runtime id (emulator-5554).
  if ($adbDevices -match "emulator-\d+\s+device" -and $flutterDevices -match "emulator-\d+") {
    Write-Host "Emulator '$AvdId' is connected and visible to Flutter."

    # Prevent INSTALL_FAILED_INSUFFICIENT_STORAGE on repeated runs.
    Write-Host "Cleaning previous app install and trimming cache..."
    & $adb uninstall $AppId 2>$null | Out-Null
    & $adb shell pm trim-caches 1G 2>$null | Out-Null

    exit 0
  }
  Start-Sleep -Seconds 2
}

Write-Error "Timed out waiting for emulator '$AvdId' to be visible in ADB/Flutter."
exit 1
