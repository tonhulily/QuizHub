# QA native build và UI test — Quốc Anh — 19/11/2026

> Trạng thái cuối sau khi phiên làm việc bị ngắt: theo yêu cầu, QA app đã gỡ; chưa ghi nhận crash mới của app QA. APK đúng và bước tiếp theo ở [resume handoff](2026-11-19-quoc-anh-resume.md).

## Mốc và cấu hình

- Source checkpoint: `447ecf394894627e498df08464466f16a12e3ef6`; `origin/main`: `08a5a2e4097923d21bbdaf7d02cb1792f2171aa3`. Source archive tạo isolated workspace từ checkpoint này. `HEAD` vẫn giữ nguyên trong lượt delegate.
- Provenance native rebuild: base source SHA `447ecf394894627e498df08464466f16a12e3ef6` cộng đúng một dòng import theo phê duyệt Sơn ngày **2026-11-19** (`import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;`). Patch chỉ áp dụng trong ignored isolated QA workspace; root source và tracked QA runtime không sửa. Patched `app_theme.dart` SHA-256 `e90ca86344996f7ebb52d86d9e6fdf8b3755fc3213925e043c499efabef94809`; patch artifact SHA-256 `95f907dee356ea454fed781363b1a472be080a713fae2645cecfeec2668c7fd7`.
- Hash input tại root (SHA-256): `pubspec.yaml` `9306ed02270a091043410285cf0eda39013eafb8ae31e59f8b8fe239f8f42ac4`; `pubspec.lock` `59611bad141bbf6af7aba78f1f03dbb05c4e62d03d69c0c5d9c379480d9ebc4f`; `lib/main_preview.dart` `3bfd940443c63a696c502154c44727c81b58b9ae61663afb4c8c5b07937de4ac`.
- Linux x86_64; Flutter 3.41.6, Dart 3.11.4; JDK17; Android SDK hiện có; Gradle 8.14; `PUB_CACHE` dùng root cache đã có. Dart 3.11.4 thỏa `sdk: ^3.9.2` trong pubspec. Không chạy pub get trong lần dựng isolated package config ban đầu; kết quả lock-enforced offline resolution được ghi riêng bên dưới.
- Workspace: ignored `.qa-tools/quoc-anh-native-20261119/workspace`. `.dart_tool/package_config.json` được copy từ root config, project `quizhub` trỏ về workspace và các package `flutter`, `flutter_test`, `flutter_localizations` remap sang Flutter 3.41.6. Không mang `build/` hoặc cached native hooks từ preview Nam.
- Android QA delta chỉ trong workspace: `applicationId = "vn.edu.hust.quizhub.qa.quocanh"`, `android/local.properties` trỏ Flutter/Android SDK hiện có. `pubspec.yaml`, `pubspec.lock`, runtime source và tests giữ nguyên checkpoint. Không cài app/SDK/package và không gọi API host.
- Coordinator đối chiếu 191 file tracked thuộc `lib/`, `assets/`, `test/`, `pubspec.yaml` và `pubspec.lock` với SHA `447ecf3`; mismatch **0**.
- Snapshot thiết bị coordinator quan sát: Android 13 / API 33, font scale 1.0, logical size 1080×2400, density 480; QA package vắng mặt trước cài đặt (`pm path` exit 1). Không ghi serial.

## UI test host

Các lệnh dùng `CI=true FLUTTER_SUPPRESS_ANALYTICS=true FLUTTER_SKIP_UPDATE_CHECK=true`, XDG config/cache task-local, `PUB_CACHE` hiện hữu, Flutter 3.41.6 và `--no-pub`; chạy bằng local runner ngoài sandbox để cho phép loopback.

- `flutter test --no-pub --reporter expanded test/qa/ui_layout_regression_test.dart`: exit **1**, final output `00:04 +2 -5: Some tests failed.` Conversation list reported 161 px Row overflow at `conversations_view.dart:256` and 341 px `EmptyView` Column overflow at `state_views.dart:143` (candidate QH-QA-010/011). Feed/PostCard reported Row overflows of 71, 67, 179 and 123 px at `post_card.dart:380,479` (candidate QH-QA-012); test host uses `AppTheme.lightTheme` and `Scaffold`, with a 320×640 view and text scale 2. These are observed widget harness failures, not device repros. The comments test had off-screen hit-test/scroll `No element` at test lines 313/316 and a reaction finder miss; exam generator had `No element` during `dragUntilVisible` at line 395. Treat those as harness candidates pending repro, not confirmed product bugs. Full log: `qa-artifacts/2026-11-19/quoc-anh-native/logs/ui_layout_regression_test.log`.
- `flutter test --no-pub --reporter expanded test/features/messenger_ui_test.dart test/features/chat_navigation_test.dart test/shared/comment_reactions_test.dart test/features/blocking_test.dart`: exit **0**, actual final output `00:05 +25: All tests passed!`. These are fixture/mock widget tests, not API or native behavior. Full log: `qa-artifacts/2026-11-19/quoc-anh-native/logs/targeted_ui_tests.log`.
- Không có screenshot failure được tạo/captured trong test run; không có screenshot để preserve. Không có test nào cài app hoặc dùng thiết bị.

