# Regression report — 2026-11-23

## Kết quả

Snapshot upstream được kiểm tra là `622640325b7c1b4bf0f3a5018ffd2635dce27061` (`main` snapshot `82ef14f38e086d6b558b392fc54a328c3d7f26a2`). Sau khi ghi baseline, coordinator cập nhật hai fixture test và tạo checkpoint `2f040844ee939317ac06da6a9d7473670f4213cd`; kết quả checkpoint được ghi riêng bên dưới.

Môi trường là Linux x86_64, Flutter 3.41.6 stable, Dart 3.11.4; không có API host hoặc thiết bị. Dùng `.qa-tools/pub-cache`, `--no-pub`, không tải/cài SDK hay dependencies. Lockfile có 141 package hosted và cả 141 phiên bản chính xác đều có trong cache. `.dart_tool/package_config.json` cũ thiếu Firebase và có 5 phiên bản lệch lock; config được dựng lại từ package map đã kiểm tra theo lock, dùng các Flutter SDK package của 3.41.6. Flutter 3.47.9 không dùng vì Flutter test SDK của nó không khớp các package test trong lockfile.

### Baseline — `622640325b7c1b4bf0f3a5018ffd2635dce27061`

| Lệnh | Exit | Kết quả quan sát |
|---|---:|---|
| `.qa-tools/flutter/bin/flutter analyze --no-pub` | 1 | 129 issues: 121 errors, 4 warnings, 4 info. 127 diagnostics nằm trong các bản sao/repro lưu ở `qa-artifacts/`; 2 diagnostics thuộc test hiện hành. |
| `.qa-tools/flutter/bin/flutter test --no-pub --reporter expanded` (sandbox) | 1 | Harness không bind được loopback (`127.0.0.1`); không dùng lượt này làm số test cuối. |
| Cùng lệnh full test với loopback access | 1 | 390 passed; 2 file test không compile. `auth_session_test.dart:156` truyền thiếu đối số thứ sáu cho `AuthRepository`; `ui_layout_regression_test.dart:167` thiếu tham số named `currentSemester` trong override. File layout được suite mặc định thu nhận, không có cờ opt-in. |
| `.qa-tools/flutter/bin/flutter analyze --no-pub lib test qa/repro` | 1 | Chỉ còn đúng hai lỗi compile fixture nói trên. |
| `.qa-tools/flutter/bin/dart format --output=none --set-exit-if-changed lib test qa/repro` | 1 | Kiểm tra 245 file; 12 file sẽ được formatter đổi. Lệnh check-only không ghi file. |
| `python3 qa/api/test_collection.py` | 0 | 3 test passed. |
| `python3 -m unittest discover -s qa/fixtures -p 'test_*.py' -v` | 0 | 6 test passed. |

### Checkpoint — `2f040844ee939317ac06da6a9d7473670f4213cd`

| Lệnh | Exit | Kết quả quan sát |
|---|---:|---|
| `.qa-tools/flutter/bin/flutter test --no-pub --reporter expanded` (loopback access) | 1 | 395 passed; 6 case trong `test/qa/ui_layout_regression_test.dart` failed. Hai lỗi là layout candidate: hàng danh sách hội thoại tràn 161 px và empty state tràn 341 px; bài feed tràn ngang 71/67/179/123 px. Bốn lỗi còn lại là test harness: hai finder/scroll của comments không tìm thấy widget; fake `_Subjects` thiếu `enrolledClasses()` gây lỗi và `pumpAndSettle` timeout ở question form; finder `dragUntilVisible` không tìm thấy element ở exam generator. Đây là widget harness local, chưa phải xác nhận trên thiết bị. |
| `.qa-tools/flutter/bin/flutter analyze --no-pub lib test qa/repro` | 0 | `No issues found`. |
| `.qa-tools/flutter/bin/dart format --output=none --set-exit-if-changed lib test qa/repro` | 1 | Vẫn 12 file sẽ được formatter đổi; lệnh check-only không sửa chúng. |

Full suite mặc định đã bao gồm `test/qa/ui_layout_regression_test.dart`. Test `test/core/fcm_pending_queue_test.dart` “opens a second tapped notification after first navigation completes” passed. Lượt test xác nhận hai fixture compile đã được sửa; sáu layout/harness failures được giữ tách bạch như trên. Kết quả Python từ baseline vẫn áp dụng cho checkpoint vì checkpoint chỉ đổi hai fixture Dart test.

Analyzer toàn repo đã quét cả `qa-artifacts/`, nên 127 diagnostics trong snapshot/repro cũ không đại diện lỗi trên source hiện hành. Scoped analyzer trên các thư mục source/test/repro cho kết quả rõ: hai compile lỗi ở baseline, rồi sạch trên checkpoint.

## Thời gian và log

Thời gian UTC, lệnh đầy đủ, output và exit code được lưu trong ignored logs:

- Baseline logs: `qa-artifacts/2026-11-23/regression/`
- Checkpoint logs: `qa-artifacts/2026-11-23/regression/checkpoint-2f040844/`
- Trích đoạn đã chọn, không chứa thông tin nhạy cảm: [evidence](../evidence/2026-11-23/regression/results.txt)

Formatter check-only báo 12 file cần format: `lib/core/firebase/firebase_messaging_service.dart`, `test/core/firebase_fid_sync_service_test.dart`, `test/core/firebase_messaging_service_test.dart`, `test/core/paged_cubit_test.dart`, `test/data/notification_repository_test.dart`, `test/data/push_notification_payload_test.dart`, `test/data/search_models_test.dart`, `test/features/async_close_lifecycle_test.dart`, `test/features/notification_cubit_test.dart`, `test/features/notification_navigator_test.dart`, `test/features/report_sheet_test.dart`, `test/helpers/fake_firebase_messaging_gateway.dart`. Không file nào được ghi bởi lệnh check-only.

Không chụp screenshot. Đây là kiểm thử local unit/widget với fixture; không có API thật, app trên thiết bị hoặc acceptance case nào được đánh dấu PASS từ kết quả này.
