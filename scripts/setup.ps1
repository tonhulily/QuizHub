<#
.SYNOPSIS
  QuizHub - kiểm tra môi trường và cài thư viện Dart.

.DESCRIPTION
  Tương đương "pip install -r requirements.txt" của Python:
    - kiểm tra công cụ cần có (Flutter, JDK, Android SDK, NDK, adb...)
    - chạy `flutter pub get` để cài thư viện khai báo trong pubspec.yaml

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\setup.ps1
  powershell -ExecutionPolicy Bypass -File scripts\setup.ps1 -Full   # thêm analyze + test

  macOS / Linux / Git Bash: dùng scripts/setup.sh
#>
param([switch]$Full)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Continue'
Set-Location (Split-Path -Parent $PSScriptRoot)

$RequiredNdk = '27.0.12077973'      # đã ghim trong android/app/build.gradle.kts
$MinDart     = [version]'3.9.2'     # environment.sdk trong pubspec.yaml
$MinJava     = 17
$script:Failed = $false

function Ok($m)   { Write-Host "  [OK] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "  [!]  $m" -ForegroundColor Yellow }
function Bad($m)  { Write-Host "  [X]  $m" -ForegroundColor Red; $script:Failed = $true }
function Step($m) { Write-Host ""; Write-Host "== $m" -ForegroundColor Cyan }
function Has($c)  { return [bool](Get-Command $c -ErrorAction SilentlyContinue) }

# Chạy lệnh ngoài, gộp stdout + stderr thành chuỗi (tránh lỗi NativeCommandError của PS 5.1)
function Run($cmdline) { return (cmd /c "$cmdline 2>&1") }

# Tìm thư mục Android SDK
function Find-Sdk {
    $fromProps = ''
    if (Test-Path 'android\local.properties') {
        $line = Select-String -Path 'android\local.properties' -Pattern '^sdk\.dir=' | Select-Object -First 1
        if ($line) { $fromProps = ($line.Line -replace '^sdk\.dir=', '') -replace '\\\\', '\' -replace '\\:', ':' }
    }
    $candidates = @(
        $env:ANDROID_HOME, $env:ANDROID_SDK_ROOT, $fromProps,
        (Join-Path $env:LOCALAPPDATA 'Android\Sdk')
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path $c)) { return $c }
    }
    return $null
}

Write-Host "QuizHub - kiểm tra môi trường"

# ---------------------------------------------------------------- Git
Step 'Git'
if (Has git) { Ok (Run 'git --version' | Select-Object -First 1) }
else { Bad 'Chưa cài Git: https://git-scm.com/downloads' }

# ---------------------------------------------------------------- Flutter / Dart
Step 'Flutter và Dart'
$haveFlutter = Has flutter
if ($haveFlutter) {
    $dartOut    = (Run 'dart --version') -join ' '
    $flutterOut = (Run 'flutter --version') -join ' '
    $dartV    = if ($dartOut    -match 'version:\s*(\d+\.\d+\.\d+)') { $Matches[1] } else { $null }
    $flutterV = if ($flutterOut -match 'Flutter\s+(\d+\.\d+\.\d+)')  { $Matches[1] } else { '?' }
    Ok "Flutter $flutterV (Dart $(if ($dartV) { $dartV } else { '?' }))"
    if ($dartV -and ([version]$dartV -lt $MinDart)) {
        Bad "Dart $dartV thấp hơn yêu cầu $MinDart. Chạy: flutter upgrade"
    }
}
else { Bad 'Chưa cài Flutter hoặc chưa thêm flutter\bin vào PATH: https://docs.flutter.dev/get-started/install' }

# ---------------------------------------------------------------- JDK
Step "JDK (cần $MinJava trở lên)"
if (Has java) {
    $javaLine = (Run 'java -version') | Select-Object -First 1
    $javaV = if ($javaLine -match '"([^"]+)"') { $Matches[1] } else { '' }
    $major = if ($javaV -match '^1\.(\d+)') { [int]$Matches[1] } elseif ($javaV -match '^(\d+)') { [int]$Matches[1] } else { 0 }
    if ($major -ge $MinJava) { Ok "Java $javaV" } else { Bad "Java $javaV quá cũ, cần $MinJava trở lên" }
}
else { Warn "Không thấy 'java' trong PATH. Nếu đã cài Android Studio thì Flutter dùng JDK của nó, bỏ qua được." }

