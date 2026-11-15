# Báo cáo QA: Android SDK và cache — 2026-11-15

**Trạng thái mới nhất:** dependency restore thành công cho main (Flutter 3.47.9) và Nam preview (Flutter 3.41.6); preview APK build và cài đặt QA app đã thành công. Native UI QA bị chặn vì overlay ứng dụng khác chiếm focus; tester dừng đọc/điều khiển thiết bị. Không có case UI nào PASS.

## Phạm vi và mốc SHA

- Đây là kiểm tra khả dụng chỉ đọc. Không build, chạy test/analyze, cài app, tải công cụ, dọn cache hoặc ghi ra dịch vụ bên ngoài.
- Kiểm tra inventory bắt đầu tại SHA `aa48b9f08ff611eac3a3bf3eed761d4a62e3cd02` trên `qa/khanhson2005`.
- Trong lúc audit, HEAD chuyển thành `adde556e2ef6e481fd7145588db878012673b059`. Trên SHA này đã recheck read-only: Java/Gradle không có trên PATH, Gradle wrapper JAR vắng mặt, `sdk.dir` không có trong `android/local.properties`, và `ANDROID_HOME`/`ANDROID_SDK_ROOT` unset. Inventory khác dưới đây được quan sát tại SHA lúc bắt đầu; không rerun toàn bộ sau khi HEAD đổi.

## Quan sát môi trường

Môi trường Linux x86_64 / WSL2. Dung lượng còn trống 909 GB trên filesystem 1007 GB (48 GB đã dùng).

Flutter SDK tại `.qa-tools/flutter` có version marker Flutter 3.41.6 stable / Dart 3.11.4; lệnh Dart version trả exit 0. Flutter engine artifacts cho `linux-x64`, `android-arm64`, và `android-x64` hiện diện. Tại SHA `adde556e2ef6e481fd7145588db878012673b059`, `.dart_tool/package_config.json` có 135 package root hiện hữu nhưng không khớp `pubspec.lock` có 136 package; `phosphor_icons`, `stomp_dart_client`, và `web_socket` chỉ có trong lockfile. Vì vậy Flutter test/analyze bị chặn và không được chạy. `.qa-tools/pub-cache` chiếm 299 MB; package root tồn tại không xác nhận cache sẵn sàng cho lockfile hiện tại. Chi tiết ở [báo cáo regression cùng SHA](2026-11-15-regression.md).

Android SDK tại `.qa-tools/android-build-sdk` chiếm 2.9 GB, có platform 34/35/36, build-tools 35/36, NDK 27.0.12077973, platform-tools 37.0.1 và command-line tools 22.0. `android/local.properties` có `flutter.sdk` trỏ tới đường dẫn hiện hữu nhưng không khai báo `sdk.dir`; các biến SDK Android cũng unset.

ADB version trả exit 0; lệnh devices trả exit 0 và liệt kê 0 thiết bị. Không có serial hoặc dữ liệu định danh thiết bị trong evidence.

Không tìm thấy Java/JDK hoặc Gradle trên PATH. `$HOME/.gradle/caches` và `$HOME/.gradle/wrapper/dists` không tồn tại; `android/gradle/wrapper/` chỉ có `gradle-wrapper.properties` cấu hình Gradle 8.14, không có wrapper JAR. `.qa-tools/android-preview/android/.gradle` có 5 MB metadata của một preview trước đó, không phải bản phân phối Gradle hay dependency cache đầy đủ.

Các quan sát trên mô tả trạng thái hiện tại. Không có inventory trước đó để xác định thành phần cache nào Sơn đã xóa.

## Trạng thái tại inventory ban đầu / recheck adde556

- **Offline Android build readiness: BLOCKED.** Hiện không có JDK trên PATH, đường dẫn Android SDK không được khai báo cho checkout qua `sdk.dir` hoặc biến môi trường, và không có Gradle distribution/dependency cache người dùng cùng wrapper JAR. Đây là đánh giá khả dụng; APK build không được chạy và không có kết quả build thất bại.
- **APK build: NOT RUN.**
- **Flutter/Dart offline tests/analyze: BLOCKED / NOT RUN.** Package config (135 package) không khớp lockfile (136); ba package mới cần cấu hình là `phosphor_icons`, `stomp_dart_client`, `web_socket`. Xem [báo cáo regression](2026-11-15-regression.md).
- **Thiết bị Android: không phát hiện thiết bị ADB tại thời điểm kiểm tra inventory ban đầu.** Không chạy lại discovery sau khi HEAD đổi.

Đây là kết quả lịch sử trước các lần restore package và discovery mới bên dưới; không dùng các trạng thái này để mô tả hiện trạng mới nhất.

Chi tiết command/exit và mốc SHA được lưu tại [evidence kiểm tra môi trường](../evidence/2026-11-15/android-environment.txt).

## Discovery bổ sung sau yêu cầu kiểm tra USB — 2026-11-15

