# Theo dõi tiến độ QA

## Handoff hiện tại — 2026-11-28 (real API smoke; acceptance matrix giữ nguyên)

- Student API baseline tại source `c34ece09f92f06103257eabfa2c92a92d46d40a3`, host `snsqb.duckdns.org`: `python3 qa/api/real_student_probe.py --phase baseline --output docs/qa/evidence/2026-11-28/real-api/baseline.json`, exit `0`; **53 PASS, 0 FAIL, 0 BLOCKED, 1 WAITING / 54 probes**. Bốn tài khoản student dùng trong lượt. Auth login/identity/refresh/logout/revocation, anonymous 401, lecturer-only 403 và GET read smoke đều đạt. Chỉ route OpenAPI cũ `/sessions/my-enrolled-subjects` còn WAITING (404/1012); route app `/sessions/my-enrolled-course-classes` trả 200/1000, một lớp. Đây là API smoke, không phải toàn bộ acceptance. [Evidence](evidence/2026-11-28/real-api/baseline.json).
- Chat hai tài khoản tại source `30bb1ef8227c8f5fa9f5244c39e4a4f134c79ced`: `node qa/api/real_chat_probe.mjs --output docs/qa/evidence/2026-11-28/real-api/chat-final.json`, exit `0`; **9/9 PASS** gồm hai login/logout, STOMP hai phía, marker delivery, history và thu hồi `EVERYONE` có `revoked=true`. GET history đánh dấu hội thoại đã đọc; direct conversation có thể tồn tại sau lượt test; message bị thu hồi vẫn là tombstone. [Evidence](evidence/2026-11-28/real-api/chat-final.json).
- Social hai tài khoản tại source `1255b538b44f885a0d72c59aaccd5f759f1ebe59`: `python3 qa/api/real_social_probe.py --output docs/qa/evidence/2026-11-28/real-api/social-final.jsonl`, exit `0`; **13 invariant PASS + 22 HTTP_PASS**, không cộng thành unique testcase. Private read bị từ chối đúng quyền; A (Sơn) bị từ chối khi xóa comment của B (Nam), còn B xóa comment của mình; comment delete để lại tombstone theo model (`deleted=true`, `hidden=true`, author null, marker content không còn). Lượt đầu tại `30bb1ef8227c8f5fa9f5244c39e4a4f134c79ced` exit `1` do harness đòi ID comment biến mất; lượt cuối đổi assertion theo tombstone contract. Không xác nhận bug. Còn NOT RUN: native/FCM/media, positive lecturer flows, practice/answer/rating cần fixture RESOLVED, profile/password edits, friendship accept/block mutations và game actions. Cleanup 0 còn lại theo runner; post/comment delete dùng tombstone semantics, không khẳng định hard-delete server-side. [Final evidence](evidence/2026-11-28/real-api/social-final.jsonl), [initial harness evidence](evidence/2026-11-28/real-api/social-initial-harness.jsonl).
- Web app source `0a1fbf8d0f26bcf00b3e40c3ce3647df18359221`: build `flutter build web --no-pub -t lib/main.dart --output qa-artifacts/2026-11-28/real-api-web`, exit `0` (93 giây). Browser mở tới login page, nhưng login bị **BLOCKED** ở CORS preflight do thiếu `Access-Control-Allow-Origin`; auth POST không được gửi. Browser đóng, local server dừng (Ctrl-C, exit 0); không dùng phone hay lecturer account. [Web evidence](evidence/2026-11-28/real-api/web-environment.txt).
- Academic API tại source `7ed7d7d11893838a20b2d2ea577569ba0997747c`: `python3 qa/api/real_academic_probe.py --output docs/qa/evidence/2026-11-28/real-api/academic-final.json`, exit `0`; **15 PASS, 5 WAITING / 20 cases**, 0 FAIL/BLOCKED. QA proposal 3 câu được tạo, đọc, cập nhật và xóa; case role denial đạt. WAITING gồm legacy exam route (404/1012) và bốn ca cần own RESOLVED session. Initial harness source `939445c...` có hai phân loại FAIL do schema/path cũ, không phải bug đã xác nhận. [Final evidence](evidence/2026-11-28/real-api/academic-final.json), [initial evidence](evidence/2026-11-28/real-api/academic-initial-harness.json), [live contract](evidence/2026-11-28/real-api/live-contract.txt).
- Student utilities tại source `dbdb2c5d4483f5e299d6970d489f7354015efafc`: `python3 qa/api/real_student_utilities_probe.py --output docs/qa/evidence/2026-11-28/real-api/utilities-final.json`, exit `0`; **31/31 PASS**. Privacy profile, cursor pagination no-overlap, saved search lifecycle, push settings restore, follow create/restore đều đạt. Lượt harness đầu WAITING vì đọc `is_following` từ relationship-stats response; final đọc `following` theo contract hiện tại. [Final evidence](evidence/2026-11-28/real-api/utilities-final.json), [initial context](evidence/2026-11-28/real-api/utilities-initial-harness.json).
- Acceptance matrix của 25 case vẫn **24 NOT RUN, 1 WAITING, 0 PASS, 0 FAIL**. Smoke results không cộng vào matrix. Upstream `main` snapshot giữ nguyên `82ef14f38e086d6b558b392fc54a328c3d7f26a2`. Utilities rerun hoàn tất: 31/31 PASS tại source integration HEAD.
- Môi trường hiện tại: Linux WSL2 x86_64, Python 3.12.3, Node 24.14.1. Integration HEAD `dbdb2c5d4483f5e299d6970d489f7354015efafc`; runtime/dependency diff với upstream `82ef14f38e086d6b558b392fc54a328c3d7f26a2` rỗng (`git diff --exit-code origin/main HEAD -- lib android ios pubspec.yaml pubspec.lock`, exit 0).

## Handoff cũ — 2026-11-25 (native PREVIEW)

Snapshot đã dừng theo yêu cầu quota; cleanup hoàn tất, còn việc.

