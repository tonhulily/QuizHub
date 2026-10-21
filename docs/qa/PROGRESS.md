# Theo dõi tiến độ QA

Dashboard ngắn cho biết trạng thái triển khai trong repo và trạng thái kiểm thử của Sơn.
Nó bổ sung cho [matrix 25 ca](../../QA.md#test-matrix-khởi-đầu) và
[kế hoạch thực thi](TEST_PLAN.md); không thay thế evidence chi tiết của từng lần chạy.

## Snapshot — 2026-10-21 (Asia/Bangkok)

| Mốc | Giá trị |
|---|---|
| Nhánh QA | `qa/khanhson2005` |
| QA HEAD để rà soát tài liệu/mã | `ddbcda516cb825eb37d64ce8bf06144a137f31b2` |
| `origin/main` local ref được biết | `0cfa3fba4cb1a8858e448b81b62954ebec9c277e` — không fetch trong phiên này, độ mới chưa được xác minh |
| Snapshot main làm nền cho nhánh theo lịch sử local | `0cfa3fba4cb1a8858e448b81b62954ebec9c277e` |
| `TESTED_SHA` của app | **NONE** — chưa chạy test app, analyze hay UI/API trên snapshot này |
| Working tree tại lúc kiểm tra | Sạch trước khi tạo tracker này |

HEAD ở đây là source snapshot đã được đọc/rà soát. Nó không phải `TESTED_SHA` và không
được dùng làm bằng chứng sản phẩm đã pass. Sau khi cập nhật từ `main`, ghi lại SHA mới;
không giả định local `origin/main` đang mới nhất nếu chưa fetch theo quy trình được phép.

## Tiến độ theo test matrix

| Trạng thái hiện tại trong QA.md | Số ca | Diễn giải |
|---|---:|---|
| NOT RUN | 19 | Ca thuộc phần đã có trong source; chưa có kết quả chạy kèm evidence |
| WAITING | 6 | Module/phạm vi chưa bàn giao hoặc chưa đủ contract để kiểm thử |
| PASS | 0 | Chưa có ca nghiệm thu nào được xác nhận PASS |
| FAIL | 0 | Chưa có ca lỗi nào được tái hiện và xác nhận |

Đây là số dòng/case trong matrix, không phải phần trăm hoàn thành sản phẩm. NOT RUN và
WAITING có nguyên nhân khác nhau; không cộng thành tỷ lệ chất lượng app. Các dòng chi
tiết: `QA.md`.

## Trạng thái mã và kiểm thử

| Phạm vi | Trạng thái trong repo | Trạng thái QA |
|---|---|---|
| Auth/session, profile, feed/post/comment/Like, quan hệ, tìm kiếm người dùng | Có implementation theo phạm vi README | Chưa nghiệm thu; các case matrix liên quan còn NOT RUN |
| Question Bank, Exam, Chat, Push/Notification, Search nâng cao, Advanced | Chưa bàn giao/đủ phạm vi theo QA.md | WAITING; tạo case khi có build và contract |
| Bộ test Dart hiện có | 13 file `*_test.dart`; có test API, model, repository và widget | Chưa chạy trong snapshot này; sự tồn tại của test không phải PASS |
| Test hỗ trợ QA mới | 3 file, 14 ca sinh ra từ test cases: Auth/session (4), pagination (4), media validation (6) | Đã rà soát tĩnh; chưa chạy vì thiếu SDK |
| QA manual/API/UI/E2E | Có matrix và case hướng dẫn trong QA.md/TEST_PLAN.md | Chưa chạy trên backend/thiết bị thật |

## Môi trường và kiểm tra đã thực hiện

- `flutter`, `dart`, `java`, `adb`: không có trong PATH; các vị trí SDK Android/Flutter
  thường gặp đã kiểm tra cũng không có. `flutter test`, `flutter analyze` và format chưa
  chạy; không tự cài SDK hay dependency.
- Test backend, tài khoản A/B và thiết bị thật chưa được xác minh/cấp trong phiên này.
  Cần các tài nguyên đó để kết luận về server authorization, side effect, upload và E2E.
- `bash -n scripts/setup.sh`: **exit 0** tại QA HEAD nêu trên. Đây chỉ xác nhận cú pháp
  shell của script setup; không phải test ứng dụng.
- Rà soát cấu hình trước đó: đường dẫn tài liệu/JSON đã được kiểm tra; rule Git khớp
  `git push` với prompt và không khớp `git fetch`. Đây là kiểm tra cấu hình local, không
  phải kiểm thử sản phẩm và không cho phép push.
- Không ghi nhận kết quả API thật, thiết bị thật, Flutter test hay analyze là PASS.

## Việc tiếp theo

- [ ] Người quản lý môi trường chuẩn bị Flutter/Dart và thiết bị; ghi phiên bản trước khi chạy. Không cài tự động từ tracker.
- [ ] Xác nhận backend test, tài khoản được cấp cho vai trò cần kiểm tra và cách dọn fixture; không dùng production cho thao tác ghi.
- [ ] Chạy test hỗ trợ QA, toàn bộ `flutter test`, format check và `flutter analyze`; lưu exit code và `TESTED_SHA` chính xác.
- [ ] Thực thi các ca manual/API P0 trước, đặc biệt auth/session và quyền nội dung với hai tài khoản; lưu request/response đã che bí mật cùng ảnh/video.
- [ ] Chạy các ca P1 theo module đã bàn giao, retest bug đã sửa và regression liên quan.
- [ ] Khi module WAITING được tích hợp, chốt expected với owner rồi mới chuyển sang NOT RUN.

Unit/component test Dart thuộc ownership dev và là bằng chứng hỗ trợ. Kết quả QA bắt
buộc trong phạm vi đã thống nhất là acceptance API/UI/E2E theo build bàn giao, cùng
evidence có thể tái lập. Xem [TEST_PLAN.md](TEST_PLAN.md).

## Nhật ký chạy

Giữ lại các dòng cũ; thêm một dòng sau mỗi lần chạy. `SOURCE_SHA` là commit code được
đọc/chạy; chỉ điền `TESTED_SHA` sau khi thực sự chạy trên đúng commit. Với mỗi lần merge
`main`, ghi snapshot main được nhập và chạy lại regression bị ảnh hưởng; PASS cũ không tự
được chuyển sang SHA mới.

| Ngày / giờ | SOURCE_SHA | MAIN_SNAPSHOT | TESTED_SHA | Case IDs / lệnh | Kết quả + evidence |
|---|---|---|---|---|---|
| 2026-10-21 | `ddbcda516cb825eb37d64ce8bf06144a137f31b2` | `0cfa3fba4cb1a8858e448b81b62954ebec9c277e` (local, chưa fetch) | — | Kiểm tra môi trường; `bash -n scripts/setup.sh` | Exit 0 cho cú pháp script; app test NOT RUN vì Flutter/Dart không có |
| _Thêm dòng khi có phiên chạy mới_ |  |  |  |  |  |

Mẫu dòng mới cần ghi thêm thiết bị/OS, API host, kết quả từng ID (`PASS`, `FAIL`,
`BLOCKED`, `NOT RUN`, `WAITING`), exit code và vị trí evidence. Che token, cookie,
password và thông tin cá nhân. Nếu không chạy được trên SHA mới, giữ trạng thái
NOT RUN/BLOCKED; không sao chép PASS từ snapshot cũ.
