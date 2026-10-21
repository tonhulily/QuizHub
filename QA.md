# Góc làm việc của Sơn — Tester / QA

Nhánh: `qa/khanhson2005`. Phạm vi: test, tài liệu và cấu hình chạy phục vụ QA.
Đây là nhánh cá nhân lâu dài; chỉ nhận thay đổi từ upstream `main`. Nhánh QA không
được merge vào `main` hoặc nhánh khác, không dùng để mở PR, và không được push nếu
chưa có yêu cầu rõ ràng sau này. Mã runtime QA mặc định theo đúng snapshot `main` đã
tích hợp; phạm vi cá nhân chỉ gồm test, cấu hình QA và tài liệu. Không thay đổi nghiệp vụ app.

Tài liệu: [theo dõi tiến độ](docs/qa/PROGRESS.md),
[kế hoạch kiểm thử](docs/qa/TEST_PLAN.md),
[19 test case chi tiết + 6 case chờ bàn giao](docs/qa/TEST_CASES.md),
[bộ request API Postman và hướng dẫn](qa/api/README.md),
[fixture biên và self-check](qa/fixtures/README.md),
[repro rủi ro network phía client](qa/repro/README.md),
[rủi ro tĩnh cần xác minh](docs/qa/RISKS.md),
[môi trường và lệnh đã thử](docs/qa/ENVIRONMENT.md),
[quy trình Git](docs/qa/GIT_WORKFLOW.md),
[thiết lập agent](docs/qa/AGENT_SETUP.md).