- Source archive `d89a8d660d93842475b694100ccef1fdf783ed9e`, upstream snapshot `82ef14f38e086d6b558b392fc54a328c3d7f26a2`; checkpoint tài liệu đã push `7edf960`. Runtime source và dependency/lock không đổi. PREVIEW APK dùng package cô lập `vn.edu.hust.quizhub.qa.retest`; thiết bị RMX3370, Android 13/API 33, MCP báo emulator, màn hình 1080×2400, density 480/360 dp, font scale 1.0 (device ID/serial che).
- Lecturer academic gộp lượt 24–25 là 19 kiểm tra unique: **18 PASS, 1 WAITING (PW-03)**. Lựa chọn quyền OS còn NOT RUN và nằm ngoài 19 kiểm tra. Core UI 24/11 có 40 kiểm tra preview riêng: **27 PASS, 1 WAITING, 6 NOT RUN, 6 BLOCKED** ([báo cáo core](reports/2026-11-24-native-core.md)); không cộng kết quả PREVIEW vào acceptance. Student APK SHA-256 `7e73007a0f1a0a641a0f60c7ee75375cb671bede178c151f9b57a7292347a718` đã được cài với hash khớp. Student academic: **23 PASS, 1 FAIL, 5 NOT RUN / 29 kiểm tra**; rating/statistics đã hoàn tất ([báo cáo Student academic](reports/2026-11-25-native-student-academic.md)). Student utilities: **11 PASS, 1 WAITING, 2 NOT RUN / 14 kiểm tra** ([báo cáo utilities](reports/2026-11-25-native-student-utilities.md)).
- Overflow khoảng 15 px ở hàng thẻ Game 2 trên hub đã được ghi thành QH-QA-016 (Open/Minor/Low; nguyên nhân chưa xác nhận). [Ảnh lỗi ghim](evidence/2026-11-25/native-student-academic/S-GAME-00-hub.png); tracker có **16 issue: 7 Open, 1 Ready for Retest, 8 Closed**, xem [cập nhật tracker](reports/2026-11-25-tracker-update.md).
- Fixture QA đã được đẩy và liệt kê đủ 8 file; lượt core xác nhận DocumentsUI hiển thị đủ 8 file sau media scan ([evidence setup](evidence/2026-11-25/device-fixtures.txt)). Core preview dừng theo quota: **12 PASS, 2 NOT RUN, 1 BLOCKED / 15** ([báo cáo core](reports/2026-11-25-native-student-core.md)). Còn chạy được các case `S-G1-02`, `S-G2-04`, `S-G2-05`, `S-G4-03`, `S-NOT-04`, `SCG-10`, `SCG-15`; `S-EXAM-01` và quyền OS còn NOT RUN theo giới hạn prompt UI. QA app đã gỡ, fixture folder đã xóa, ADB process dừng; chi tiết và giới hạn tại [cleanup evidence](evidence/2026-11-25/device-cleanup.txt). Xem [resume checkpoint](reports/2026-11-25-resume.md); không dùng trạng thái đang chờ như PASS.
- Acceptance baseline vẫn **24 NOT RUN, 1 WAITING, 0 PASS, 0 FAIL**. API/backend và FCM **BLOCKED** do chưa có host/tài khoản QA. Đây là native PREVIEW, không phải acceptance hoặc kiểm tra dịch vụ thật.

## Checkpoint lịch sử — 2026-11-23

### Source và acceptance

| Mốc | SHA / trạng thái |
|---|---|
| `QA_BEFORE` | `b25419365a8ecb78a00ccfd629f0807a1eea98a7` |
| `MAIN_SNAPSHOT` | `82ef14f38e086d6b558b392fc54a328c3d7f26a2` |
| QA merge / `TESTED_SHA` full regression | `622640325b7c1b4bf0f3a5018ffd2635dce27061` |
| Checkpoint sau khi sửa hai fixture compile | `2f040844ee939317ac06da6a9d7473670f4213cd` |
| Focused retest checkpoint | `04d858c5348626198b1879a7900e2d75c9390e58` |
| Runtime/config delta theo coordinator | `lib/`, `android/`, `ios/`, `pubspec.yaml`, `pubspec.lock` trùng `MAIN_SNAPSHOT`; không có app/dependency edit riêng trên QA. |
| Acceptance matrix | **24 NOT RUN, 1 WAITING, 0 PASS, 0 FAIL**. SEARCH/PUSH đã có implementation trong snapshot mới nên chuyển từ WAITING sang NOT RUN; minigame có một phần, AI/contract còn WAITING. Local regression không được cộng vào acceptance. |
| Canonical bug tracker | **15 unique issues: 8 Closed, 1 Ready for Retest, 6 Open**; cells đã được coordinator readback xác nhận, dashboard 15/6/1/8 khớp. [Tracker update report](reports/2026-11-23-tracker-update.md). |
| API/native acceptance | **NOT RUN** — không có API host/tài khoản hoặc thiết bị trong các lượt này. |

### Regression và local repro

- Full default suite trên `6226403`, Flutter 3.41.6/Dart 3.11.4: exit 1, 390 passed; hai file test compile lỗi. Sau khi sửa fixture, full suite tại `2f04084`: exit 1, 395 passed / 6 failed. Đây là full-suite result duy nhất ở checkpoint đó; không gộp với focused retest mới hơn. Xem [regression report](reports/2026-11-23-regression.md) và [evidence excerpt](evidence/2026-11-23/regression/results.txt).
- Tại `04d858c`, focused issue suite: **47 PASS**, exit 0; bao phủ QH-QA-001..004 và QH-QA-006..008 bằng unit/widget tests với mocks/fakes. QH-QA-005 chưa retest bằng Flutter 3.47.9; runner lock-compatible Flutter 3.41.6 không đóng được issue đó. Kết quả từng issue: [retest report](reports/2026-11-23-retest.md).
- Cùng `04d858c`, `test/qa/ui_layout_regression_test.dart`: **2 PASS / 5 FAIL**, exit 1. Hai failed test cases chứa ba overflow component sites tương ứng QH-QA-010..012: conversation row 161 px ngang, shared EmptyView 341 px dọc, PostCard actions (71/67/179/123 px ngang trên bốn diagnostic). Ba failed test cases còn lại là hit-test/viewport limits của harness (reply control, like control, exam action off-screen). Widget run 320×640/text scale 2, không xác nhận trên thiết bị. Không dùng exploratory layout log 4/3; source test của nó đã bị chỉnh trong lúc điều tra và log đó không được tính.
- Cùng `04d858c`, scoped analyzer `flutter analyze --no-pub lib test qa/repro`: exit 0, `No issues found`.
- Network fake repro: 2 invariant FAIL, exit 1. Redirect gửi dummy bearer/body sang off-origin host; hai concurrent 401 callers phân loại timeout thành `noConnection` và `unauthorized`. Đây là adapter in-memory, không phải server/API repro; đề xuất QH-QA-014/015.
- Flutter/Dart formatter check tại checkpoint `2f04084`: exit 1, 12 file trong `lib/`/`test/` được formatter báo cần đổi; lệnh check-only, không sửa file. Full analyzer baseline có 129 diagnostics; 127 nằm trong bản sao/repro cũ dưới `qa-artifacts/`, 2 là compile fixture ở SHA baseline.
- Python checks tại `6226403`: API collection 3 test PASS (exit 0), fixture unittest 6 PASS (exit 0); checkpoint sau đó chỉ thay Dart tests nên các kết quả vẫn áp dụng.