## Android APK build gate

- Lượt Flutter wrapper sandbox ban đầu gọi `flutter build apk -t lib/main_preview.dart --debug --no-pub --target-platform android-arm64` trong isolated workspace, rồi dừng vì Gradle không xác định wildcard IP (exit 1); log `build.log`.
- Escalated Flutter invocation thử thêm `--offline` và bị Flutter từ chối vì option không hợp lệ (exit 2). Sau đó chỉ gọi Gradle offline, không tải dependency: `./gradlew --offline --no-daemon assembleDebug` exit **1**, thiếu engine artifact các ABI ngoài arm64; log `gradle-offline.log`.
- Retry chính xác ABI: `./gradlew --offline --no-daemon -Ptarget-platform=android-arm64 assembleDebug` exit **1** tại `:app:checkDebugAarMetadata`; Gradle cache thiếu `androidx.profileinstaller:profileinstaller:1.3.1` AAR. Log `gradle-arm64-offline.log`.
- Lệnh Flutter build thử ban đầu chỉ định `-t lib/main_preview.dart`; các lệnh direct Gradle offline retries **không truyền `-Ptarget=lib/main_preview.dart`**, vì vậy các retry đó không xác minh entrypoint preview. Không có APK/SHA-256 từ các lượt thử này. Không dùng APK preview Nam cũ.
- Sau khi Sơn cho phép tải artifact Gradle còn thiếu theo phiên bản đã khai báo (không đổi SDK, declarations hay source), coordinator chạy lệnh exact-target online ở cuối report. Kết quả packaging: exit **0**, `BUILD SUCCESSFUL in 1m 25s`, 52 tasks (46 executed, 6 up-to-date). Log: `qa-artifacts/2026-11-19/quoc-anh-native/coordinator-gradle-preview.log`.
- APK packaging-only: `.qa-tools/quoc-anh-native-20261119/workspace/build/app/outputs/apk/debug/app-debug.apk`, 88,258,453 bytes, SHA-256 `588233dc1d965986eb58ddd3beefa3812ab23d963d063105ff205d64ae782288`. `aapt dump badging` exit **0**: package `vn.edu.hust.quizhub.qa.quocanh`, launcher `vn.edu.hust.quizhub.MainActivity`, minSDK 24, targetSDK 36, ABI `arm64-v8a`.
- APK thử này khởi chạy nhưng hiển thị splash đen. Logcat báo `GeneratedPluginsRegister` không tìm thấy `io.flutter.plugins.GeneratedPluginRegistrant` (`ClassNotFoundException`), rồi `PlatformException(channel-error Unable to establish connection dev.flutter.pigeon.shared_preferences_android.SharedPreferencesApi.getAll)`. Đây là lỗi QA build tooling, không phải product bug; screenshot được giữ lại và APK cũ đã gỡ.
- Nguyên nhân thuộc QA build harness: isolated archive không có `.flutter-plugins-dependencies` hay generated `GeneratedPluginRegistrant.java`; direct Gradle packaging bỏ qua Flutter tool phase tạo registrant chuẩn. `.flutter-plugins-dependencies` ở root là metadata SDK 3.47.9; bản trong cache Android preview là 3.41.6 với các path/version riêng, không thể chép nguyên vào isolated workspace. Isolated `package_config.json` đã có `shared_preferences_android`, nhưng điều đó tự nó không tạo native plugin registrant.
- Flutter 3.41.6 source xác nhận `regeneratePlatformSpecificToolingIfApplicable` trả về ngay khi `shouldRunPub` là false. Vì vậy wrapper build với `--no-pub` **không** refresh plugin metadata hay registrant; coordinator đã thử và thấy registrant/APK chưa được tạo mới, rồi dừng trước install. Khi pub thực sự chạy, Flutter project tooling gọi `refreshPluginsList` và `injectPlugins`; Android inject gọi `_writeAndroidPluginRegistrant` để tạo registrant từ package config đã resolve. Sau đó cache-only `flutter pub get --offline --enforce-lockfile` đã trả exit 65, chi tiết ngay dưới đây. Không thêm manual registration/runtime changes.
- Kết quả `flutter pub get --offline --enforce-lockfile` trên Flutter 3.41.6: exit **65**; solver muốn hạ 5 package so với lockfile: `intl` 0.20.3→0.20.2, `matcher` 0.12.20→0.12.19, `meta` 1.19.0→1.17.0, `test_api` 0.7.12→0.7.10, `vector_math` 2.4.4→2.2. Lock SHA vẫn `59611bad141bbf6af7aba78f1f03dbb05c4e62d03d69c0c5d9c379480d9ebc4f` ở root và isolated copy. Không tiếp tục route Flutter 3.41.6: package config remap đã dùng cho local widget tests là provisional, không phải resolved SDK/lock-compatible native baseline.
- Source Flutter 3.47.9 compile blocker đã được vá trong isolated QA copy theo phê duyệt nêu trên; patch không được áp dụng vào root source. `flutter pub get --offline --enforce-lockfile`: exit 0; lock SHA giữ nguyên. Tooling sinh plugin metadata và registrant; log `qa-artifacts/2026-11-19/quoc-anh-native/offline-generated-tooling-3.47.9.log`.
- Exact-target Flutter 3.47.9 preview wrapper build `--no-pub`, `arm64`, tắt SDK downloads: exit 0 sau 318.7 giây. Log `qa-artifacts/2026-11-19/quoc-anh-native/corrected-flutter-preview-3.47.9.log`. APK: `.qa-tools/quoc-anh-native-20261119/workspace/build/app/outputs/flutter-apk/app-debug.apk`, 97,980,127 bytes, SHA-256 `755b5deaf26c70f781a0055167fba5e4a29d544a8697a829772c26981654a120`; DEX có registrant và SharedPreferences classes. Install ADB exit 0/Success; cold launch exit 0/Status ok trong 5.786 giây. QA foreground và Home với Tạo bài/Tin Nhắn/feed đã được quan sát; APK trên thiết bị có SHA khớp local artifact.
- Flutter 3.47.9 targeted UI log `qa-artifacts/2026-11-19/quoc-anh-native/targeted-ui-tests-3.47.9.log` chỉ partial tới `+11`; không có completion hoặc exit code cuối. Ghi **INTERRUPTED / INCOMPLETE**, không gọi là 25 PASS.
- APK có registrant failure đã gỡ (uninstall exit 0, `pm path` exit 1); screenshot black splash được giữ. APK đúng cũng đã uninstall theo yêu cầu mới nhất; `pm path` xác nhận package vắng mặt. Font scale 1.0, 1080×2400, density 480; không cần hoàn nguyên display setting.
- Lỗi compile `CupertinoPageTransitionsBuilder` trên Flutter 3.47.9 tại compile gate trước đó vẫn là kết quả riêng theo SDK đó; không được giải quyết bởi APK packaging lần này.

