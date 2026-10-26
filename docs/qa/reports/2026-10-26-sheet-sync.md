# Đồng bộ lỗi QA — 26/10/2026

Đã ghi và đọc lại thành công bốn mục trong tab `TESTING LỖI`, vùng `A10:V13` (sheetId `2122578546`). [Mở tab](https://docs.google.com/spreadsheets/d/1URTpbSX2k_04dvurVlJUbkP2iDILs618CKItSpDxjq4/edit#gid=2122578546). Readback xác nhận IDs `QH-QA-001`–`QH-QA-004`, trạng thái `Open`, Reporter `Sơn`, Assignee `Dũng`, Retest `Not retested`, và ngày 26/10/2026. Các dropdown vẫn tồn tại, các ô ngày B/R/T/U giữ định dạng `dd/MM/yyyy`. Dashboard sau ghi: Total Issues 4, Open / To Do 4; In Progress, Blocked, Ready for Retest và Fixed đều 0. Không có thay đổi tab nào khác được thực hiện.

| Issue Key | Phân loại | Severity / Priority | Nội dung |
|---|---|---|---|
| QH-QA-001 | Question Bank · Bug | Major / Medium | `LoadCubit` có thể ném `StateError` khi tải hoàn tất sau lúc cubit đóng. |
| QH-QA-002 | Question Bank · Validation | Major / Medium | Hai lựa chọn chỉ có ảnh khác nhau bị nhận nhầm là trùng. |
| QH-QA-003 | Exam · Crash | Major / Medium | `PlatformException` khi mở export không được xử lý. |
| QH-QA-004 | Other · Other | Minor / Low | Widget test đổi role tái dùng `ProfileCubit` cũ; lỗi fixture/test harness, không phải lỗi phân quyền production. |

Các mục dùng trạng thái `Open`, Reporter `Sơn`, Assignee `Dũng`, Retest `Not retested`; ngày phát hiện/cập nhật là 26/10/2026. Các hàng được ghi bằng request chỉ cập nhật `userEnteredValue`, giữ nguyên định dạng, validation và công thức của sheet.

## Nền tảng kiểm thử được ghi nhận

Source SHA `b949513b254bee55a3887e619786ea91f85b477f`; Linux x86_64 WSL2, Flutter 3.41.6 stable, Dart 3.11.4; API host và thiết bị: NONE cho bộ test. Full suite: 144 passed, 1 failed (fixture đổi role); `flutter analyze`: 0 issues. Web preview mock: 12 cases passed. APK QA Android arm64 build: exit 0; kiểm tra trên điện thoại/API vẫn pending. Chi tiết lỗi và repro: [báo cáo Dũng](https://github.com/tonhulily/QuizHub/blob/qa/khanhson2005/docs/qa/reports/2026-10-26-dung-review.md).

## Request và manifest

- `qa-artifacts/2026-10-26/sheet-sync/requestdraft/requests.json` — một yêu cầu `updateCells` cho A10:V13.
- `qa-artifacts/2026-10-26/sheet-sync/requestdraft/row-manifest.json` — manifest bốn hàng đã ghi.
