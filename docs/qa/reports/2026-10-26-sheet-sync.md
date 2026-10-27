# Đồng bộ lỗi QA — cập nhật 27/10/2026

Tracker là tab `TESTING LỖI`, sheetId `2122578546` trong [spreadsheet](https://docs.google.com/spreadsheets/d/1URTpbSX2k_04dvurVlJUbkP2iDILs618CKItSpDxjq4/edit#gid=2122578546). Bốn hàng `A10:V13` giữ IDs `QH-QA-001`–`QH-QA-004`, trạng thái `Open`, Reporter `Sơn`, Assignee `Dũng` và Retest `Not retested`. Readback ngày 27/10 xác nhận `U10:U13` là 27/10/2026; ngày phát hiện `B10:B13` vẫn là 26/10/2026; `R`/`T` vẫn trống. Dropdowns và định dạng ngày `dd/MM/yyyy` được giữ nguyên. Dashboard vẫn ghi Total Issues 4, Open / To Do 4 và 0 ở In Progress, Blocked, Ready for Retest, Fixed.

| Issue Key | Phân loại | Severity / Priority | Nội dung |
|---|---|---|---|
| QH-QA-001 | Question Bank · Bug | Major / Medium | `LoadCubit` có thể ném `StateError` khi tải hoàn tất sau lúc cubit đóng. |
| QH-QA-002 | Question Bank · Validation | Major / Medium | Hai lựa chọn chỉ có ảnh khác nhau bị nhận nhầm là trùng. |
| QH-QA-003 | Exam · Crash | Major / Medium | `PlatformException` khi mở export không được xử lý. |
| QH-QA-004 | Other · Other | Minor / Low | Widget test đổi role tái dùng `ProfileCubit` cũ; vấn đề thuộc fixture/test harness, không phải lỗi phân quyền production. |

Ba lỗi P2 và một vấn đề test harness vẫn `Open / Not retested`. Native smoke không phải fix retest. Không xác nhận real API/backend.

## Kết quả kiểm thử

App source được kiểm tra tại SHA `b949513b254bee55a3887e619786ea91f85b477f`; Linux x86_64 WSL2, Flutter 3.41.6 stable, Dart 3.11.4. Full Flutter suite: 144 pass, 1 fail (fixture đổi role); `flutter analyze`: 0 issues; web preview mock: 12 cases pass; APK QA Android arm64 build: exit 0.

Native smoke diễn ra ngày 26/10 trên QA app riêng: 5 PASS, 2 BLOCKED/inconclusive, dùng mock/local data, không gọi real API. MCP báo gỡ QA preview thành công; truy vấn `adb shell pm path vn.edu.hust.quizhub.qa.preview` kết thúc exit 1 và không trả đường dẫn package. Không kết nối hoặc truy cập lại điện thoại trong phiên chốt báo cáo ngày 27/10 theo yêu cầu của Sơn. Không có ảnh native nào được coi là bằng chứng tái hiện ba lỗi P2. Lượt chạy trước đây ghi “native UI/API pending” nay đã được hoàn tất một phần như mô tả trên; phần API vẫn chưa được chạy.

## Link bằng chứng đã đọc lại từ tracker

P10:P13 dùng commit evidence ghim `79fa46cf1235ebc11723695985a5bd78bde1693a`:

- Báo cáo tổng hợp: [2026-10-26-dung-review.md](https://github.com/tonhulily/QuizHub/blob/79fa46cf1235ebc11723695985a5bd78bde1693a/docs/qa/reports/2026-10-26-dung-review.md)
- Báo cáo lượt native: [2026-10-26-mobile-ui-setup.md](https://github.com/tonhulily/QuizHub/blob/79fa46cf1235ebc11723695985a5bd78bde1693a/docs/qa/reports/2026-10-26-mobile-ui-setup.md)
- Repro source local cho ba lỗi: [LoadCubit](https://github.com/tonhulily/QuizHub/blob/79fa46cf1235ebc11723695985a5bd78bde1693a/docs/qa/evidence/2026-10-26/repros/cubit_lifecycle_repro_test.dart.txt), [image-only options](https://github.com/tonhulily/QuizHub/blob/79fa46cf1235ebc11723695985a5bd78bde1693a/docs/qa/evidence/2026-10-26/repros/image_only_options_repro_test.dart.txt), [export PlatformException](https://github.com/tonhulily/QuizHub/blob/79fa46cf1235ebc11723695985a5bd78bde1693a/docs/qa/evidence/2026-10-26/repros/export_platform_exception_repro_test.dart.txt).
- Ảnh native tại cùng commit: [QBank after submit](https://github.com/tonhulily/QuizHub/blob/79fa46cf1235ebc11723695985a5bd78bde1693a/docs/qa/evidence/2026-10-26/android-ui/qbank-after-submit.png) và [QBank stats](https://github.com/tonhulily/QuizHub/blob/79fa46cf1235ebc11723695985a5bd78bde1693a/docs/qa/evidence/2026-10-26/android-ui/qbank-stats.png) là ngữ cảnh PASS; [exam detail](https://github.com/tonhulily/QuizHub/blob/79fa46cf1235ebc11723695985a5bd78bde1693a/docs/qa/evidence/2026-10-26/android-ui/exam-detail.png) và [exam AI result visible](https://github.com/tonhulily/QuizHub/blob/79fa46cf1235ebc11723695985a5bd78bde1693a/docs/qa/evidence/2026-10-26/android-ui/exam-ai-result-visible.png) cũng chỉ là ngữ cảnh PASS. Ảnh [exam AI dismiss blank screen](https://github.com/tonhulily/QuizHub/blob/79fa46cf1235ebc11723695985a5bd78bde1693a/docs/qa/evidence/2026-10-26/android-ui/exam-ai-dismiss-blank-screen.png) được đánh dấu BLOCKED/inconclusive, không chứng minh lỗi export hay lỗi sản phẩm.
- QH-QA-004 là lỗi harness: không có ảnh native nào làm bằng chứng cho việc `ProfileCubit` bị tái sử dụng trong widget test. Ảnh web [exam generated](https://github.com/tonhulily/QuizHub/blob/79fa46cf1235ebc11723695985a5bd78bde1693a/docs/qa/evidence/2026-10-26/web-ui/exam-generated.png) chỉ là ngữ cảnh PASS.

Các URL trên đã được đọc lại tại tracker: cột P cho từng issue, và phần tổng kết mới nhất tại V13. V10:V12 vẫn giữ nguyên ghi chú repro cục bộ. Ngày phát hiện, trạng thái, kết quả retest, chủ sở hữu và các tab khác không được thay đổi trong lần cập nhật này.