### Web preview

Trên `2f04084`, cached Flutter web build exit 0 (57.6 giây). Browser boot của `lib/main_preview.dart` **FAIL**: header/shell hiện nhưng body xám trống; Firebase init trên web lỗi rồi lazy messaging service ném `[core/no-app]`. Đây là local preview candidate QH-QA-013, không phải lỗi API/native. Search, push settings, report và minigame flows **NOT RUN** do boot bị chặn. Xem [web report](reports/2026-11-23-web.md), [console excerpt](evidence/2026-11-23/web/console.txt) và [ảnh](evidence/2026-11-23/web/preview-blank-body.png).

Tracker update/readback ngày 23/11: QH-QA-010..012 và QH-QA-014..015 hiện **Open / Retest Fail** với evidence local; QH-QA-013 **Open / Not Retested** sau lần web preview đầu; QH-QA-005 **Ready for Retest / Retest Blocked**; QH-QA-001..004 và QH-QA-006..009 **Closed**. Chi tiết, status history và URL ghim: [tracker update report](reports/2026-11-23-tracker-update.md). Delta minigame/question bank/report/push: [delta review](reports/2026-11-23-delta-review.md). Môi trường và lệnh: [ENVIRONMENT](ENVIRONMENT.md).

## Execution 2026-11-20 — Nam (native preview)

Trên APK preview đã có sẵn từ Nam pristine source `639da129d89e8290c13b63af3d36045309b38fd6`, coordinator quan sát Search (filter/history/empty/paging fixture), Notifications (19 unread ban đầu trong fixture 33 mục, đọc đơn/đọc tất cả/paging/điều hướng) và Push settings (draft/cancel/save/reopen cùng process). Dùng preview backend; Firebase SDK được khởi tạo, nhưng API thật và FCM delivery không xác minh. Nhánh deny Android notification permission **INCONCLUSIVE**: cuối cùng quyền vẫn granted. `QUESTION_APPROVED` thiếu state rõ và badge còn placeholder (**WAITING**). Acceptance `SEARCH-01`/`PUSH-01` không đổi. Local retest cùng ngày: 95 feature/data/core PASS (exit 0); focused repro/UI tái hiện 6 lỗi, 3 ca harness PASS (exit 1); QH-QA-006..008 giữ Open / Retest Fail trên SHA này. Thiết bị RMX3370 Android 13/API 33, MCP báo emulator, 1080×2400/font 1.0. APK SHA-256 `c09122a2c64d4e76650176c330b4494d090f822bd0357dc2b76b512fe7718603`; Mobile MCP install/launch không có numeric exit. Cleanup: QA package uninstall thành công, Windows `pm path` exit 1/stdout rỗng; display/font read exit 0; ADB dừng trên Windows/Linux, process checks không thấy adb. Chi tiết và 18 ảnh context đã chọn: [native report](reports/2026-11-20-nam-native.md), [local report](reports/2026-11-20-nam-local.md).

## Execution 2026-11-20 — Quốc Anh (native preview)

Trên APK QA Flutter 3.47.9 / Dart 3.13.7 (source base `447ecf394894627e498df08464466f16a12e3ef6` cộng một import Cupertino đã được Sơn cho phép; APK SHA-256 `755b5deaf26c70f781a0055167fba5e4a29d544a8697a829772c26981654a120`), coordinator quan sát các luồng preview post/edit/detail/persistence, reaction root/reply độc lập, follow/unfollow/block/unblock, chat revoke/delete và baseline filter keyboard. Kết quả chỉ áp dụng cho fixture preview một tài khoản; không tính là acceptance API. Thiết bị RMX3370 Android 13/API 33, Mobile MCP báo emulator, 1080×2400, font 1.0. Cài/mở bằng MCP không có numeric exit code; ADB hash APK đã cài exit 0 và khớp artifact.

Thử cấu hình 320×640 dp/font 2.0 bị ColorOS chặn quyền ghi setting; native QH-QA-012 và kiểm tra hẹp chính xác **BLOCKED / NOT RUN**. Process logcat là lát cắt hạn chế, không xác nhận toàn phiên không crash. Cleanup được coordinator xác nhận: MCP uninstall thành công, ADB `pm path` exit 1/stdout rỗng, đọc lại display/font exit 0. Tại thời điểm ghi nhận, ADB còn hoạt động để tiếp tục phiên Nam; phiên Nam 20/11 sau đó dừng ADB như ghi ở execution phía trên. API host/A+B không có; API/backend **BLOCKED**, contract chưa rõ **WAITING**. Acceptance matrix giữ **22 NOT RUN, 3 WAITING, 0 PASS, 0 FAIL**. Chi tiết, giới hạn và 19 ảnh ngữ cảnh đã chọn: [native report](reports/2026-11-20-quoc-anh-native.md). APK được giữ trong isolated workspace; root runtime/dependencies không đổi.

Widget preview ngày 20/11: **25 PASS**; layout sweep **2 PASS / 5 FAIL** chỉ là candidate quan sát, chưa xác minh thành bug và không đổi acceptance `main`. Chi tiết tại [Quốc Anh widget report](reports/2026-11-20-quoc-anh-widget.md).

