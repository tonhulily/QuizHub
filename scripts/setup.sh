#!/usr/bin/env bash
# =============================================================================
#  QuizHub - kiểm tra môi trường và cài thư viện Dart
#
#  Tương đương "pip install -r requirements.txt" của Python:
#    - kiểm tra công cụ cần có (Flutter, JDK, Android SDK, NDK, adb...)
#    - chạy `flutter pub get` để cài thư viện khai báo trong pubspec.yaml
#
#  Dùng (Git Bash / macOS / Linux):
#    bash scripts/setup.sh          # kiểm tra + cài thư viện
#    bash scripts/setup.sh --full   # thêm flutter analyze và flutter test
#
#  Windows PowerShell: xem scripts/setup.ps1
# =============================================================================
set -u
cd "$(dirname "$0")/.." || exit 1

REQUIRED_NDK="27.0.12077973"   # đã ghim trong android/app/build.gradle.kts
MIN_DART="3.9.2"               # environment.sdk trong pubspec.yaml
MIN_JAVA=17
FULL=0
[ "${1:-}" = "--full" ] && FULL=1

FAILED=0
ok()   { printf '  [OK] %s\n' "$*"; }
warn() { printf '  [!]  %s\n' "$*"; }
bad()  { printf '  [X]  %s\n' "$*"; FAILED=1; }
step() { printf '\n== %s\n' "$*"; }

# ver_ge A B  ->  đúng nếu phiên bản A >= B
ver_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]; }

# Đổi đường dẫn Windows (C:\...) sang dạng Git Bash khi có cygpath
to_unix() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -u "$1" 2>/dev/null || echo "$1"; else echo "$1"; fi
}

# Tìm thư mục Android SDK
find_sdk() {
  local from_props
  from_props=$(grep -s '^sdk.dir=' android/local.properties | head -n1 | cut -d= -f2- | sed 's/\\\\/\\/g; s/\\:/:/g')
  local candidates=(
    "${ANDROID_HOME:-}" "${ANDROID_SDK_ROOT:-}" "$from_props"
    "${LOCALAPPDATA:-}/Android/Sdk" "$HOME/Library/Android/sdk" "$HOME/Android/Sdk"
  )
  local c
  for c in "${candidates[@]}"; do
    [ -n "$c" ] || continue
    c=$(to_unix "$c")
    if [ -d "$c" ]; then echo "$c"; return; fi
  done
}

echo "QuizHub - kiểm tra môi trường"

# ---------------------------------------------------------------- Git
step "Git"
if command -v git >/dev/null 2>&1; then ok "$(git --version)"
else bad "Chưa cài Git: https://git-scm.com/downloads"; fi

# ---------------------------------------------------------------- Flutter / Dart
step "Flutter và Dart"
HAVE_FLUTTER=0
if command -v flutter >/dev/null 2>&1; then
  HAVE_FLUTTER=1
  DART_V=$(dart --version 2>&1 | sed -n 's/.*version: \([0-9][0-9.]*\).*/\1/p' | head -n1)
  FLUTTER_V=$(flutter --version 2>&1 | sed -n 's/^Flutter \([0-9][0-9.]*\).*/\1/p' | head -n1)
  ok "Flutter ${FLUTTER_V:-?} (Dart ${DART_V:-?})"
  if [ -n "${DART_V:-}" ] && ! ver_ge "$DART_V" "$MIN_DART"; then
    bad "Dart $DART_V thấp hơn yêu cầu $MIN_DART. Chạy: flutter upgrade"
  fi
else
  bad "Chưa cài Flutter hoặc chưa thêm flutter/bin vào PATH: https://docs.flutter.dev/get-started/install"
fi

# ---------------------------------------------------------------- JDK
step "JDK (cần $MIN_JAVA trở lên)"
if command -v java >/dev/null 2>&1; then
  JAVA_V=$(java -version 2>&1 | head -n1 | sed 's/.*"\(.*\)".*/\1/')
  JAVA_MAJOR=${JAVA_V%%.*}
  [ "$JAVA_MAJOR" = "1" ] && JAVA_MAJOR=$(echo "$JAVA_V" | cut -d. -f2)
  if [ "${JAVA_MAJOR:-0}" -ge "$MIN_JAVA" ] 2>/dev/null; then ok "Java $JAVA_V"
  else bad "Java $JAVA_V quá cũ, cần $MIN_JAVA trở lên"; fi