Nguồn phân công: [Kế hoạch phân công — Flutter Social Question Bank](https://docs.google.com/spreadsheets/d/1URTpbSX2k_04dvurVlJUbkP2iDILs618CKItSpDxjq4/edit#gid=0),
đọc ngày 21/10/2026, cả ba tab `Phân chia công việc`, `Phân chia màn hình`,
`Dependency & Tiêu chí`. Đây là bản ghi tại thời điểm đọc, cần đối chiếu lại khi nhóm đổi phân công.

Sơn (TV4) lập test matrix, kiểm thử API/UI/business rule/E2E/mạng/thiết bị, ghi bug,
verify fix và regression. Bắt đầu từ phần nền tảng Như đã code, rồi kiểm thử từng luồng
hoàn chỉnh khi các bạn bàn giao. Thứ tự trong bảng: Auth → Home/Social → Question Bank
→ Relationship/Chat → Notification/Search → Advanced.

**Ranh giới trách nhiệm:** unit/component test cho logic Dart thường do dev viết và
duy trì cùng module. QA chịu trách nhiệm kịch bản, acceptance criteria, bằng chứng và
kết quả kiểm thử; có thể tự động hoá API/UI/E2E nếu nhóm thống nhất. Ghi chú “viết test
phần Như đã code” trong bảng chưa quy định bắt buộc Sơn phải viết unit test. Ba file
test Dart bổ sung trên nhánh này là hỗ trợ hồi quy cho dev, không thay cho QA API/UI
và không chuyển quyền sở hữu unit test sang Sơn.

## Owner để chuyển bug

| Owner | Phạm vi theo phân công |
|---|---|
| Như / TV1 | Nền tảng, Auth, profile cơ bản, network/storage, shared UI, tích hợp/build |
| Dũng / TV2 | Ngân hàng câu hỏi, đề thi, AI, gamification sau core |
| Quốc Anh / TV3 | Feed/post/comment/Like, quan hệ, chat, media |
| Nam / TV5 | Search, notification, FCM, settings/device/push, hỗ trợ release |
| Sơn / TV4 | QA toàn hệ thống, verify fix và quyết định kết quả kiểm thử |

Kế hoạch phân công không đồng nghĩa với trạng thái đã triển khai. Mốc repo ban đầu:
`0cfa3fb`; phạm vi hiện có xem [README](README.md#phạm-vi). Chưa coi placeholder là
tính năng đã hoàn thành hoặc tự động ghi nhận nó là bug.

## Chạy phiên làm việc

1. Cài môi trường theo [REQUIREMENTS](REQUIREMENTS.md). Trên Windows dùng PowerShell;
   trên Linux/macOS/Git Bash dùng script bash đã có. Test tự động không cần điện thoại,
   nhưng cần Flutter SDK và thư viện từ `flutter pub get`.
2. Chạy bộ test mới, rồi toàn bộ regression:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test test/features/auth_session_test.dart test/core/paged_cubit_test.dart test/data/media_validation_test.dart
flutter test --coverage
```

3. Chạy UI: lấy ID từ `flutter devices`, thay `<device-id>` trong lệnh:

```bash
flutter run -d <device-id> -t lib/main_preview.dart
flutter run -d <device-id> -t lib/main.dart
```

Đổi server test cho bản thật bằng
`--dart-define=API_BASE_URL=https://<test-host>/api/v1`. Bản thật mặc định dùng server
trong `lib/core/config/app_config.dart`; ghi rõ URL và commit trong mỗi lần test.

VS Code có ba cấu hình F5 trong `.vscode/launch.json`: preview, preview có tài khoản
đăng nhập nhanh, backend thật. Bản có tài khoản mẫu vẫn vào app trước; logout để xem
thẻ đăng nhập. Các task `Sơn QA:*` trong Terminal → Run Task chạy test mới, analyze và
regression. Cần extension Dart/Flutter và chọn thiết bị có sẵn.

Preview giả lập API, chấp nhận mọi credentials và trả HTTP 200/code `0000` cả khi route
chưa được định nghĩa. Nó không chứng minh xác thực, phân quyền, upload hay lỗi server
thật hoạt động đúng. Ảnh mẫu vẫn dùng Internet. Token/API mẫu ở RAM, nhưng entry preview
vẫn dùng LocalStorage/CredentialStorage mặc định: không giả định dữ liệu cục bộ được
cách ly với bản thật; nên dùng thiết bị/emulator test riêng.

## Test matrix khởi đầu

P0: ưu tiên phiên đăng nhập, quyền truy cập và dữ liệu. P1: luồng chính và phục hồi lỗi.
P2: giao diện phụ và chức năng sau core. Đây là thứ tự test, không phải severity bug.

`NOT RUN`: đã có để kiểm tra nhưng chưa chạy; `BLOCKED`: thiếu môi trường/tài khoản;
`WAITING`: chưa triển khai; `PASS`/`FAIL`: chỉ ghi sau khi chạy kèm bằng chứng.

Mọi dòng dưới đây chưa được chạy trong đợt thiết lập nhánh. Cột tự động là file test
có liên quan, không có nghĩa file đó bao phủ toàn bộ acceptance criteria của dòng.

| ID | Mức / owner | Ca kiểm thử và kết quả mong đợi | Tự động / môi trường | Trạng thái |
|---|---|---|---|---|
| AUTH-01 | P0 / Như | Email rỗng/sai, password rỗng: báo lỗi trước API; tài khoản hợp lệ vào đúng màn | `models_test`, UI/backend test | NOT RUN |
| AUTH-02 | P0 / Như | Tài khoản mới bắt buộc tên + avatar; Back/khởi động lại không vượt bước | Backend test | NOT RUN |
| AUTH-03 | P0 / Như | Access token hết hạn: refresh và retry; refresh không hợp lệ: xoá phiên, về login | `api_client_test`, `auth_session_test` | NOT RUN |
| AUTH-04 | P0 / Như | Logout lúc server lỗi/mất mạng vẫn xoá token và cache profile/feed | `auth_session_test`, backend test | NOT RUN |
| AUTH-05 | P0 / Như | Đổi A → B: không thấy dữ liệu A; ghi nhớ/bỏ lưu hoạt động đúng | `saved_account_test` một phần, UI/backend test | NOT RUN |
| AUTH-06 | P1 / Như | Mật khẩu mới 5/6/32/33 ký tự, ký tự đặc biệt, confirm lệch; thất bại không đổi mật khẩu đã lưu | `models_test`, `saved_account_test`, UI/backend test | NOT RUN |
| PROF-01 | P1 / Như | Sửa tên/avatar/cover, gỡ ảnh; cancel hoặc API lỗi không báo lưu thành công | `remove_photos_test`, `profile_privacy_ui_test`, UI/backend test | NOT RUN |
| PAGE-01 | P1 / Như | Load đầu, truyền cursor khi load more, dừng cuối danh sách; nhiều lần cuộn không gửi trùng request đang chạy | `paged_cubit_test` | NOT RUN |
| PAGE-02 | P1 / Như | Load more lỗi giữ dữ liệu/cursor để retry; mã 9994 kết thúc, không xoá nội dung cũ | `paged_cubit_test` | NOT RUN |
| PAGE-03 | P1 / Như | Refresh lỗi vẫn có cache; refresh thành công thay trang đầu; danh sách rỗng hiện empty state | UI/backend test | NOT RUN |
| POST-01 | P1 / Quốc Anh | Đăng text/ảnh; 499/500/501 từ, 0/1/4/5 ảnh; dữ liệu hợp lệ hiện ở home và profile | UI/preview rồi backend test | NOT RUN |
| POST-02 | P0 / Quốc Anh | PUBLIC/FRIENDS/ONLY_ME: hai tài khoản kiểm tra đúng đối tượng được xem qua feed và truy cập trực tiếp | Backend test, cần hai tài khoản | NOT RUN |
| POST-03 | P1 / Quốc Anh | Xoá bài của mình, refresh và mở lại không hiện bài ma; huỷ xoá giữ bài | `deleted_posts_test`, `feed_ghost_test`, UI/backend test | NOT RUN |
| REACT-01 | P1 / Quốc Anh | Like/unlike, API lỗi hoàn tác cả trạng thái và số đếm, các màn đồng bộ | UI/backend test | NOT RUN |
| COMM-01 | P0 / Quốc Anh | Bình luận tối đa 500 từ; chỉ chủ được xoá, không sửa; API từ chối người khác xoá trực tiếp | UI/backend test | NOT RUN |
| MEDIA-01 | P1 / Quốc Anh | Ảnh đúng 4 MiB được gửi; vượt 1 byte hoặc đuôi GIF bị chặn trước API | `media_validation_test` | NOT RUN |
| MEDIA-02 | P1 / Quốc Anh | Từ chối quyền camera/gallery, huỷ chọn ảnh, upload timeout: không crash, có thông báo/retry phù hợp | Hai điện thoại thật | NOT RUN |
| REL-01 | P1 / Quốc Anh | Kết bạn cùng vai trò; accept/decline/cancel; follow khác vai trò; search tên/mã/email | `friends_test`, `friend_actions_test`, backend test | NOT RUN |
| REL-02 | P0 / Quốc Anh | Block/unblock: đối chiếu contract về feed/profile/tương tác; cả hai chiều và hai tài khoản | Backend test; cần thống nhất contract chi tiết | NOT RUN |
| QUESTION-01 | P1 / Dũng | Tạo/sửa/xoá submission, câu trùng, answer/rating; chốt expected từ contract khi bàn giao | Chưa triển khai module | WAITING |
| EXAM-01 | P1 / Dũng | Sinh/xem/export đề; validation và lỗi API; chốt expected khi bàn giao | Chưa triển khai module | WAITING |
| CHAT-01 | P1 / Quốc Anh | Send/read/delete, block và mất mạng/reconnect không mất/trùng tin nhắn; chốt contract | Chưa triển khai module | WAITING |
| PUSH-01 | P1 / Nam | FCM foreground/background/terminated, permission, token đăng ký và deep link | Chưa triển khai; hai điện thoại thật | WAITING |
| SEARCH-01 | P1 / Nam | Search/history/saved search, refresh/load more; tìm người đã có kiểm tra riêng ở REL-01 | Chưa đủ phạm vi search theo kế hoạch | WAITING |
| ADV-01 | P2 / Dũng | Gamification/AI sau core, test theo contract lúc bàn giao | Chưa triển khai module | WAITING |

Quy tắc biên trong code dùng byte: 4 MiB = 4,194,304; 15 MiB = 15,728,640.
`media_validation_test` còn kiểm tra giới hạn video ở repository để chuẩn bị tích hợp;
không đánh dấu video UI là đã triển khai. File mẫu chỉ dùng kiểm tra kích thước/đuôi,
không kiểm chứng định dạng media thực, nội dung file hay dịch vụ lưu trữ.

## Ba ca manual bắt đầu ngay khi có môi trường

**AUTH-01 — validate trước khi gọi API**

- Điều kiện: mở màn login, bật log debug; dùng preview hoặc bản thật.
- Bước: để trống cả hai ô rồi bấm đăng nhập; nhập email `abc` với password bất kỳ;
  cuối cùng nhập email hợp lệ nhưng để password trống.
- Expected: báo lỗi đúng ô ở từng lần, vẫn ở login, không có request
  `POST /auth/login` cho dữ liệu không hợp lệ. Không dùng preview để kết luận
  password sai có bị server từ chối hay không.
- Bằng chứng: ảnh lỗi và log request của khoảng thời gian thao tác.

**POST-02 — quyền xem ONLY_ME qua hai tài khoản**

- Điều kiện: backend test, tài khoản A và B được cấp phép, app trên hai thiết bị.
- Bước: A đăng bài ONLY_ME và ghi ID; B refresh feed, mở profile A, rồi thử đọc bài
  qua API `GET /posts/{id}` bằng phiên B; A mở lại bài của mình.
- Expected: A xem được; B không nhận được nội dung bài qua UI hay API. Mã HTTP/body
  lỗi cụ thể phải đối chiếu contract hiện hành, không tự giả định 403 hay 404.
- Bằng chứng: ID bài, ảnh cả hai phía, response đã che token. Chỉ dọn bài test của A.

**PAGE-02 — load more mất mạng rồi retry**

- Điều kiện: backend test có ít nhất hai trang feed; đã tải trang đầu.
- Bước: tắt mạng, cuộn tới cuối; bật mạng và retry/cuộn lại; tiếp tục tới hết dữ liệu.
- Expected: trang cũ vẫn hiển thị khi lỗi; thao tác sau khi có mạng tải tiếp được,
  không trùng/mất bài; hết dữ liệu dừng tải và không crash.
- Bằng chứng: video thao tác và log request/cursor đã che thông tin nhạy cảm.
- Ghi chú: test component chỉ kiểm tra cursor/retry/chặn request đồng thời;
  phát hiện trùng/mất bài trên dữ liệu thật vẫn là việc cần QA xác minh.

## Bug list và mẫu ghi nhận

Chưa có defect server/backend được xác nhận. Hai invariant client tái hiện bằng fake
transport được ghi ở [RISKS.md](docs/qa/RISKS.md); không phải bằng chứng đã gọi server.
Ghi nhận ban đầu:

| ID | Liên quan | Quan sát | Cách xác nhận / trạng thái |
|---|---|---|---|
| QA-NOTE-01 | Auth / Như | `AuthRepository.changePassword` cập nhật bất kỳ saved account nào sau API thành công | Kiểm tra khả năng A còn được lưu khi B đăng nhập; UI hiện nhớ B hoặc bỏ lưu A khi B đăng nhập. Chưa xác nhận đường tái hiện thực tế, chưa coi là bug |
| QA-ENV-01 | Môi trường | SDK Flutter/Dart cô lập hiện đã sẵn; Android JDK/adb, backend test/tài khoản/thiết bị chưa sẵn hoặc chưa xác nhận. Swagger lookup bị ngắt khi người dùng yêu cầu dừng; kết quả chưa biết | Tiếp tục environment/API access check ngày mai; không dùng production credentials/data |

Mỗi bug mới dùng mẫu này, không đưa password/token vào log hoặc ảnh:

```text
ID / tiêu đề:
Owner / severity (Critical, Major, Minor):
Commit / build / API_BASE_URL:
Thiết bị / OS / mạng / vai trò tài khoản (không ghi credentials):
Điều kiện trước:
Các bước tái hiện:
Kết quả mong đợi + nguồn requirement/contract:
Kết quả thực tế:
Tần suất + bằng chứng (ảnh/video/log đã che thông tin nhạy cảm):
Trạng thái: NEW → IN PROGRESS → READY FOR RETEST → VERIFIED hoặc REOPENED
Build đã fix / kết quả retest / các ca regression liên quan:
```

Chỉ kết luận lệch nghiệp vụ khi có nguồn expected rõ. Với điểm chưa thống nhất giữa
README, bảng phân công và backend, ghi câu hỏi cho owner trước khi kết luận lỗi.

## Báo cáo regression và release checklist

Cập nhật ngày 21/10/2026: bộ regression Dart mặc định **95 PASS** trên source
`d58cdf01a4b2e04a41901e8804fe1d49847faccf`; format cho 112 file trong `lib test` exit 0,
không đổi file. Hai test opt-in trong `qa/repro/` **FAIL** vì tái hiện invariant client
không đạt. Đây là hai scope riêng: kết quả 95 test xanh không xoá kết quả repro đỏ.
Không test nào trong 19 acceptance case backend/UI/E2E đã chạy; matrix vẫn **19 NOT RUN,
6 WAITING, 0 PASS, 0 FAIL**. Chưa có API request, backend acceptance hay xác minh thiết bị.
`flutter analyze` ở snapshot `f5e225a5d4aa5d8e8e366770eb2bb4b0212621a6` có output “No issues
found”; chưa chạy lại sau khi thêm repro QA. Chi tiết lệnh/log và giới hạn xem
[PROGRESS.md](docs/qa/PROGRESS.md).

Mỗi lần bàn giao, copy khối sau vào báo cáo của lần chạy và điền từ kết quả thực tế:

```text
Ngày / người chạy: ... / Sơn
SHA upstream `main` đã tích hợp:
SHA nguồn QA được kiểm thử (`TESTED_SHA`):
Build / môi trường API:
Thiết bị 1 / OS:
Thiết bị 2 / OS:
Phạm vi / ID test cases:
Tổng: ... | PASS: ... | FAIL: ... | BLOCKED: ... | NOT RUN: ... | WAITING: ...
Lệnh tự động / exit code / đường dẫn log và coverage:
Bug còn mở / severity / owner / kết quả retest:
Kết luận: PASS, FAIL hoặc BLOCKED + lý do:
```

Sau khi commit báo cáo, ghi `REPORT_COMMIT_SHA` trong handoff bên ngoài commit đó
hoặc lấy lại bằng `git log -1 --format=%H`. Không sửa/amend báo cáo để nhúng SHA
commit chứa chính nó.

- [ ] Ghi riêng SHA upstream `main` đã tích hợp và SHA nguồn QA đã kiểm thử (`TESTED_SHA`); kèm build/server và phạm vi.
- [ ] `dart format --output=none --set-exit-if-changed lib test` và `flutter analyze` sạch.
- [ ] `flutter test --coverage` xanh; lưu kết quả, không dùng coverage thay cho manual test.
- [ ] Smoke Auth → Home → Profile → Social; kiểm tra chéo ít nhất hai tài khoản test.
- [ ] Các ca quyền truy cập, logout, block, pagination và upload trong phạm vi release đã verify.
- [ ] Loading/empty/error, refresh/load more và mất mạng/timeout/retry không crash.
- [ ] Test ít nhất **hai điện thoại thật**, responsive, keyboard, camera/gallery permission.
- [ ] Khi chat/push được tích hợp: verify reconnect, FCM và deep link theo trạng thái app.
- [ ] Bug chặn release đã fix và retest; regression luồng liên quan pass, đính kèm bằng chứng.
- [ ] Xác nhận thay đổi upstream của app đã vào nhánh tích hợp theo quy trình phát triển; QA vẫn trên nhánh cá nhân riêng và chỉ gửi kết quả cho Như/Nam trước đóng gói demo.