## Execution 2026-11-19 — Quốc Anh (cập nhật)

**Handoff sau crash:** theo yêu cầu Sơn, đã dừng kiểm thử và gỡ QA APK khỏi điện thoại. APK đúng và bước tiếp theo được lưu tại [resume handoff](reports/2026-11-19-quoc-anh-resume.md). Không tiếp tục kiểm thử trong phiên này.

Root source `447ecf394894627e498df08464466f16a12e3ef6`, upstream `main` `08a5a2e4097923d21bbdaf7d02cb1792f2171aa3`; không có runtime/dependency changes trên root. Local suites core/data/chat recovery đạt **106 PASS** với Flutter 3.47.9 / Dart 3.13.7, nhưng chỉ dùng fake/preview/loopback, không phải acceptance API. Transcript excerpt, commands và giới hạn raw log ở [local expanded report](reports/2026-11-19-quoc-anh-local-expanded.md) và [evidence](evidence/2026-11-19/quoc-anh-local/results.txt).

QH-QA-005 trên root source vẫn **OPEN / Retest Fail** theo tracker đọc lại 19/11: `CupertinoPageTransitionsBuilder` unresolved; compile-only, widget bodies chưa chạy, không có upstream fix. Sơn cho phép một import Cupertino trong QA workspace cô lập và Gradle artifact downloads, không cài SDK. APK QA Flutter 3.47.9 từ BASE `447ecf3` cộng patch được phép build thành công; lock giữ nguyên, metadata và plugin registrant sinh thành công. Install exit 0, cold launch exit 0, QA foreground và Home được quan sát; sau crash theo yêu cầu mới nhất app QA đã gỡ. APK còn trong isolated workspace. Hash, lệnh build và trạng thái UI dở dang tại [summary](reports/2026-11-19-quoc-anh-summary.md), [native build](reports/2026-11-19-quoc-anh-native-build.md) và [native UI](reports/2026-11-19-quoc-anh-native-ui.md). Đây là build QA có patch, không phải acceptance bản main nguyên trạng.

Các kết quả đầu tiên trên SDK 3.41.6 (manual remapped UI 25 PASS; layout 2 PASS/5 FAIL) là **PROVISIONAL**, không phải baseline chuẩn. `offline-enforce-lock` exit 65 sẽ hạ 5 dependencies; lock SHA phải giữ nguyên. Không dùng SDK 3.41 để kết luận cuối.

Một APK thử trước đó (SHA `588…`) mở màn đen/logo do thiếu `GeneratedPluginRegistrant`/SharedPreferences; QA tooling mistake, không phải product bug. APK gỡ thành công (exit 0; `pm path` absence exit 1); giữ PNG evidence.

Flutter 3.47.9 targeted UI rerun bị **INTERRUPTED / INCOMPLETE** (partial log tới `+11`, không final summary/exit code). Native Home/startup đã quan sát; normal flow chưa hoàn tất trước crash. Android RMX3370 / Android 13 / API 33, 1080×2400, density 480, font 1.0; QA app đã gỡ. API host/A+B không có: backend cases **BLOCKED**, contract chưa chốt **WAITING**. Acceptance matrix không đổi. Tiếp tục từ APK và kịch bản trong resume handoff khi người dùng yêu cầu.

## Execution 2026-11-19 — Quốc Anh

Tại checkpoint `2cf8ef3cfaa93928607b338d794ea3c46f7eb8b0` / `TESTED_SHA` cùng giá trị, `MAIN_SNAPSHOT=08a5a2e4097923d21bbdaf7d02cb1792f2171aa3`. Flutter 3.47.9 compile gate **BLOCKED** do `CupertinoPageTransitionsBuilder` unresolved ở `app_theme.dart:196–197`; test body chưa chạy. Chat preview probe độc lập **2 PASS** với mock/local demo server sau khi cho phép bind loopback; không phải API acceptance. API+A/B **BLOCKED**, contract assertions chưa rõ **WAITING**. Chi tiết/lệnh/log: [execution report](reports/2026-11-19-quoc-anh-execution.md). Lần thử 3.41.6 cache-hook mismatch được lưu riêng, không dùng làm app compile result.

Snapshot handoff 2026-11-15 (Asia/Bangkok). Số matrix là acceptance của app, không gộp
với regression tự động hoặc reproduction harness. Chi tiết: [TEST_CASES.md](TEST_CASES.md),
[TEST_PLAN.md](TEST_PLAN.md), [QA.md](../../QA.md).

## Handoff hiện tại — 2026-11-15

