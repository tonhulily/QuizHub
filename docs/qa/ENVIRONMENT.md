# Môi trường QA

Ghi nhận cập nhật **2026-10-22** trên nhánh `qa/khanhson2005`. Flutter persistent đã được setup và xác minh; thư mục `.qa-tools/` được ignore bởi Git. Phiên bản, archive checksum, pub get và lockfile evidence: [sdk-setup.log](../../qa-artifacts/2026-10-22/sdk-setup.log).

## Cập nhật QA ngày 2026-10-26

- Source app được kiểm tra: `b949513b254bee55a3887e619786ea91f85b477f`.
- `flutter test --no-pub --reporter expanded`: 144 passed, 1 failed, exit 1; lỗi fixture role trong test UI, chưa xác nhận runtime defect. `flutter analyze --no-pub`: 0 issues, exit 0. Chi tiết: [báo cáo review](reports/2026-10-26-dung-review.md).
- Web preview dùng `PreviewBackend` in-memory: 12 case PASS; không xác nhận API/backend thật. Xem [báo cáo web UI](reports/2026-10-26-web-ui.md).
- Native preview APK `vn.edu.hust.quizhub.qa.preview`, cùng source SHA, trên GT Neo2 / RMX3370 / Android 13 / API 33: 5 case PASS, 2 BLOCKED/INCONCLUSIVE; không gọi API host. Case và ảnh: [báo cáo mobile UI](reports/2026-10-26-mobile-ui-setup.md). Coordinator đã gỡ riêng QA app; MCP uninstall thành công, và `adb shell pm path vn.edu.hust.quizhub.qa.preview` trả exit 1 với output rỗng.
- Preview UI smoke cases độc lập với acceptance matrix; chúng không làm thay đổi trạng thái 19 NOT RUN / 6 WAITING.

## Flutter local runner

Flutter 3.41.6 stable / Dart 3.11.4 nằm trong `.qa-tools/flutter`; archive SHA-256 `503b3e6b7d352fca5d21b6474eca95ad544d8fc3b053782eab63a360c7fc7569` đã khớp manifest chính thức. Package cache ở `.qa-tools/pub-cache`; `flutter pub get --enforce-lockfile` exit 0 và `pubspec.lock` giữ SHA-256 `4069b6a766720cba6b6ec17891ecc9c6b5d448bed16f5af8d7d0f1552eedc7d0`. Kết quả Flutter checks theo source SHA được ghi ở phần dưới.

Từ root repo, dùng các biến terminal tạm sau:

```bash
export XDG_CONFIG_HOME="$PWD/.qa-tools/config"
export XDG_CACHE_HOME="$PWD/.qa-tools/cache"
export PUB_CACHE="$PWD/.qa-tools/pub-cache"
export FLUTTER_SUPPRESS_ANALYTICS=true CI=true
FLUTTER="$PWD/.qa-tools/flutter/bin/flutter"
```

Không pin SDK toàn cục hoặc vào cấu hình editor.

**Lịch sử Flutter đã test, không áp dụng cho merge SHA `74c8ea16b05733a2e5620dc48f3c52cc6867c3b6`:** `d58cdf01a4b2e04a41901e8804fe1d49847faccf`.

- `flutter test --no-pub`: 95 test passed, exit 0. Log: [flutter-regression-d58cdf0-local-runner.log](../../qa-artifacts/flutter-regression-d58cdf0-local-runner.log).
- `dart format --output=none --set-exit-if-changed lib test`: 112 files, 0 changed, exit 0. Log: [dart-format-d58cdf0.log](../../qa-artifacts/dart-format-d58cdf0.log).
- Lượt `flutter test` trong sandbox mặc định không chạy được do runner không bind được loopback `127.0.0.1` cho 13 test loader; lần chạy local runner được duyệt ở trên đã thành công. Chi tiết: [flutter-regression-d58cdf0.log](../../qa-artifacts/flutter-regression-d58cdf0.log).
- `flutter analyze` trước đó báo `No issues found` tại SHA `f5e225a5d4aa5d8e8e366770eb2bb4b0212621a6`; đầu ra của lượt đó không được lưu thành log. Đây không phải kết quả analyzer sau commit `d58cdf0`.

