# Rà upstream `main` — 15/11/2026

## Kết quả và phạm vi

Rà tĩnh, chưa nghiệm thu runtime. Upstream được rà từ `c34bc531404d4fdcd3c788a1afa843bddf13bf58` đến merge `08a5a2e4097923d21bbdaf7d02cb1792f2171aa3`: **19 commits, 101 files, +12.166/-491 dòng**. Nguồn QA hiện tại là `adde556e2ef6e481fd7145588db878012673b059`; đây là SHA được giao để xem xét, không phải SHA đã chạy kiểm thử.

Delta tập trung vào:

- Feed/bài viết mẫu được lưu qua lần mở app; mở chi tiết bài từ vùng trống của thẻ.
- Block state phía client: lọc/ẩn nội dung quan hệ, bài, bình luận và hội thoại; chặn thao tác liên quan, xử lý danh sách block nhiều trang.
- Chat REST/STOMP: danh sách và lịch sử hội thoại, gửi chữ/ảnh, trạng thái đọc/typing, reconnect, xác nhận gửi; khóa gửi khi một bên block. Có nhánh demo chat hai tài khoản với persistence riêng.
- Reaction cho bình luận/phản hồi; thêm hướng dẫn QA chat/iOS và cấu hình Xcode/CocoaPods.

`feature/search` tại `639da12` còn **17 commits** chưa có trong merge SHA, gồm global search, notification/FCM/settings và thay đổi menu. Chỉ thống kê, không merge. Một số code demo/mock và local persistence không chứng minh hành vi với API thật.

## Đối chiếu issue cũ

Các so sánh nguồn dưới đây chỉ là **static candidate**. Tracker trước đây ghi `QH-QA-001..004` Open / Not retested; báo cáo này không xác nhận fix và không thay đổi tracker.

| Issue | Dấu hiệu tại merge SHA | Trạng thái QA đề nghị |
|---|---|---|
| QH-QA-001 | `LoadCubit.load` kiểm tra `isClosed` sau await ở cả nhánh thành công/lỗi tại `lib/features/question_bank/cubit/load_cubit.dart:36-50`; widget test có case đóng cubit trước khi future hoàn tất tại `test/features/question_bank_ui_test.dart` (nhóm LoadCubit, khoảng dòng 438). | Static candidate; retest NOT RUN. Giữ Open đến khi chạy regression tại SHA được ghi nhận. |
| QH-QA-002 | Validator chỉ thêm text không rỗng vào tập so trùng tại `lib/features/question_bank/cubit/submission_form_cubit.dart:148-159`; test widget có trường hợp hai option chỉ có ảnh khác nhau tại `test/features/question_bank_ui_test.dart:334-354`. | Static candidate; retest NOT RUN. Cần chạy form/regression, không suy ra từ test tồn tại. |
| QH-QA-003 | `_export` bắt `PlatformException` của `launchUrl` và hiển thị feedback lỗi tại `lib/features/exam/view/exam_detail_view.dart:93-108`. | Static candidate; retest NOT RUN. Kịch bản launcher ném exception chưa được chạy lại trên SHA này/thiết bị. |
| QH-QA-004 | Fixture `withRole` thêm `ValueKey(role)` để provider/cubit được dựng lại khi đổi role tại `test/helpers/fake_profile.dart:24-33`; `test/features/exam_ui_test.dart` tách case student/lecturer. | Static candidate về sửa harness; test cần chạy lại để xác nhận. Đây không phải bug phân quyền runtime. |

## Retest và acceptance

Ưu tiên P0 trước: REL-02 block/unblock hai phía và quyền truy cập feed/profile/tương tác; dùng hai tài khoản test, xác nhận danh sách block sau relaunch. README đã nêu FE phải ẩn dữ liệu người bị block, kể cả nội dung đã tải, và unblock không tự kết bạn/theo dõi lại (`README.md:76-78`). Tuy nhiên `docs/qa/TEST_CASES.md:220-225` vẫn yêu cầu owner xác nhận semantics API, policy hai chiều và cleanup trước khi kết luận. UI/mock checks có thể khảo sát lọc phía client; quyền server vẫn BLOCKED nếu chưa có contract/API test.

