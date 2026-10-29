param(
    [ValidateSet('customer','staff')][string]$Role = 'customer',
    [ValidateSet('debug','release')][string]$Mode = 'debug'
)
$ErrorActionPreference = 'Stop'
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$previousGradleHome = $env:GRADLE_USER_HOME
$previousTemp = $env:TEMP
$previousTmp = $env:TMP
Push-Location $projectRoot
try {
    # Keep this project's large cache and temporary files on its workspace drive.
    if (-not $env:GRADLE_USER_HOME) { $env:GRADLE_USER_HOME = Join-Path $projectRoot '.smartpark/gradle-home' }
    $projectTemp = Join-Path $projectRoot '.smartpark/android-temp'
    New-Item -ItemType Directory -Force -Path $env:GRADLE_USER_HOME,$projectTemp | Out-Null
    $env:TEMP = $projectTemp
    $env:TMP = $projectTemp
    $entrypoint = if ($Role -eq 'staff') { 'lib/main_staff.dart' } else { 'lib/main.dart' }
    & flutter.bat build apk "--$Mode" --flavor $Role -t $entrypoint
    if ($LASTEXITCODE -ne 0) { throw "Android build failed ($LASTEXITCODE)" }
} finally {
    if ($previousGradleHome) { $env:GRADLE_USER_HOME = $previousGradleHome }
    else { Remove-Item Env:GRADLE_USER_HOME -ErrorAction SilentlyContinue }
    $env:TEMP = $previousTemp
    $env:TMP = $previousTmp
    Pop-Location
}