| Mốc | SHA / kết quả |
|---|---|
| QA test-source snapshot | `999a1678206a6b0d5589cf2c97a0f677ef8bb017` (3 QA probe tests only) |
| Upstream `main` đã tích hợp | `08a5a2e4097923d21bbdaf7d02cb1792f2171aa3` |
| `TESTED_SHA` | `999a1678206a6b0d5589cf2c97a0f677ef8bb017` cho compile-only check; không có test case thực thi |
| Acceptance matrix | **22 NOT RUN, 3 WAITING, 0 PASS, 0 FAIL**. QUESTION-01, EXAM-01 và CHAT-01 đã có implementation/docs, nên là NOT RUN; API/UI chưa chạy. SEARCH-01, PUSH-01, ADV-01 chưa có trong snapshot main nên WAITING. Một số assertion QUESTION/EXAM/CHAT còn cần owner chốt contract riêng. |
| Compile baseline | `flutter test --no-pub test/features/exam_ui_test.dart`: exit 1 before tests ran; `CupertinoPageTransitionsBuilder` unresolved at `app_theme.dart:196-197` on Flutter 3.47.9 / Dart 3.13.7. [Evidence](evidence/2026-11-15/regression/theme-baseline.txt); no app source delta from upstream main. |
| Offline Python / formatter | Results in [regression report](reports/2026-11-15-regression.md) belong to their recorded earlier source/run context; not relabeled as a current `999a167` run. Initial cache mismatch is historical; main deps are now restored by coordinator with SDK 3.47.9 and Nam snapshot with 3.41.6, lockfiles unchanged. |
| Flutter full suite / analyze / QH-QA-001..004 retest | **NOT RUN** on current source; compile blocker prevents test execution. Three client defects reproduced separately on pristine Nam source SHA `639da129d89e8290c13b63af3d36045309b38fd6`, mock/fake only. Corrected notification UI host passed 3/3 in independent rerun; reviewer also verified 244 runtime/config files match pristine source. QH-QA-009 is Closed / Retest Pass as Other/harness, owner Sơn. See [Nam evidence](evidence/2026-11-15/nam/README.md). |
| API / native / build | API **NOT RUN**. Nam preview APK build exit 0 (772.3 s; SHA-256 `c09122a2c64d4e76650176c330b4494d090f822bd0357dc2b76b512fe7718603`); install via ADB fallback succeeded. Native UI **BLOCKED / NOT RUN**: another app's overlay retained focus; relaunch + one Back action did not return focus to QA app (confirmed by targeted `dumpsys`). No UI PASS or product bug. QA package uninstall succeeded; MCP uninstall and `pm path` absence were confirmed. Details: [native UI report](reports/2026-11-15-native-ui.md). Main build **NOT RUN**. |
| Tracker | **Updated and CSV-readback verified**: 9 unique issues total; `QH-QA-001..008` Open, `QH-QA-009` Closed / Retest Pass (Other/harness, owner Sơn); no duplicates. Details and pinned URLs: [tracker update report](reports/2026-11-15-tracker-update.md). |
| QA report commit | Docs/evidence update `f3661a2db84c3e4fb544b1307f599b96c360e1e6` pushed to `origin/qa/khanhson2005`; corrected host evidence URL pinned to tracker and HTTP 200-verified. |

Handoff này không mang kết quả cũ sang SHA mới. Flutter 98 PASS, preview 12/5 PASS,
144-pass/1-fail và experimental widget results bên dưới đều thuộc SHA/runner ghi cạnh
từng lượt; không phải kết quả hiện tại. Xem [summary hiện tại](reports/2026-11-15-summary.md).

## Kết quả lịch sử (không phải snapshot hiện tại)

| Phạm vi | Kết quả |
|---|---|
| Acceptance API/UI/E2E matrix (snapshot 2026-10-22) | **19 NOT RUN, 6 WAITING, 0 PASS, 0 FAIL**. Ma trận chưa chạy; các preview smoke checks ngày 2026-10-26 ghi riêng bên dưới và không tính vào ma trận. Trạng thái handoff 2026-11-15 ở đầu file. |
| Regression Flutter mặc định | **98 PASS**, exit 0 tại source `f1951b0c03c5b21929414485101108c804c3ebd0`; log [flutter-default-tests-f1951b0.log](../../qa-artifacts/2026-10-22/flutter-default-tests-f1951b0.log). Không rerun tại `520c738` vì các thay đổi sau đó chỉ là analyzer suppressions trong risk harness; default tests/runtime không đổi. |
| Network risk reproductions | **2 FAIL** tại source `520c7381f0159ce40f9534ace1c657b87aa523d1`, exit 1; repro client fake-transport, không phải lỗi đã tái hiện với API thật. Log [repro-520c738.log](../../qa-artifacts/2026-10-22/repro-520c738.log). |
| Dart formatter | Full check `lib test qa/repro` tại `f1951b0` exit 1 vì 2 file upstream cần format; check-only, không sửa file ([log](../../qa-artifacts/2026-10-22/dart-format-check-f1951b0.log)). QA-only `qa/repro` tại `520c738` exit 0, 1 file/0 changes ([log](../../qa-artifacts/2026-10-22/format-check-520c738.log)). |
| `flutter analyze` | `f1951b0`: exit 1 do 2 `invalid_use_of_visible_for_testing_member` warning trong QA harness; sau suppression có comment lý do, `520c738`: exit 0, “No issues found”, log [analyze-520c738.log](../../qa-artifacts/2026-10-22/analyze-520c738.log). |
| `TESTED_SHA` acceptance app (snapshot 2026-10-22) | **NONE** — không có app/backend/device acceptance run tại snapshot đó. |
| Preview web UI, 2026-10-26 | **12 PASS** trên mock in-memory tại source `b949513b254bee55a3887e619786ea91f85b477f`; không phải API hoặc acceptance-matrix result. Xem [báo cáo web UI](reports/2026-10-26-web-ui.md). |
| Preview native UI, 2026-10-26 | **5 PASS, 2 BLOCKED/INCONCLUSIVE** tại cùng source SHA; GT Neo2 / Android 13 / API 33, mock backend. QA APK đã gỡ sau test. Xem [báo cáo native UI](reports/2026-10-26-mobile-ui-setup.md) và [evidence](evidence/2026-10-26/android-ui/). |
| Flutter run, 2026-10-26 | `flutter test --no-pub --reporter expanded`: 144 passed, 1 failed, exit 1; `flutter analyze --no-pub`: 0 issues, exit 0 tại source `b949513b254bee55a3887e619786ea91f85b477f`. Lỗi suite thuộc fixture role; chưa xác nhận lỗi runtime. Xem [báo cáo review](reports/2026-10-26-dung-review.md). |
| OpenAPI / collection static review | **Hoàn tất tĩnh**: 41 request, 33 operation duy nhất (method/path) trên 128 paths; OpenAPI SHA-256 `63dc2323…939cc5`. `python3 qa/api/test_collection.py`: 3 PASS, exit 0 tại source `74c8ea16b05733a2e5620dc48f3c52cc6867c3b6`; log `qa-artifacts/2026-10-22/api-contract-74c8ea1.log`. Sơn chưa có API host/account; chưa import Postman hoặc gửi request nghiệp vụ. |

Hai FAIL reproduction là test opt-in ngoài `test/`, kiểm tra riêng invariant redirect và concurrent refresh. Chúng không làm matrix API/UI FAIL; 98 default PASS cũng không làm các invariant đạt. Xem [RISKS.md](RISKS.md) và [hướng dẫn reproduction](../../qa/repro/README.md).

Repro đã chạy lại trên `520c738`; code mạng/runtime không đổi từ `f1951b0`. Mọi log dưới
`qa-artifacts/` là local ignored artifact. Flutter 3.41.6/Dart 3.11.4 và cache nằm trong
`.qa-tools/`; lượt kiểm tra không dùng API host hoặc thiết bị.

