param(
    [string]$DeviceId = '',
    [switch]$NoAttach
)
$ErrorActionPreference = 'Stop'
Push-Location -LiteralPath $PSScriptRoot
try {
    $sdkRoot = $env:ANDROID_HOME
    if (-not $sdkRoot) { $sdkRoot = $env:ANDROID_SDK_ROOT }
    if (-not $sdkRoot -and (Test-Path -LiteralPath 'android/local.properties')) {
        $sdkLine = Get-Content -LiteralPath 'android/local.properties' | Where-Object { $_.StartsWith('sdk.dir=') } | Select-Object -First 1
        if ($sdkLine) { $sdkRoot = $sdkLine.Substring(8).Replace('\\', '\').Replace('\:', ':') }
    }
    if (-not $sdkRoot) { $sdkRoot = Join-Path $env:LOCALAPPDATA 'Android/Sdk' }
    $adbExe = Join-Path $sdkRoot 'platform-tools/adb.exe'
    if (-not (Test-Path -LiteralPath $adbExe)) { throw 'ADB was not found. Set ANDROID_HOME to your Android SDK directory.' }
    if (-not $DeviceId) {
        $deviceRows = & $adbExe devices
        $connected = @($deviceRows | Where-Object { $_ -match '^emulator-\d+\s+device\s*$' } | ForEach-Object { ($_ -split '\s+')[0] })
        foreach ($candidate in $connected) {
            $avdName = & $adbExe -s $candidate emu avd name
            if ($avdName -contains 'TazeKal_API36') { $DeviceId = $candidate; break }
        }
        if (-not $DeviceId -and $connected.Count -eq 1) { $DeviceId = $connected[0] }
        if (-not $DeviceId) { throw 'Start TazeKal_API36 or select a connected emulator explicitly with -DeviceId.' }
    }
    Write-Host "Using emulator: $DeviceId"
    $abi = & $adbExe -s $DeviceId shell getprop ro.product.cpu.abi
    if ($LASTEXITCODE -ne 0 -or "$abi".Trim() -ne 'x86_64') { throw 'Start an x86_64 Android emulator and pass its ID with -DeviceId.' }
    $diskOutput = & $adbExe -s $DeviceId shell df -k /data
    if ($LASTEXITCODE -ne 0) { throw 'Could not read emulator storage.' }
    $diskRow = $diskOutput | Where-Object { $_ -match '^/dev/' } | Select-Object -First 1
    if (-not $diskRow) { throw 'Could not determine emulator free storage.' }
    $columns = $diskRow.Trim() -split '\s+'
    $freeMb = [math]::Floor([double]$columns[3] / 1024)
    Write-Host "Emulator free storage: $freeMb MB"
    if ($freeMb -lt 1024) { throw 'At least 1 GB free emulator storage is required. Free space manually or use a larger AVD. No app was uninstalled.' }
    $defines = @()
    if (Test-Path -LiteralPath 'config/local.json') { $defines = @('--dart-define-from-file=config/local.json') }
    flutter build apk --debug --split-per-abi --target-platform android-x64 @defines
    if ($LASTEXITCODE -ne 0) { throw 'Emulator APK build failed.' }
    # Do NOT use flutter run: it may uninstall an existing app after install failure.
    $previousErrorPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $installOutput = & $adbExe -s $DeviceId install -r 'build/app/outputs/flutter-apk/app-x86_64-debug.apk' 2>&1
        $installExit = $LASTEXITCODE
    } finally { $ErrorActionPreference = $previousErrorPreference }
    $installOutput | ForEach-Object { Write-Host $_ }
    if ($installExit -ne 0) { throw 'APK installation failed. Existing app/data were not automatically removed. Resolve storage or signing errors before retrying.' }
    & $adbExe -s $DeviceId shell am start -W -n 'com.tazekal.taze_kal/.MainActivity'
    if ($LASTEXITCODE -ne 0) { throw 'App could not be started.' }
    if (-not $NoAttach) {
        flutter attach -d $DeviceId @defines
        if ($LASTEXITCODE -ne 0) { throw 'App started, but the Flutter debugger could not attach.' }
    }
} finally {
    Pop-Location
}
