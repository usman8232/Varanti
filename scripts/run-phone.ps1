# Forward port 8000 from USB-connected Android phone to local FastAPI backend and run Varanti
$ErrorActionPreference = "Stop"

$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
$flutter = "D:\flutter\bin\flutter.bat"
$env:JAVA_HOME = "D:\Android Studio\jbr"
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"

Write-Host "Setting up ADB reverse tcp:8000 -> tcp:8000..." -ForegroundColor Cyan
& $adb reverse tcp:8000 tcp:8000

Push-Location "$PSScriptRoot\..\mobile"
try {
    & $flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000 @args
} finally {
    Pop-Location
}