- Lần Mobile MCP discovery ban đầu trả `devices: []`; Windows ADB shim cũng chưa enumerate được.
- Windows ADB shim `.qa-tools/android-sdk/platform-tools/adb devices` thoát mã 1 trước khi liệt kê thiết bị do WSL lỗi `UtilBindVsockAnyPort ... socket failed 1`. Vì vậy chưa xác nhận được online/model/OS/screen; kết quả này không chứng minh điện thoại vắng mặt. Kết quả Linux-native ADB 0 thiết bị trước đó không đại diện cho Windows bridge hiện tại.
- Tìm thấy JDK tái sử dụng tại `.qa-tools/java17` (Temurin 17.0.20.1, `java -version` exit 0). `.qa-tools/gradle-home` không có; wrapper JAR có trong Android preview nhưng không có Gradle 8.14 distribution/executable trong lượt tìm kiếm có giới hạn. Không chạy Gradle hay app.
- Chi tiết: [evidence discovery](../evidence/2026-11-15/device-discovery.txt); bản đầy đủ trong ignored `qa-artifacts/2026-11-15/device-discovery.txt`.

## Cấu hình preview biệt lập cho native QA — 2026-11-15

- Preview hiện có tại `.qa-tools/android-preview` được trỏ tới snapshot Nam có source SHA `639da129d89e8290c13b63af3d36045309b38fd6`. `pubspec.yaml`, `pubspec.lock`, `lib/main_preview.dart`, `lib/dev/preview_backend.dart`, và `android/app/build.gradle.kts` khớp nội dung commit đó.
- Chỉ hai manifest package trong preview được chép lại; symlink `lib` và `assets` đã được xác nhận trước khi đổi đích. `lib`, `android`, `pubspec.yaml` và `pubspec.lock` ở root không bị sửa.
- Preview Android manifest giữ application ID `vn.edu.hust.quizhub.qa.preview`; build config không định nghĩa product flavor. Dùng entrypoint `lib/main_preview.dart` và `--dart-define=PREVIEW_ROLE=LECTURER`, không truyền `--flavor`.
- `.qa-tools/flutter` là Flutter 3.41.6; JDK có sẵn ở `.qa-tools/java17`, SDK trong `.qa-tools/android-build-sdk`. Preview `local.properties` trỏ tới hai SDK path này. Dùng các user/cache path riêng dưới `.qa-tools` để coordinator fetch package và Gradle distribution.
- `main_preview.dart` truyền `PreviewBackend` vào `setupLocator` làm HTTP adapter nên REST mock của app không gửi thao tác business tới API backend. Entry point vẫn khởi tạo Firebase và đăng ký FCM khi Firebase khả dụng; đây có thể liên hệ dịch vụ Firebase bên ngoài.
- Tại thời điểm chuẩn bị cấu hình, package fetch/build chưa chạy. Coordinator có thể dùng:

```bash
export JAVA_HOME="$PWD/.qa-tools/java17"
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="$PWD/.qa-tools/android-build-sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export ANDROID_USER_HOME="$PWD/.qa-tools/android-user-home"
export GRADLE_USER_HOME="$PWD/.qa-tools/gradle-user-home"
export XDG_CONFIG_HOME="$PWD/.qa-tools/config"
export XDG_CACHE_HOME="$PWD/.qa-tools/cache"
export PUB_CACHE="$PWD/.qa-tools/pub-cache"
export FLUTTER_SUPPRESS_ANALYTICS=true CI=true
FLUTTER="$PWD/.qa-tools/flutter/bin/flutter"
cd "$PWD/.qa-tools/android-preview"
"$FLUTTER" pub get --enforce-lockfile
"$FLUTTER" build apk -t lib/main_preview.dart --dart-define=PREVIEW_ROLE=LECTURER --debug --no-pub --target-platform android-arm64
```

## Cập nhật sau khi coordinator restore dependency và discovery thiết bị — 2026-11-15

- Coordinator báo `flutter pub get --enforce-lockfile` exit 0 cho main với Flutter 3.47.9 và cho preview Nam với Flutter 3.41.6. Preview source giữ SHA `639da129d89e8290c13b63af3d36045309b38fd6`; không thay lockfile.
- Mobile MCP báo `RMX3370`, Android 13, online. Không ghi serial/ID hoặc suy đoán loại thiết bị.
- Coordinator báo preview `assembleDebug` exit 0 (772.3 giây), APK SHA-256 `c09122a2c64d4e76650176c330b4494d090f822bd0357dc2b76b512fe7718603`; package `vn.edu.hust.quizhub.qa.preview`; source snapshot SHA `639da129d89e8290c13b63af3d36045309b38fd6`. Coordinator xác nhận cài đặt bằng ADB exit 0 và gỡ QA app qua Mobile MCP. Lệnh `timeout 20s adb -s [masked] shell pm path vn.edu.hust.quizhub.qa.preview` thoát mã 1, output rỗng, xác nhận package không còn. Đây là build/install thành công, không phải UI QA PASS; app chính không bị thao tác.
- UI QA bắt đầu khi coordinator xác nhận QA package là foreground. Tap tìm kiếm tại `(820,180)` tiếp theo trả về overlay ứng dụng khác; coordinator kiểm tra sau đó thấy overlay vẫn giữ focus. Tester dừng đọc/điều khiển ngay. Không lưu màn hình hoặc nội dung ngoài scope. Native case hiện `BLOCKED` do môi trường thiết bị bị che; chi tiết ở [native UI report](2026-11-15-native-ui.md).