# ---------------------------------------------------------------- Android
Step 'Android SDK, NDK, adb'
$sdk = Find-Sdk
$adb = $null
if (-not $sdk) {
    Bad 'Không tìm thấy Android SDK. Cài Android Studio rồi cài SDK, hoặc đặt biến ANDROID_HOME.'
}
else {
    Ok "Android SDK: $sdk"

    if (Test-Path (Join-Path $sdk "ndk\$RequiredNdk\source.properties")) { Ok "NDK $RequiredNdk" }
    else { Bad "Thiếu NDK $RequiredNdk (SDK Manager > SDK Tools > NDK (Side by side) > Show Package Details)" }

    $adbPath = Join-Path $sdk 'platform-tools\adb.exe'
    if (Test-Path $adbPath) { $adb = $adbPath; Ok 'adb (platform-tools)' }
    else { Bad 'Thiếu Android SDK Platform-Tools (adb)' }

    if (Test-Path (Join-Path $sdk 'cmdline-tools')) { Ok 'Command-line Tools' }
    else { Warn 'Thiếu Command-line Tools (cần để chạy: flutter doctor --android-licenses)' }

    $platforms = @()
    if (Test-Path (Join-Path $sdk 'platforms')) {
        $platforms = Get-ChildItem (Join-Path $sdk 'platforms') -Directory |
            Where-Object { $_.Name -like 'android-*' } |
            ForEach-Object { $_.Name -replace '^android-', '' }
    }
    if ($platforms.Count -gt 0) { Ok ("SDK Platform: " + (($platforms | Sort-Object { [int]($_ -replace '\D.*', '') }) -join ' ')) }
    else { Bad 'Chưa cài SDK Platform nào (cần Android 14 / API 34 trở lên)' }
}

Step 'Thiết bị Android đang kết nối'
if ($adb) {
    $lines = (Run "`"$adb`" devices") | Select-Object -Skip 1
    $devices = @($lines | Where-Object { $_ -match '\sdevice$' } | ForEach-Object { ($_ -split '\s+')[0] })
    $unauth  = @($lines | Where-Object { $_ -match '\sunauthorized$' } | ForEach-Object { ($_ -split '\s+')[0] })
    if ($devices.Count -gt 0) { foreach ($d in $devices) { Ok "Máy: $d" } }
    else { Warn 'Chưa thấy máy nào. Cắm cáp, bật Gỡ lỗi USB, hoặc mở máy ảo (build vẫn chạy được).' }
    foreach ($u in $unauth) { Warn "Máy $u chưa cấp quyền: bấm Cho phép trên điện thoại." }
}
else { Warn 'Bỏ qua (chưa có adb)' }

# ---------------------------------------------------------------- Thư viện Dart
Step "Cài thư viện Dart (flutter pub get) - như 'pip install -r requirements.txt'"
if ($haveFlutter) {
    # Chỉ in ra khi lỗi (đầu ra mặc định rất dài vì liệt kê cả gói có bản mới)
    $pubOut = Run 'flutter pub get'
    if ($LASTEXITCODE -eq 0) { Ok 'Đã cài xong thư viện theo pubspec.yaml / pubspec.lock' }
    else { $pubOut | ForEach-Object { Write-Host $_ }; Bad 'flutter pub get thất bại. Đọc thông báo lỗi ở trên.' }
}
else { Warn 'Bỏ qua vì chưa có Flutter' }

# ---------------------------------------------------------------- Kiểm tra mã (tuỳ chọn)
if ($Full -and $haveFlutter) {
    Step 'flutter analyze'
    & flutter analyze
    if ($LASTEXITCODE -eq 0) { Ok 'analyze sạch' } else { Bad 'analyze có lỗi' }
    Step 'flutter test'
    & flutter test
    if ($LASTEXITCODE -eq 0) { Ok 'test xanh' } else { Bad 'test có lỗi' }
}

# ---------------------------------------------------------------- Kết quả
Write-Host ''
if (-not $script:Failed) {
    Write-Host 'SẴN SÀNG. Chạy app:' -ForegroundColor Green
    Write-Host '    flutter devices'
    Write-Host '    flutter run -d <id máy>'
    Write-Host '  (chưa có tài khoản: flutter run -d <id> -t lib/main_preview.dart)'
}
else {
    Write-Host 'CHƯA ĐỦ: sửa các mục [X] ở trên theo gợi ý rồi chạy lại script.' -ForegroundColor Red
    Write-Host 'Hướng dẫn cài chi tiết: REQUIREMENTS.md'
    exit 1
}
