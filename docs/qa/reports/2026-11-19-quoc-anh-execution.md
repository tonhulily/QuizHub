# QA execution Quốc Anh — 19/11/2026

## Kết quả compile gate

- **Checkpoint:** `2cf8ef3cfaa93928607b338d794ea3c46f7eb8b0` trên `qa/khanhson2005`; worktree sạch trước khi chạy. Đây là checkpoint QA, không phải snapshot `main`.
- Các lệnh retry dùng cùng source/test inputs, không có runtime hoặc dependency thay đổi; vì vậy `TESTED_SHA` vẫn là checkpoint trên. Sau lần compile thử 3.41.6, report/evidence QA mới xuất hiện dưới dạng untracked; worktree không còn sạch tại các lượt 3.47.9.
- **MAIN_SNAPSHOT:** `origin/main` tại `08a5a2e4097923d21bbdaf7d02cb1792f2171aa3`.
- **TESTED_SHA:** `2cf8ef3cfaa93928607b338d794ea3c46f7eb8b0` (lệnh Flutter chạy trực tiếp trên HEAD này).
- Coordinator xác nhận `origin/main` là ancestor của checkpoint; diff `lib android ios pubspec.yaml pubspec.lock` giữa HEAD và main rỗng. Đây chỉ là grounding về source delta, không thay compile evidence.
- **Môi trường compile gate:** Linux x86_64; Flutter 3.47.9 stable, Dart 3.13.7; SDK `.qa-tools/sdk-3.47.9/flutter`; `XDG_CONFIG_HOME=$PWD/.qa-tools/config`, `XDG_CACHE_HOME=$PWD/.qa-tools/cache`, `PUB_CACHE=$PWD/.qa-tools/pub-cache`, `FLUTTER_SUPPRESS_ANALYTICS=true`, `CI=true`; `--no-pub`. Không dùng API host hay thiết bị. Flutter version command exit 0.
- **Lệnh compile gate:** `./.qa-tools/sdk-3.47.9/flutter/bin/flutter test --no-pub --reporter expanded test/qa/exam_export_regression_test.dart`
- **Exit:** `1`. Compiler diagnostics: `lib/core/design_system/app_theme.dart:196:35: Error: Method not found: 'CupertinoPageTransitionsBuilder'.` và cùng lỗi tại `197:31`; probe không load và test body **chưa chạy**. Đây là compile blocker quan sát được trên SDK khớp baseline.
- **Trạng thái app/UI gate:** **BLOCKED**; dừng các probe UI phụ thuộc importer `AppTheme`, không sửa probe, runtime hoặc dependency.

Lần thử ban đầu với Flutter 3.41.6/Dart 3.11.4 gặp cached `objective_c` 9.5.0 hook kernel incompatibility (`expected 127, found 138`) trước khi tới app compile. Lượt đó exit 1 và được giữ nguyên để phân biệt môi trường; không dùng làm kết luận compile.

Logs đầy đủ và version: [compile với Flutter 3.47.9](../../../qa-artifacts/2026-11-19/quoc-anh/exam-export-compile-gate-3.47.9.log), [lần thử Flutter 3.41.6](../../../qa-artifacts/2026-11-19/quoc-anh/exam-export-compile-gate.log), [Flutter 3.47.9](../../../qa-artifacts/2026-11-19/quoc-anh/flutter-version-3.47.9.log), [Flutter 3.41.6](../../../qa-artifacts/2026-11-19/quoc-anh/flutter-version.log). Chat probe log: [chat-preview-local-3.47.9.log](../../../qa-artifacts/2026-11-19/quoc-anh/chat-preview-local-3.47.9.log). Evidence tóm tắt: [`compile-gate.txt`](../evidence/2026-11-19/quoc-anh/compile-gate.txt).

## Review probe trước khi chạy

- `test/qa/chat_preview_regression_test.dart`: hai phần bao gồm `PreviewBackend` và `ChatDemoServer` localhost, tạo REST/WebSocket clients giả, token demo, dữ liệu sentinel. Assertion xác nhận summary/deletion/restart theo fixture/mock; host loopback và timing/retry có thể ảnh hưởng runner. Không xác nhận server/API thật hoặc hành vi native. Import graph không đi qua `AppTheme`; chạy độc lập được với Flutter 3.47.9.
- `test/qa/exam_export_regression_test.dart`: widget test với `ExamRepository` giả và mock `url_launcher` ném `PlatformException`; assertion xác nhận phản hồi UI/exception trong harness. Host tự dựng `MaterialApp`, EasyLoading, role helper và kích thước view; không kiểm tra exporter/backend/file thật hoặc native launcher. Đây là probe chọn chạy để chạm compile gate qua importer UI liên quan.
- `test/qa/ui_layout_regression_test.dart`: widget tests dùng fixture/repository giả, host `MaterialApp` với theme, role và một số ca màn 320×640/text scale 2/keyboard. Assertions về finder/rect/hit testing chỉ phản ánh layout trong harness; phụ thuộc cấu trúc host, scrollables và animation, không chứng minh trên thiết bị. Không chạy do compile gate bị chặn.

## Trạng thái phạm vi

- `BUILD-THEME-001` / `QH-QA-005`: **BLOCKED** tại compile gate; lỗi `CupertinoPageTransitionsBuilder` được quan sát trên Flutter 3.47.9. `exam_export_regression_test.dart` không load, test body chưa chạy.
- `CHAT-DEL-01` — local subsets only: test `preview list summary falls back after revoked message is deleted ME and restart` và test `shared REST summaries stay user-specific after revoked message is deleted ME and restart` đều chạy, tổng **2 PASS**, exit 0 với Flutter 3.47.9 sau khi cho phép bind loopback. Chúng dùng `PreviewBackend`/`ChatDemoServer` local, không phải API/backend acceptance. Full CHAT-DEL-01 app flow (menu, back/relaunch và quan sát UI hai phía) vẫn **BLOCKED**.
- `QH-QA-010..012`: **NOT RUN**, không có fresh UI repro/confirmed finding trong lượt này.
- API/realtime hai tài khoản: **BLOCKED**, chưa có API host và tài khoản A/B.
- Các assertion về business rule/server chưa có contract/owner xác nhận: **WAITING**.
- Native UI/iOS: **BLOCKED / NOT RUN** trong phiên này; không có lần chạy thiết bị mới.
- Snapshot tracker coordinator đọc ngày 19/11 trước cập nhật coordinator: 9 issue (8 Open; `QH-QA-009` Closed/Pass; tại snapshot đó `QH-QA-005` Open/Not retested, owner Tố Như). Không dùng đây làm trạng thái tracker mới nhất.

## Giới hạn

Compile gate xác nhận source compile blocker ở `AppTheme`; chat local xác nhận hai invariant trong fixture/mock. Không cài/cập nhật SDK hoặc package, không sửa app/dependencies. API/A+B và native UI chưa được thực hiện.