## Baseline và môi trường

| Mốc | Giá trị |
|---|---|
| Nhánh | `qa/khanhson2005` |
| Runtime snapshot tại lần rà 2026-10-22 | `6ee7f6d9a9a9d2342803c41a32f8dd03ac7a0d48`; runtime/dependency/platform files khớp upstream main ở lần rà đó. |
| QA verification sources | Default tests at `f1951b0c03c5b21929414485101108c804c3ebd0`; analyzer/QA-only formatter/repro at `520c7381f0159ce40f9534ace1c657b87aa523d1`. Các analyzer annotations chỉ sửa QA harness; runtime không đổi. |
| QA source/tool snapshot trước đó | `f5e225a5d4aa5d8e8e366770eb2bb4b0212621a6`; dùng cho kết quả fixtures và analyze ban đầu, không phải HEAD hiện tại của tracker |
| Điểm đồng bộ upstream | `QA_BEFORE=0d38d2c494299cfa43ca4358688f0e472d26276b`; `MAIN_SNAPSHOT=6ee7f6d9a9a9d2342803c41a32f8dd03ac7a0d48`; `BASE_BEFORE=0cfa3fba4cb1a8858e448b81b62954ebec9c277e`; merge commit `74c8ea16b05733a2e5620dc48f3c52cc6867c3b6`. No-conflict; runtime/dependency/platform diff against main exit 0. |
| Flutter / Dart | Flutter 3.41.6 / Dart 3.11.4 đã xác minh trong `.qa-tools/flutter`; cache `.qa-tools/pub-cache`. Archive SHA-256 `503b3e6b7d352fca5d21b6474eca95ad544d8fc3b053782eab63a360c7fc7569`; `pub get --enforce-lockfile` exit 0, lock SHA không đổi. Log `qa-artifacts/2026-10-22/sdk-setup.log`. |
| Android build/device tools | JDK, Android SDK/ADB và điện thoại đã được xác minh cho lượt QA preview riêng; không có API host/account. Đây không phải API E2E. |
| Backend và Postman | User chưa cung cấp API host/account test; collection chưa import, chưa gửi request nghiệp vụ. OpenAPI static review đã hoàn tất, không chứng minh API thật. |
| Trạng thái tại lần rà 2026-10-26 | Kết quả Flutter/web/native preview ở các dòng trên; không có API host/account. Acceptance matrix lúc đó là 19 NOT RUN / 6 WAITING. |

## QA deliverables và giới hạn

| Deliverable | Trạng thái |
|---|---|
| Acceptance case pack lúc tạo | 19 ID matrix NOT RUN có steps/assertions/expected source/data/cleanup/evidence; 6 ID WAITING có entry criteria và câu hỏi contract. Handoff 2026-11-15 đổi QUESTION/EXAM/CHAT sang NOT RUN sau khi xác nhận module đã có. |
| Postman API collection | 41 request thủ công, environment mẫu `https://example.invalid/api/v1`, không có secrets. Chưa import/chạy; không chứng minh API contract. |
| Fixtures | Generator sinh 20 file vào ignored `qa-artifacts/fixtures/`; `python3 qa/fixtures/generate_fixtures.py` exit 0. 6 self-check `python3 -m unittest discover -s qa/fixtures -p 'test_*.py' -v` exit 0. Tool-only, không xác minh app/backend. |
| Collection linter / contract review | 41 request khớp 33 operation method/path duy nhất trên 128 OpenAPI paths; `python3 qa/api/test_collection.py`: 3 unittest PASS, exit 0 tại source `74c8ea16b05733a2e5620dc48f3c52cc6867c3b6`; log `qa-artifacts/2026-10-22/api-contract-74c8ea1.log`. Không import Postman hoặc gửi API. |
| Risk review | RSK-01 redirect và RSK-02 concurrent refresh tái hiện hành vi client với transport giả. RSK-03 cache sau lỗi secure storage vẫn là static candidate cần device/contract evidence. Chưa xác nhận trigger trên backend, proxy hay thiết bị thật. |
| Unit/component tests (lịch sử) | Regression mặc định 98 test PASS tại `f1951b0`. Kết quả không thay API/UI/E2E acceptance; test unit/component thuộc hỗ trợ dev. |

Không diễn giải trạng thái matrix của từng snapshot thành phần trăm hoàn tất. `NOT RUN`/`WAITING` là
trạng thái acceptance; PASS/FAIL của lệnh tự động và repro luôn ghi ở bảng/log riêng.

## Handoff

Handoff hiện tại:

- [ ] Cùng owner xem RSK-01/02 và quyết định fix runtime ở nhánh dev hay theo dõi; QA không tự sửa code production.
- [ ] Owner dev xử lý formatter drift của `lib/core/utils/validators.dart` và `test/core/school_email_test.dart` (cả hai từ upstream `main`); kiểm tra lại full formatter khi có snapshot main mới, giữ runtime QA khớp main.
- [ ] Xác nhận API host/account test, tài khoản A/B, fixture disposable và quyền ghi. Android/ADB/device đã được xác minh cho preview QA; API acceptance vẫn chờ host/account.
- [x] OpenAPI static review và collection checks đã hoàn tất tại SHA `74c8ea16b05733a2e5620dc48f3c52cc6867c3b6`; xem `qa-artifacts/2026-10-22/api-contract-74c8ea1.log`. Không thay thế API test thật.
- [ ] Thực hiện acceptance P0 trước trên build được bàn giao; ghi từng case và evidence. Handoff 2026-11-15 có 22 NOT RUN; chỉ đổi trạng thái sau khi case chạy thật.

`TESTED_SHA` cho từng lần chạy là commit source chính xác đã test, không phải SHA của
file tracker hay nhánh “đã chuẩn bị”. Khi source đổi, đánh giá lại regression bị ảnh
hưởng; không bê PASS từ SHA cũ.

## Nhật ký append-only

Giữ các dòng lịch sử, kể cả khi thông tin remote/tool được xác minh sau đó. Những dòng
Flutter tự động phân biệt regression mặc định với reproduction opt-in; không cộng chung.