else
  warn "Không thấy 'java' trong PATH. Nếu đã cài Android Studio thì Flutter dùng JDK của nó, bỏ qua được."
fi

# ---------------------------------------------------------------- Android
step "Android SDK, NDK, adb"
SDK=$(find_sdk)
ADB=""
if [ -z "$SDK" ]; then
  bad "Không tìm thấy Android SDK. Cài Android Studio rồi cài SDK, hoặc đặt biến ANDROID_HOME."
else
  ok "Android SDK: $SDK"

  if [ -f "$SDK/ndk/$REQUIRED_NDK/source.properties" ]; then
    ok "NDK $REQUIRED_NDK"
  else
    bad "Thiếu NDK $REQUIRED_NDK (SDK Manager > SDK Tools > NDK (Side by side) > Show Package Details)"
  fi

  for cand in "$SDK/platform-tools/adb" "$SDK/platform-tools/adb.exe"; do
    [ -f "$cand" ] && ADB="$cand" && break
  done
  if [ -n "$ADB" ]; then ok "adb (platform-tools)"
  else bad "Thiếu Android SDK Platform-Tools (adb)"; fi

  if [ -d "$SDK/cmdline-tools" ]; then ok "Command-line Tools"
  else warn "Thiếu Command-line Tools (cần để chạy: flutter doctor --android-licenses)"; fi

  if ls "$SDK/platforms" 2>/dev/null | grep -q 'android-'; then
    ok "SDK Platform: $(ls "$SDK/platforms" | sed 's/android-//' | sort -n | tr '\n' ' ')"
  else
    bad "Chưa cài SDK Platform nào (cần Android 14 / API 34 trở lên)"
  fi
fi

step "Thiết bị Android đang kết nối"
if [ -n "$ADB" ]; then
  DEVICES=$("$ADB" devices 2>/dev/null | tail -n +2 | awk '$2=="device"{print $1}')
  UNAUTH=$("$ADB" devices 2>/dev/null | tail -n +2 | awk '$2=="unauthorized"{print $1}')
  if [ -n "$DEVICES" ]; then
    for d in $DEVICES; do ok "Máy: $d"; done
  else
    warn "Chưa thấy máy nào. Cắm cáp, bật Gỡ lỗi USB, hoặc mở máy ảo (build vẫn chạy được)."
  fi
  [ -n "$UNAUTH" ] && warn "Máy $UNAUTH chưa cấp quyền: bấm Cho phép trên điện thoại."
else
  warn "Bỏ qua (chưa có adb)"
fi

# ---------------------------------------------------------------- Thư viện Dart
step "Cài thư viện Dart (flutter pub get) - như 'pip install -r requirements.txt'"
if [ "$HAVE_FLUTTER" = "1" ]; then
  # Chỉ in ra khi lỗi (đầu ra mặc định rất dài vì liệt kê cả gói có bản mới)
  if PUB_OUT=$(flutter pub get 2>&1); then ok "Đã cài xong thư viện theo pubspec.yaml / pubspec.lock"
  else echo "$PUB_OUT"; bad "flutter pub get thất bại. Đọc thông báo lỗi ở trên."; fi
else
  warn "Bỏ qua vì chưa có Flutter"
fi

# ---------------------------------------------------------------- Kiểm tra mã (tuỳ chọn)
if [ "$FULL" = "1" ] && [ "$HAVE_FLUTTER" = "1" ]; then
  step "flutter analyze"
  flutter analyze && ok "analyze sạch" || bad "analyze có lỗi"
  step "flutter test"
  flutter test && ok "test xanh" || bad "test có lỗi"
fi

# ---------------------------------------------------------------- Kết quả
echo
if [ "$FAILED" = "0" ]; then
  echo "SẴN SÀNG. Chạy app:"
  echo "    flutter devices"
  echo "    flutter run -d <id máy>"
  echo "  (chưa có tài khoản: flutter run -d <id> -t lib/main_preview.dart)"
else
  echo "CHƯA ĐỦ: sửa các mục [X] ở trên theo gợi ý rồi chạy lại script."
  echo "Hướng dẫn cài chi tiết: REQUIREMENTS.md"
  exit 1
fi
