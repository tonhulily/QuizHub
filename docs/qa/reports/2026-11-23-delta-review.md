# Rà soát delta minigame, qbank và push/report

- **QA source SHA:** `622640325b7c1b4bf0f3a5018ffd2635dce27061` (merge `origin/main` `82ef14f38e086d6b558b392fc54a328c3d7f26a2`).
- **Delta được giao:** `main` `08a5a2e4097923d21bbdaf7d02cb1792f2171aa3..82ef14f38e086d6b558b392fc54a328c3d7f26a2`.
- **Môi trường/lệnh:** code review trong checkout QA; chưa chạy Flutter/widget, preview hoặc API business flow. Đã tải public OpenAPI JSON bằng `curl -L --max-time 25` (HTTP 200, 488833 bytes, exit 0; SHA-256 `f031f885a87340067daaabdb680992077c6a2f222b6ed4fc75dc504dc2ff0401`) sau sandbox DNS failure và một approved retry. Schema OpenAPI 3.1.0 liệt kê `GET /sessions/my-enrolled-course-classes` và các route minigame; đây chỉ là contract route presence. Regression đang do coordinator điều phối; lệnh dưới đây đề xuất sau cache gate.
- **Phạm vi:** minigame, `GET /sessions/my-enrolled-course-classes`, report target labels, push settings confirm và disabled controls.

| Case | Quan sát tĩnh / coverage sẵn có | Trạng thái trên SHA này |
|---|---|---|
| MG-01 Hub, mở Game 1; MG-02 validation và ghi nhận Game 1; MG-03 Game 4 chốt và khóa đoán lại; MG-04 leaderboard theo môn báo lỗi/thử lại | `test/features/minigame_ui_test.dart` có widget cases và fake repositories. | **NOT RUN** — test file/code không phải bằng chứng chạy. Game 2 và API/backend thật chưa được xác minh. |
| QB-ENROLLED-01 đổi endpoint enrolled classes và lọc lớp cho submission form | `SubjectRepository.enrolledClasses()` dùng `ApiEndpoints.myEnrolledCourseClasses`; `enrolled()` gộp subject, lọc `activeSemester` khi yêu cầu. `test/features/question_bank_ui_test.dart` fake lớp hiện tại/cũ và `canPropose`; chưa thấy test xác minh HTTP method/path/parse qua API client cho endpoint này. Public schema có `GET /sessions/my-enrolled-course-classes` (evidence: [`openapi.txt`](../evidence/2026-11-23/delta/openapi.txt)). | **NOT RUN** — route được tài liệu hóa, nhưng chưa gọi endpoint/backend hoặc xác minh payload/runtime. |
| REPORT-TARGET-01 tiêu đề/nội dung báo cáo theo post/comment/user | `test/features/report_sheet_test.dart` kiểm tra đủ ba target. Caller static: post card, comments sheet và friend actions. | **NOT RUN** |
| PUSH-SETTINGS-01 khóa switch con khi master off; PUSH-SETTINGS-02 xác nhận Back khi dirty | `test/features/push_settings_view_test.dart` kiểm tra callback disabled/enabled và cả hai lựa chọn ở lại/bỏ thay đổi. | **NOT RUN** — chưa kiểm tra native/back gesture/thiết bị. |

Rà soát ban đầu không xác nhận defect ở các luồng delta. Riêng web preview có lỗi local đã xác nhận sau đó: xem [báo cáo web smoke](2026-11-23-web.md), đề xuất QH-QA-013; tracker chưa cập nhật. Checkpoint regression `2f040844ee939317ac06da6a9d7473670f4213cd` chạy full suite bằng Flutter 3.41.6/Dart 3.11.4: 395 passed, 6 failed; failures là hai layout candidates và bốn harness/finder failures, trong đó question-form fake thiếu `enrolledClasses()`. Chi tiết và log: [báo cáo regression](2026-11-23-regression.md). Đây là widget/unit suite tổng thể, không acceptance/API/native PASS; Game 2, endpoint thật và manual flows vẫn chưa được nghiệm thu.

## Lệnh regression đề xuất

Chạy sau khi coordinator xác nhận SDK/cache sẵn sàng, từ repo root và ghi exit code/log riêng:

```bash
XDG_CONFIG_HOME=/tmp/flutter-config FLUTTER_SUPPRESS_ANALYTICS=true .qa-tools/flutter/bin/flutter test --no-pub test/features/minigame_ui_test.dart
XDG_CONFIG_HOME=/tmp/flutter-config FLUTTER_SUPPRESS_ANALYTICS=true .qa-tools/flutter/bin/flutter test --no-pub test/features/question_bank_ui_test.dart
XDG_CONFIG_HOME=/tmp/flutter-config FLUTTER_SUPPRESS_ANALYTICS=true .qa-tools/flutter/bin/flutter test --no-pub test/features/report_sheet_test.dart test/features/push_settings_view_test.dart
```

Các lệnh là **đề xuất, chưa chạy**; exit code chưa có. Test fake chỉ hỗ trợ widget behavior, không thay API/backend hoặc native acceptance. Chưa tạo test QA mới vì các luồng UI được hỏi đã có test module hiện hữu; endpoint/API cần môi trường được cấp để kiểm chứng có ý nghĩa.