## Kết luận

- APK direct Gradle đầu tiên không đạt startup do plugin registrant thiếu; tooling đã xác định và APK đó đã gỡ. Flutter 3.41.6 dependency resolution offline muốn thay 5 lockfile versions nên nhánh đó dừng. APK wrapper Flutter 3.47.9 đã build và khởi chạy tới Home với patch cô lập được duyệt; sau đó đã gỡ theo yêu cầu.
- `ui_layout_regression_test.dart`: test đã chạy, **2 PASS / 5 FAIL** trên harness local Flutter 3.41.6; các failures không tự động xác nhận bug native.
- Targeted UI suite Flutter 3.47.9: **INTERRUPTED / INCOMPLETE** (partial output `+11`, không có exit code cuối); không cộng kết quả 3.41.6 provisional.
- Native startup/Home: đã quan sát. POST/COMM/CHAT/REL normal flows chưa hoàn tất trước khi phiên làm việc bị ngắt; chưa ghi nhận crash mới của app QA. Acceptance giữ **NOT RUN / INCOMPLETE**, không suy ra PASS/FAIL. QA package đã gỡ; hai ảnh startup được giữ.

## Lệnh coordinator

Lệnh direct Gradle lịch sử trong isolated workspace `android/` (chỉ tạo APK SHA `588…`, không dùng cho nghiệm thu startup):

```bash
./gradlew --no-daemon -Ptarget=lib/main_preview.dart -Ptarget-platform=android-arm64 -Pandroid.builder.sdkDownload=false assembleDebug
```

Lệnh wrapper `--no-pub` trên Flutter 3.41.6 không regen metadata khi pub bị skip; offline lock-enforced pub exit 65 vì muốn đổi 5 pinned versions. Không chạy tiếp nhánh này. Lệnh 3.47.9 sau khi Sơn cho phép patch import cô lập đã chạy thành công với exact target:

```bash
../../sdk-3.47.9/flutter/bin/flutter build apk -t lib/main_preview.dart --debug --no-pub --target-platform android-arm64 --android-project-arg=android.builder.sdkDownload=false
```

Flutter 3.47.9 hỗ trợ `--android-project-arg`; implementation nối giá trị thành Gradle `-Pandroid.builder.sdkDownload=false`. Build dùng JDK17 `.qa-tools/java17`, Android SDK `.qa-tools/android-build-sdk`, Gradle cache `.qa-tools/gradle-user-home` và task-local XDG/cache. Không chép metadata từ root/preview và không thêm manual/runtime registration.