### Kiểm tra source cập nhật 2026-10-22

Các lần chạy được phân biệt theo source SHA. Môi trường: Linux x86_64 / WSL2, Flutter 3.41.6 stable, Dart 3.11.4, `.qa-tools/` isolated XDG/PUB_CACHE, không có API host hoặc thiết bị.

- Tại `f1951b0c03c5b21929414485101108c804c3ebd0`, `flutter test --no-pub --reporter expanded`: **98 PASS**, exit 0 ([log](../../qa-artifacts/2026-10-22/flutter-default-tests-f1951b0.log)).
- Cùng SHA, `flutter analyze --no-pub`: exit 1 do hai `invalid_use_of_visible_for_testing_member` warnings trong `qa/repro/network_risks_test.dart` ([log](../../qa-artifacts/2026-10-22/flutter-analyze-f1951b0.log)).
- Cùng SHA, `dart format --output=none --set-exit-if-changed lib test qa/repro`: exit 1; 114 files checked, hai file `lib/core/utils/validators.dart` và `test/core/school_email_test.dart` sẽ đổi. Đây là check-only; không format/modify file ([log](../../qa-artifacts/2026-10-22/dart-format-check-f1951b0.log)). Coordinator xác nhận hai file này đến từ upstream `main` snapshot `6ee7f6d9a9a9d2342803c41a32f8dd03ac7a0d48`; không tự ý format chúng.
- Tại `520c7381f0159ce40f9534ace1c657b87aa523d1`, `flutter analyze --no-pub`: exit 0, “No issues found” ([log](../../qa-artifacts/2026-10-22/analyze-520c738.log)); QA-only `dart format --output=none --set-exit-if-changed qa/repro`: 1 file/0 changes, exit 0 ([log](../../qa-artifacts/2026-10-22/format-check-520c738.log)); opt-in network repro: 2 invariant FAIL, exit 1 ([log](../../qa-artifacts/2026-10-22/repro-520c738.log)). Default tests không rerun tại SHA này vì thay đổi sau `f1951b0` chỉ suppress hai warning trong QA harness; runtime và default test code không đổi.

Lần chạy mặc định 98 PASS không xác nhận API, thiết bị, hay acceptance UI/E2E. Chưa có API host/account; API acceptance vẫn NOT RUN. Các lượt preview UI riêng ngày 2026-10-26 không thay thế acceptance matrix.

98 test là unit/widget automation chạy trên local runner; không xác nhận tích hợp API từ xa, hành vi trên thiết bị/emulator, hoặc hoàn tất ma trận 25 kịch bản acceptance thủ công.

**API_ACCEPTANCE_TESTED_SHA: NONE.** Chưa có API host/account để chạy API business acceptance. Android SDK/ADB và thiết bị đã được kiểm tra riêng cho QA preview như ghi ở trên; đây không phải API acceptance. Yêu cầu môi trường dự án xem [REQUIREMENTS.md](../../REQUIREMENTS.md#yêu-cầu-cài-đặt).

## OpenAPI static review

OpenAPI công khai được rà soát tĩnh: 128 paths, 33 operation duy nhất (method/path) đối chiếu với 41 request trong collection; tài liệu có hash rút gọn `63dc2323…939cc5`. `python3 qa/api/test_collection.py`: 3 offline Python tests PASS, exit 0 tại source `74c8ea16b05733a2e5620dc48f3c52cc6867c3b6`; log [api-contract-74c8ea1.log](../../qa-artifacts/2026-10-22/api-contract-74c8ea1.log). Sơn chưa có API host/account; đây không phải kiểm tra Postman import, API business hay backend.

## Fixture generator

**FIXTURE_TOOL_TESTED_SHA:** `f5e225a5d4aa5d8e8e366770eb2bb4b0212621a6`. Parent đã chạy `python3 -m unittest discover -s qa/fixtures -p 'test_*.py' -v` — 6 test, exit 0; và `python3 qa/fixtures/generate_fixtures.py` — 20 file verified, exit 0. Đây chỉ là kiểm tra generator/fixture.
