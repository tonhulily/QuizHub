# Môi trường QA

Ghi nhận cập nhật **2026-10-22** trên nhánh `qa/khanhson2005`, sau merge commit `74c8ea16b05733a2e5620dc48f3c52cc6867c3b6`. SDK Flutter và package cache tạm từ hôm trước đã bị dọn khỏi `/tmp`. Sơn đã duyệt setup SDK persistent trong `.qa-tools/flutter` và cache `.qa-tools/pub-cache`; delegate đang chuẩn bị chúng. Chưa xác nhận lệnh chạy được cho đến khi setup hoàn tất.

## Flutter local runner

Lịch sử phiên 2026-10-21: Flutter 3.41.6 stable / Dart 3.11.4 từng được cài tại `/tmp/quizhub-qa-sdk/flutter`; SHA-256 archive đã xác minh là `503b3e6b7d352fca5d21b6474eca95ad544d8fc3b053782eab63a360c7fc7569`. Package cache tạm từng ở `/tmp/quizhub-pub-cache`; `flutter pub get --enforce-lockfile` hoàn tất và `pubspec.lock` có SHA-256 `4069b6a766720cba6b6ec17891ecc9c6b5d448bed16f5af8d7d0f1552eedc7d0`. Hai thư mục đó hiện không còn; đây là lịch sử bootstrap, không phải vị trí hiện tại.

Sau khi setup persistent được xác minh, ghi path/version thực tế và dùng chúng cho lệnh QA. Không pin SDK toàn cục hoặc vào cấu hình editor.

**Lịch sử Flutter đã test, không áp dụng cho merge SHA `74c8ea16b05733a2e5620dc48f3c52cc6867c3b6`:** `d58cdf01a4b2e04a41901e8804fe1d49847faccf`.

- `flutter test --no-pub`: 95 test passed, exit 0. Log: [flutter-regression-d58cdf0-local-runner.log](../../qa-artifacts/flutter-regression-d58cdf0-local-runner.log).
- `dart format --output=none --set-exit-if-changed lib test`: 112 files, 0 changed, exit 0. Log: [dart-format-d58cdf0.log](../../qa-artifacts/dart-format-d58cdf0.log).
- Lượt `flutter test` trong sandbox mặc định không chạy được do runner không bind được loopback `127.0.0.1` cho 13 test loader; lần chạy local runner được duyệt ở trên đã thành công. Chi tiết: [flutter-regression-d58cdf0.log](../../qa-artifacts/flutter-regression-d58cdf0.log).
- `flutter analyze` trước đó báo `No issues found` tại SHA `f5e225a5d4aa5d8e8e366770eb2bb4b0212621a6`; đầu ra của lượt đó không được lưu thành log. Đây không phải kết quả analyzer sau commit `d58cdf0`.

Tại checkpoint merge `74c8ea16b05733a2e5620dc48f3c52cc6867c3b6`, Flutter analyze, format check, test suite và Flutter risk reproductions **NOT RUN**, đang chờ setup persistent đã được duyệt. Kết quả 95 PASS / 2 repro FAIL ở trên chỉ mô tả SHA cũ. Chưa có API host/account nên API/UI/device acceptance vẫn NOT RUN.

95 test là unit/widget automation chạy trên local runner; không xác nhận tích hợp API từ xa, hành vi trên thiết bị/emulator, hoặc hoàn tất ma trận 25 kịch bản acceptance thủ công.

**DEVICE/API TESTED_SHA: NONE.** Chưa xác nhận Android SDK, JDK, `adb`, thiết bị/emulator, tài khoản môi trường test hay API host. Thiếu kiểm tra này không phải kết quả PASS/FAIL của API hoặc thiết bị. Yêu cầu môi trường dự án xem [REQUIREMENTS.md](../../REQUIREMENTS.md#yêu-cầu-cài-đặt).

## OpenAPI static review

OpenAPI công khai được rà soát tĩnh: 128 paths, 33 operation duy nhất (method/path) đối chiếu với 41 request trong collection; tài liệu có hash rút gọn `63dc2323…939cc5`. `python3 qa/api/test_collection.py`: 3 offline Python tests PASS, exit 0 tại source `74c8ea16b05733a2e5620dc48f3c52cc6867c3b6`; log [api-contract-74c8ea1.log](../../qa-artifacts/2026-10-22/api-contract-74c8ea1.log). Sơn chưa có API host/account; đây không phải kiểm tra Postman import, API business hay backend.

## Fixture generator

**FIXTURE_TOOL_TESTED_SHA:** `f5e225a5d4aa5d8e8e366770eb2bb4b0212621a6`. Parent đã chạy `python3 -m unittest discover -s qa/fixtures -p 'test_*.py' -v` — 6 test, exit 0; và `python3 qa/fixtures/generate_fixtures.py` — 20 file verified, exit 0. Đây chỉ là kiểm tra generator/fixture.
