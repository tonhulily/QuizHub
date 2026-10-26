# Báo cáo QA: dung merge vào QA

**Kết quả:** Chưa nên chấp nhận ngay. Có 3 lỗi P2 đã tái hiện và 1 test harness cần sửa. Không sửa mã runtime trong lần review này. Báo cáo và evidence chọn lọc được lưu trong nhánh QA; bulk logs nằm trong `qa-artifacts/` bị ignore.

## Phạm vi và nguồn

- `main` trước merge: `6ee7f6d9a9a9d2342803c41a32f8dd03ac7a0d48`
- Commit dung: `bd1d7b098252bc2707c70f06f2715a5ee416ffe6`
- Trạng thái QA được kiểm tra: `b949513b254bee55a3887e619786ea91f85b477f`
- Trước khi merge: `e44594d460146687bcb048cab4c36aee973dd158`
- Môi trường: Linux x86_64 WSL2, Flutter 3.41.6 stable, Dart 3.11.4; không có API host hoặc thiết bị.
- Bằng chứng cục bộ (được `.gitignore` loại trừ): [`qa-artifacts/2026-10-26/dung-review`](../../../qa-artifacts/2026-10-26/dung-review/).

## Lỗi đã xác nhận

Các lỗi và mục theo dõi test đã ghi vào tracker chuẩn [tab TESTING LỖI](https://docs.google.com/spreadsheets/d/1URTpbSX2k_04dvurVlJUbkP2iDILs618CKItSpDxjq4/edit#gid=2122578546): `QH-QA-001` đến `QH-QA-004` đang **Open**, chưa retest.

1. **QH-QA-001 · P2 — Tải xong sau khi rời màn hình gây `StateError`** — `lib/features/question_bank/cubit/load_cubit.dart:34`
   - **Tình huống:** mở màn chi tiết/thống kê rồi rời màn hình trước khi request kết thúc. `BlocProvider` đóng cubit; khi loader trả về, `load()` vẫn gọi `emit`.
   - **Kết quả:** `StateError` thoát khỏi future tải chưa được await ở nơi gọi, tạo lỗi async không xử lý.
   - **Sửa tối thiểu:** kiểm tra `isClosed` trước các lần emit sau await (cả nhánh thành công và lỗi).
   - **Tái hiện:** harness `qbank/cubit_lifecycle_repro_test.dart`, case `LoadCubit completion after close`; exit 0 vì harness xác nhận exception. Log: [`qbank/cubit-lifecycle.log`](../../../qa-artifacts/2026-10-26/dung-review/qbank/cubit-lifecycle.log).

2. **QH-QA-002 · P2 — Không nộp được câu có hai phương án chỉ gồm ảnh** — `lib/features/question_bank/cubit/submission_form_cubit.dart:64-66`
   - **Tình huống:** hai phương án có ảnh khác nhau và text rỗng. Validator cho phép text rỗng nếu có `mediaUrl` (dòng 59-62), và form có nút thêm ảnh riêng cho từng phương án.
   - **Kết quả:** cả hai text thành `''`, bị báo trùng dù ảnh khác nhau; người dùng không thể nộp phiên hợp lệ.
   - **Sửa tối thiểu:** chỉ so trùng các text không rỗng; giữ kiểm tra nội dung/ảnh của từng lựa chọn.
   - **Tái hiện:** `qbank/image_only_options_repro_test.dart`, case `two distinct image-only options are accepted`; validator trả `Câu 1: có hai phương án trùng nhau.` Log: [`qbank/image-only-validation.log`](../../../qa-artifacts/2026-10-26/dung-review/qbank/image-only-validation.log). Test thoát 1 theo dự kiến vì kỳ vọng hiện tại không đạt.

3. **QH-QA-003 · P2 — Lỗi mở link export thoát khỏi màn hình, không báo người dùng** — `lib/features/exam/view/exam_detail_view.dart:93-99`
   - **Tình huống:** API export trả link hợp lệ nhưng nền tảng không có ứng dụng xử lý URL, `url_launcher` ném `PlatformException(ACTIVITY_NOT_FOUND)`.
   - **Kết quả:** `_export` chỉ bắt `ApiException`, nên exception thoát ra ngoài và không hiển thị feedback.
   - **Sửa tối thiểu:** bắt `PlatformException` tại đây và dùng feedback lỗi sẵn có như trường hợp `launchUrl` trả false.
   - **Tái hiện:** case `EX-EXPORT-PLATFORM-001`, fake repository trả URL hợp lệ, launcher giả ném lỗi nền tảng; test xác nhận exception thoát (exit 1 theo kỳ vọng lỗi). Log và harness: [`exam-ai/export-platform-exception.log`](../../../qa-artifacts/2026-10-26/dung-review/exam-ai/export-platform-exception.log), [`exam-ai/export_platform_exception_repro_test.dart`](../../../qa-artifacts/2026-10-26/dung-review/exam-ai/export_platform_exception_repro_test.dart).

## QH-QA-004 · Cần sửa test harness

Test `exam_ui_test.dart` thay vai trò bằng cách gọi `pumpWidget` lần nữa nhưng helper `fake_profile.dart` dựng provider bằng `create`; Flutter giữ provider cũ nên vai trò vẫn là `student`, làm test nút AI thất bại giả. Đây là vấn đề test, không phải lỗi quyền runtime đã xác nhận. Sửa fixture để unmount/recreate provider hoặc dùng key phù hợp. Instrumented log cho thấy `student` trước và sau lần pump lecturer; bản tạm unmount rồi dựng lại chạy đủ 10 test. Bằng chứng: [`execution/exam-ui-instrumented.log`](../../../qa-artifacts/2026-10-26/dung-review/execution/exam-ui-instrumented.log), [`execution/exam-ui-unmount.log`](../../../qa-artifacts/2026-10-26/dung-review/execution/exam-ui-unmount.log).

## Kết quả kiểm tra

| Lệnh / case | Kết quả | Bằng chứng |
|---|---|---|
| `flutter test --no-pub --reporter expanded` | 144 đạt, 1 lỗi, exit 1 | [`execution/flutter-test.log`](../../../qa-artifacts/2026-10-26/dung-review/execution/flutter-test.log) |
| `flutter test --no-pub --reporter expanded test/features/exam_ui_test.dart` | 9 đạt, 1 lỗi, exit 1 | [`execution/exam-ui-targeted.log`](../../../qa-artifacts/2026-10-26/dung-review/execution/exam-ui-targeted.log) |
| Bản test instrumented ghi vai trò trước/sau khi đổi sang giảng viên | Vẫn là `student`; lỗi test do provider fake được tái sử dụng, không phải lỗi quyền runtime đã xác nhận | [`execution/exam-ui-instrumented.log`](../../../qa-artifacts/2026-10-26/dung-review/execution/exam-ui-instrumented.log) |
| Bản test tạm unmount provider trước khi đổi vai trò | 10 đạt, exit 0; không sửa test nguồn | [`execution/exam-ui-unmount.log`](../../../qa-artifacts/2026-10-26/dung-review/execution/exam-ui-unmount.log) |
| `flutter test --no-pub test/features/question_bank_ui_test.dart` | 11 đạt, exit 0 | [`qbank/ui-focused.log`](../../../qa-artifacts/2026-10-26/dung-review/qbank/ui-focused.log) |
| `flutter analyze --no-pub` | Không có issue, exit 0 | [`execution/flutter-analyze.log`](../../../qa-artifacts/2026-10-26/dung-review/execution/flutter-analyze.log) |
| `dart format --output=none --set-exit-if-changed lib test qa/repro` | 148 file; 7 file cần format, exit 1 | [`execution/dart-format.log`](../../../qa-artifacts/2026-10-26/dung-review/execution/dart-format.log) |
| `python3 qa/api/test_collection.py` và `python3 -m unittest discover -s qa/fixtures -p test_*.py -v` | 3 API-contract và 6 fixture test đạt, exit 0 | [`execution/python-qa.log`](../../../qa-artifacts/2026-10-26/dung-review/execution/python-qa.log) |

Lệnh Flutter/Dart dùng SDK cô lập theo [môi trường QA](../ENVIRONMENT.md): `.qa-tools/flutter/bin/flutter`, XDG/cache/PUB_CACHE trong `.qa-tools/`, không cài dependency. Harness QBank dùng `XDG_CONFIG_HOME=/tmp/flutter-config`; harness export dùng `/tmp/quizhub-flutter-config`. Flutter test cần quyền bind cổng localhost tạm.

## Còn chờ

- Test API/UI/E2E trên backend, thiết bị và tài khoản thật: **BLOCKED**, chưa có API host/tài khoản/thiết bị.
- Browser UI đã chạy trên web preview in-memory tại SHA nguồn đã nêu; xem [báo cáo web UI](2026-10-26-web-ui.md). API thật, thiết bị native và acceptance trên app điện thoại vẫn **BLOCKED/NOT RUN**; preview không thay thế các kiểm tra đó.
- Các placeholder chưa có contract rõ ràng tiếp tục là **WAITING**, không tính là lỗi.