| Ngày / giờ | SOURCE_SHA | MAIN snapshot | TESTED_SHA | Lệnh / scope | Kết quả và bằng chứng |
|---|---|---|---|---|---|
| 2026-10-21 | `f5e225a5d4aa5d8e8e366770eb2bb4b0212621a6` | `0cfa3fba4cb1a8858e448b81b62954ebec9c277e` (fetch exit 0; không có commit mới) | — | `python3 qa/fixtures/generate_fixtures.py` | Exit 0; sinh 20 fixture trong ignored `qa-artifacts/fixtures/`; tool-only |
| 2026-10-21 | `f5e225a5d4aa5d8e8e366770eb2bb4b0212621a6` | cùng snapshot | — | `python3 -m unittest discover -s qa/fixtures -p 'test_*.py' -v` | 6 unittest PASS, exit 0; chỉ fixture generator/self-check |
| 2026-10-21 | QA tooling snapshot `f5e225a5d4aa5d8e8e366770eb2bb4b0212621a6` | cùng snapshot | — | `python3 qa/api/test_collection.py` | 3 unittest PASS, exit 0; working-tree collection linter, không gửi API |
| 2026-10-21 | `d58cdf01a4b2e04a41901e8804fe1d49847faccf` | `0cfa3fba4cb1a8858e448b81b62954ebec9c277e` | `d58cdf01a4b2e04a41901e8804fe1d49847faccf` | Flutter mặc định `flutter test --no-pub` | 95 PASS, exit 0; `qa-artifacts/flutter-regression-d58cdf0-local-runner.log` |
| 2026-10-21 | `d58cdf01a4b2e04a41901e8804fe1d49847faccf` | cùng snapshot | `d58cdf01a4b2e04a41901e8804fe1d49847faccf` | Flutter opt-in `flutter test --no-pub qa/repro/network_risks_test.dart --reporter expanded` | 2 FAIL invariant, exit 1; `qa-artifacts/network-risks-repro.log`; in-memory fake transport, không gọi API thật |
| 2026-10-21 | `d58cdf01a4b2e04a41901e8804fe1d49847faccf` | cùng snapshot | — | `dart format --output=none --set-exit-if-changed lib test` | 112 files, 0 changed, exit 0; `qa-artifacts/dart-format-d58cdf0.log` |
| 2026-10-21 | `f5e225a5d4aa5d8e8e366770eb2bb4b0212621a6` | cùng snapshot | — | `flutter analyze` | Output “No issues found”; exit code không được ghi, không rerun sau khi thêm repro |
| 2026-10-21 (lịch sử) | QA snapshot `ddbcda516cb825eb37d64ce8bf06144a137f31b2` | `0cfa3fba4cb1a8858e448b81b62954ebec9c277e` (remote chưa fetch khi đó) | — | `bash -n scripts/setup.sh` | Exit 0 cho cú pháp shell; không phải test ứng dụng |
| 2026-10-21 23:32 +07 | Runtime không đổi | cùng snapshot | — | GET tài liệu Swagger/OpenAPI công khai | HTTP 200, TLS được kiểm tra; OpenAPI 3.1.0, 128 paths. Chỉ đọc tài liệu; đối chiếu contract chưa xong tại thời điểm đó. Metadata: `qa-artifacts/swagger/metadata.json`. |
| 2026-10-22 | QA `74c8ea16b05733a2e5620dc48f3c52cc6867c3b6` | `6ee7f6d9a9a9d2342803c41a32f8dd03ac7a0d48`; baseline `0cfa3fba4cb1a8858e448b81b62954ebec9c277e` | — | Merge main vào QA | QA trước merge `0d38d2c494299cfa43ca4358688f0e472d26276b`; merge không conflict, staged diff check exit 0, runtime/dependency/platform diff với main exit 0. Không push. |
| 2026-10-22 | `74c8ea16b05733a2e5620dc48f3c52cc6867c3b6` | `6ee7f6d9a9a9d2342803c41a32f8dd03ac7a0d48` | `74c8ea16b05733a2e5620dc48f3c52cc6867c3b6` | `python3 qa/api/test_collection.py` + static OpenAPI/collection review | 3 Python tests PASS, exit 0; 41 requests / 33 operations / 128 paths; OpenAPI hash `63dc2323…939cc5`; `qa-artifacts/2026-10-22/api-contract-74c8ea1.log`. Không import Postman/gọi API thật. |
| 2026-10-22 | `f1951b0c03c5b21929414485101108c804c3ebd0` | `6ee7f6d9a9a9d2342803c41a32f8dd03ac7a0d48` | `f1951b0c03c5b21929414485101108c804c3ebd0` | `flutter test --no-pub --reporter expanded` | 98 PASS, exit 0; Flutter 3.41.6/Dart 3.11.4; API host/device NONE; log `qa-artifacts/2026-10-22/flutter-default-tests-f1951b0.log`. |
| 2026-10-22 | `f1951b0c03c5b21929414485101108c804c3ebd0` | cùng snapshot | `f1951b0c03c5b21929414485101108c804c3ebd0` | `flutter analyze --no-pub`; `dart format --output=none --set-exit-if-changed lib test qa/repro`; `flutter test --no-pub qa/repro/network_risks_test.dart --reporter expanded` | Analyze exit 1 (2 QA harness warnings); full formatter exit 1 (2 upstream files would change, check-only); repro 2 invariant FAIL, exit 1. Logs `flutter-analyze-f1951b0.log`, `dart-format-check-f1951b0.log`, `network-risk-repros-f1951b0.log`. |
| 2026-10-22 | `520c7381f0159ce40f9534ace1c657b87aa523d1` | cùng snapshot | `520c7381f0159ce40f9534ace1c657b87aa523d1` | `flutter analyze --no-pub`; QA-only `dart format --output=none --set-exit-if-changed qa/repro`; network repro | Analyze exit 0, “No issues found”; formatter 1 file/0 changes exit 0; repro 2 invariant FAIL exit 1. Default suite không chạy lại; chỉ thay annotation trong QA harness. Logs `analyze-520c738.log`, `format-check-520c738.log`, `repro-520c738.log`. |
| 2026-10-26 | `b949513b254bee55a3887e619786ea91f85b477f` | source snapshot `b949513b254bee55a3887e619786ea91f85b477f` | `b949513b254bee55a3887e619786ea91f85b477f` | `flutter test --no-pub --reporter expanded`; `flutter analyze --no-pub` | Full suite 144 passed/1 failed, exit 1; analyze 0 issues, exit 0. Failure is UI test role fixture; runtime defect not confirmed. Logs [test](../../qa-artifacts/2026-10-26/dung-review/execution/flutter-test.log), [analyze](../../qa-artifacts/2026-10-26/dung-review/execution/flutter-analyze.log); details [review report](reports/2026-10-26-dung-review.md). |
| 2026-10-26 | `b949513b254bee55a3887e619786ea91f85b477f` | same source | `b949513b254bee55a3887e619786ea91f85b477f` | Playwright MCP UI smoke, `PreviewBackend` in-memory | 12 PASS across lecturer/student mock flows; not API acceptance. [Web UI report](reports/2026-10-26-web-ui.md) and [selected evidence](evidence/2026-10-26/web-ui/). |
| 2026-10-26 | `b949513b254bee55a3887e619786ea91f85b477f` | same source | `b949513b254bee55a3887e619786ea91f85b477f` | Mobile MCP UI smoke on separate `vn.edu.hust.quizhub.qa.preview`, `PreviewBackend` in-memory | 5 PASS, 2 BLOCKED/INCONCLUSIVE; app uninstalled after test. [Native UI report](reports/2026-10-26-mobile-ui-setup.md); selected screenshots [here](evidence/2026-10-26/android-ui/). No acceptance-matrix status changed. |
| 2026-11-15 | `999a1678206a6b0d5589cf2c97a0f677ef8bb017` | `08a5a2e4097923d21bbdaf7d02cb1792f2171aa3` | `999a1678206a6b0d5589cf2c97a0f677ef8bb017` | Flutter 3.47.9: `flutter test --no-pub test/features/exam_ui_test.dart` | Exit 1 during compile/load; 0 tests executed; `CupertinoPageTransitionsBuilder` missing at AppTheme lines 196–197. [Evidence](evidence/2026-11-15/regression/theme-baseline.txt). |
| 2026-11-15 | Nam feature/search source `639da129d89e8290c13b63af3d36045309b38fd6` | upstream `08a5a2e4097923d21bbdaf7d02cb1792f2171aa3` | Same pristine source; QA repro tests in ignored snapshot | Initial combined run, then corrected-host UI run | Initial command exit 1 (7/2) included invalid empty-state overflow from incomplete host; five async-close paths + second-tap loss remain confirmed. Corrected UI file exit 0, 3/3, no overflow. [Nam evidence](evidence/2026-11-15/nam/README.md), [host correction](evidence/2026-11-15/nam/host-correction.txt). |
| 2026-11-15 | Nam preview source `639da129d89e8290c13b63af3d36045309b38fd6` | upstream `08a5a2e4097923d21bbdaf7d02cb1792f2171aa3` | APK built from separate Nam preview snapshot | Preview APK build/install; attempted native UI launch | Build exit 0 in 772.3 s; APK SHA-256 `c09122a2c64d4e76650176c330b4494d090f822bd0357dc2b76b512fe7718603`; install succeeded via ADB fallback. UI **BLOCKED / NOT RUN** because another app's overlay kept focus away from QA after relaunch + Back; no product defect/UI result claimed. QA app later uninstalled successfully; MCP uninstall and `pm path` absence confirmed. |
| 2026-11-15 | QA docs/evidence snapshot `f3661a2db84c3e4fb544b1307f599b96c360e1e6` | `08a5a2e4097923d21bbdaf7d02cb1792f2171aa3` | Nam runtime baseline `639da129d89e8290c13b63af3d36045309b38fd6` for host-correction evidence | Tracker correction + CSV readback | `QH-QA-009` row18 reclassified Other/harness, owner Sơn, Closed / Retest Pass; evidence URL pinned and HTTP 200-verified. 9 unique issue rows: 8 Open, 1 Closed. See [tracker update report](reports/2026-11-15-tracker-update.md). |
| 2026-11-20 | Nam preview source `639da129d89e8290c13b63af3d36045309b38fd6` | upstream `08a5a2e4097923d21bbdaf7d02cb1792f2171aa3` | Existing QA preview APK SHA-256 `c09122a2c64d4e76650176c330b4494d090f822bd0357dc2b76b512fe7718603` reused; no build today | Mobile MCP native preview; Search, Notifications, Push settings; permission denial attempt | Search/notification fixture interactions and push draft/cancel/save/reopen observed. API/FCM NOT RUN; Android deny branch INCONCLUSIVE; no acceptance matrix change. Cleanup uninstall confirmed and ADB stopped. [Native report](reports/2026-11-20-nam-native.md), 18 selected context screenshots in `evidence/2026-11-20/nam-native/`. |
| 2026-11-24 | `d89a8d660d93842475b694100ccef1fdf783ed9e` | — | `d89a8d660d93842475b694100ccef1fdf783ed9e` | Native PREVIEW build gates and Mobile MCP core/academic phases | Core UI phase completed on Lecturer artifact (40 preview checks: 27 PASS, 1 WAITING, 6 NOT RUN, 6 BLOCKED). Lecturer academic phase stopped by quota (19 UI checks: 12 PASS, 0 FAIL, 1 WAITING, 0 BLOCKED, 6 NOT RUN). Fresh Student artifact passed build/kernel/signature checks but was not installed or startup-observed. QA app and eight device fixtures were cleaned up. Preview only; acceptance baseline 24 NOT RUN / 1 WAITING and issue statuses unchanged; API/FCM blocked. [Retest](reports/2026-11-24-native-retest.md), [core](reports/2026-11-24-native-core.md), [Lecturer](reports/2026-11-24-native-lecturer.md), [resume](reports/2026-11-24-resume.md), [cleanup](evidence/2026-11-24/device-cleanup.txt), [build evidence](evidence/2026-11-24/native-build-gate.txt). |
| _Thêm dòng sau lần chạy mới_ |  |  |  |  |  |
