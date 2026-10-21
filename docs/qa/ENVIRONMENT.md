# Môi trường QA

Ghi nhận cập nhật **2026-10-21** trên nhánh `qa/khanhson2005`. Đường dẫn SDK dưới đây nằm trong `/tmp`, không chỉnh `PATH`, cấu hình Flutter, VS Code hay cài đặt toàn cục. Thư mục `/tmp` và package cache có thể bị dọn khi phiên làm việc kết thúc.

## Flutter local runner

Flutter 3.41.6 stable và Dart 3.11.4 đã được cài tại `/tmp/quizhub-qa-sdk/flutter`. SHA-256 archive khớp manifest phát hành chính thức: `503b3e6b7d352fca5d21b6474eca95ad544d8fc3b053782eab63a360c7fc7569`. Package cache cô lập ở `/tmp/quizhub-pub-cache`; `flutter pub get --enforce-lockfile` hoàn tất thành công và `pubspec.lock` giữ nguyên SHA-256 `4069b6a766720cba6b6ec17891ecc9c6b5d448bed16f5af8d7d0f1552eedc7d0`.

Để dùng SDK trong terminal hiện tại, đặt biến môi trường tạm thời và gọi binary bằng đường dẫn đầy đủ:

```bash
export XDG_CONFIG_HOME=/tmp/quizhub-qa-sdk/config
export XDG_CACHE_HOME=/tmp/quizhub-qa-sdk/cache
export PUB_CACHE=/tmp/quizhub-pub-cache
export FLUTTER_SUPPRESS_ANALYTICS=true CI=true
FLUTTER=/tmp/quizhub-qa-sdk/flutter/bin/flutter
```

Không cần thêm SDK vào cấu hình editor. Sau khi khởi động lại hoặc dọn `/tmp`, kiểm tra lại sự tồn tại của binary/cache trước khi chạy lệnh.

**FLUTTER_TESTED_SHA:** `d58cdf01a4b2e04a41901e8804fe1d49847faccf`.

- `flutter test --no-pub`: 95 test passed, exit 0. Log: [flutter-regression-d58cdf0-local-runner.log](../../qa-artifacts/flutter-regression-d58cdf0-local-runner.log).
- `dart format --output=none --set-exit-if-changed lib test`: 112 files, 0 changed, exit 0. Log: [dart-format-d58cdf0.log](../../qa-artifacts/dart-format-d58cdf0.log).
- Lượt `flutter test` trong sandbox mặc định không chạy được do runner không bind được loopback `127.0.0.1` cho 13 test loader; lần chạy local runner được duyệt ở trên đã thành công. Chi tiết: [flutter-regression-d58cdf0.log](../../qa-artifacts/flutter-regression-d58cdf0.log).
- `flutter analyze` trước đó báo `No issues found` tại SHA `f5e225a5d4aa5d8e8e366770eb2bb4b0212621a6`; đầu ra của lượt đó không được lưu thành log. Đây không phải kết quả analyzer sau commit `d58cdf0`.

95 test là unit/widget automation chạy trên local runner; không xác nhận tích hợp API từ xa, hành vi trên thiết bị/emulator, hoặc hoàn tất ma trận 25 kịch bản acceptance thủ công.

**DEVICE/API TESTED_SHA: NONE.** Chưa xác nhận Android SDK, JDK, `adb`, thiết bị/emulator, tài khoản môi trường test hay API host. Thiếu kiểm tra này không phải kết quả PASS/FAIL của API hoặc thiết bị. Yêu cầu môi trường dự án xem [REQUIREMENTS.md](../../REQUIREMENTS.md#yêu-cầu-cài-đặt).

## Fixture generator

**FIXTURE_TOOL_TESTED_SHA:** `f5e225a5d4aa5d8e8e366770eb2bb4b0212621a6`. Parent đã chạy `python3 -m unittest discover -s qa/fixtures -p 'test_*.py' -v` — 6 test, exit 0; và `python3 qa/fixtures/generate_fixtures.py` — 20 file verified, exit 0. Đây chỉ là kiểm tra generator/fixture.