Tiếp theo P1, expected đã rõ trong README/test cases: REACT-01 Like/unlike và rollback khi API lỗi (`README.md:72-73`, `docs/qa/TEST_CASES.md:169-176`); COMM-01 giới hạn 500 từ, không sửa, chỉ chủ comment xoá (`README.md:69,74`, `TEST_CASES.md:178-185`); POST-02 visibility chỉ khi policy cho FRIENDS/ONLY_ME đã được xác nhận (`TEST_CASES.md:149-156`). Chat đã được implement và có [API contract](../../chat/API_CONTRACT.md) cùng [hướng dẫn QA](../chat.md); `CHAT-01` là **NOT RUN**, readiness hiện **BLOCKED** do chưa có API/user test và realtime payload thực để xác minh. Những assertion về ordering/delivery, retry/idempotency, receipts, delete và block semantics còn cần owner xác nhận riêng nên các assertion đó **WAITING**, không phải toàn bộ module chờ triển khai. Không coi preview/shared-demo là API acceptance.

Trạng thái tĩnh khi rà upstream: `QUESTION-01`, `EXAM-01` và `CHAT-01` đã có implementation/docs nên không còn là placeholder; cả ba acceptance đều **NOT RUN**. Readiness chạy Flutter hiện **BLOCKED** do package cache không khớp lockfile; API/UI acceptance **BLOCKED** do thiếu API host/tài khoản/device. Các assertion QUESTION/EXAM chưa rõ schema, vai trò, range và side effects cùng các assertion realtime CHAT chưa được owner xác nhận tiếp tục **WAITING** ở cấp assertion. Không có PASS/FAIL mới. Handoff regression ghi `TESTED_SHA=adde556e2ef6e481fd7145588db878012673b059`, nhưng không có app/API/device acceptance run tại SHA này.

Theo handoff regression cùng ngày, hai lệnh Python offline đạt 3 + 6 checks (exit 0); formatter check-only exit 1 với bốn file cần format. Flutter test/analyze và bốn retest QH-QA-001..004 là **NOT RUN/BLOCKED** bởi package cache mismatch. Không có API, native, build hay thiết bị run. Xem [báo cáo regression](2026-11-15-regression.md); đây là kết quả được coordinator cung cấp, không phải lần chạy trong lượt rà upstream này.

## Lệnh đã chạy

Các lệnh chỉ đọc, không mạng; mỗi lệnh hoàn tất với exit code 0:

- `git status --short --branch`
- `git rev-parse HEAD`
- `git rev-list --count c34bc531404d4fdcd3c788a1afa843bddf13bf58..08a5a2e4097923d21bbdaf7d02cb1792f2171aa3`
- `git diff --shortstat c34bc531404d4fdcd3c788a1afa843bddf13bf58 08a5a2e4097923d21bbdaf7d02cb1792f2171aa3`
- `git rev-list --count 08a5a2e4097923d21bbdaf7d02cb1792f2171aa3..639da12`
- `git log --oneline --reverse 08a5a2e4097923d21bbdaf7d02cb1792f2171aa3..639da12`
- `git diff --unified=2 79fa46cf1235ebc11723695985a5bd78bde1693a 08a5a2e4097923d21bbdaf7d02cb1792f2171aa3 -- <các file QH-QA-001..004>`
- `rg -n 'QH-QA-001|QH-QA-002|QH-QA-003|QH-QA-004|LoadCubit|image.only|PlatformException|test harness' lib test qa docs/qa`

Không chạy Flutter/Dart, API, UI, thiết bị hay cài dependency theo phạm vi được giao. Kết quả ở trên không phải PASS.

## Evidence và giới hạn

Tham chiếu tĩnh: `README.md:18-31, 55-78`; `docs/qa/TEST_CASES.md:149-185, 218-237`; `docs/qa/chat.md:1-56`; `docs/qa/relationships.md:1-32`; các file runtime/test nêu trong bảng. Evidence repro cũ của ba lỗi nằm tại `docs/qa/evidence/2026-10-26/repros/`; đó là evidence của SHA/lượt cũ, không phải retest upstream. Cần kiểm tra GitHub URL đã ghim SHA mới sau khi báo cáo được commit/push bởi coordinator.

Rủi ro lớn nhất còn lại là hợp đồng block và chat phía backend chưa đủ rõ để chấm acceptance, trong khi thay đổi block chạm nhiều cache/màn hình và chat dùng realtime. Cấu hình iOS mới cũng chưa được build trên Mac/Xcode trong lượt rà này.
