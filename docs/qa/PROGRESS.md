# Theo dõi tiến độ QA

Snapshot vận hành 2026-10-21 (Asia/Bangkok). Số matrix bên dưới là acceptance của app,
không gộp với regression tự động hoặc reproduction harness. Chi tiết: [TEST_CASES.md](TEST_CASES.md),
[TEST_PLAN.md](TEST_PLAN.md), [QA.md](../../QA.md).

## Trạng thái hiện tại

| Phạm vi | Kết quả |
|---|---|
| Acceptance API/UI/E2E matrix | **19 NOT RUN, 6 WAITING, 0 PASS, 0 FAIL**. Chưa có request API thật hoặc app UI/device run. |
| Regression Flutter mặc định | **95 PASS**, exit 0 tại source `d58cdf01a4b2e04a41901e8804fe1d49847faccf`; log `qa-artifacts/flutter-regression-d58cdf0-local-runner.log`. |
| Network risk reproductions | **2 FAIL** (đúng invariant được kiểm tra), exit 1; fake transport/in-memory tại source `d58cdf01a4b2e04a41901e8804fe1d49847faccf`; log `qa-artifacts/network-risks-repro.log`. |
| Dart formatter | Format check cho 112 file `lib test`: exit 0, không đổi file; log `qa-artifacts/dart-format-d58cdf0.log`. |
| `flutter analyze` | Output “No issues found” ở snapshot `f5e225a5d4aa5d8e8e366770eb2bb4b0212621a6`; không rerun sau khi thêm reproduction QA. Exit code/log không được ghi lại trong hồ sơ hiện có. |
| `TESTED_SHA` acceptance app | **NONE** — không có app/backend/device acceptance run. |

Hai FAIL reproduction không mâu thuẫn với 95 PASS: chúng là test opt-in riêng ngoài `test/`, chủ đích kiểm tra invariant chưa đạt. 95 test xanh không xóa hai kết quả này; ngược lại hai repro cũng không đánh dấu matrix backend/UI FAIL. Xem [RISKS.md](RISKS.md) và [hướng dẫn reproduction](../../qa/repro/README.md).

Mã reproduction được lưu trong commit `e1fcf21`; lần chạy ghi ở trên dùng client source
`d58cdf0` và file harness khi còn trong working tree. Chưa chạy lại sau commit theo yêu
cầu dừng kiểm thử. Log, OpenAPI đã tải và fixture sinh ra chỉ giữ local trong
`qa-artifacts/`; SDK/cache trong `/tmp` có thể mất sau khi reset môi trường.

## Baseline và môi trường

| Mốc | Giá trị |
|---|---|
| Nhánh | `qa/khanhson2005` |
| Runtime source đã test | `d58cdf01a4b2e04a41901e8804fe1d49847faccf`; repro harness/docs được thêm trên cùng source tree và không đổi runtime app |
| QA source/tool snapshot trước đó | `f5e225a5d4aa5d8e8e366770eb2bb4b0212621a6`; dùng cho kết quả fixtures và analyze ban đầu, không phải HEAD hiện tại của tracker |
| local `origin/main` | `0cfa3fba4cb1a8858e448b81b62954ebec9c277e`; fetch origin exit 0, không có commit mới tại thời điểm kiểm tra; QA ahead/behind `6/0`, không merge |
| Flutter / Dart | `3.41.6` / `3.11.4`, cài đặt riêng tại `/tmp/quizhub-qa-sdk/flutter`; tạm thời, có thể mất sau khi workspace reset |
| Android build/device tools | JDK/adb và Android device chưa chuẩn bị/xác nhận; UI/device E2E chưa chạy |
| Backend và Postman | Chưa xác nhận host/tài khoản cho API test; collection chưa import, chưa gửi request nghiệp vụ. Đã tải OpenAPI công khai qua TLS; đối chiếu contract còn dở khi người dùng yêu cầu dừng. |
| Công việc hiện tại | Người dùng yêu cầu dừng test đến ngày mai. Không tiếp tục test, SDK hay lookup trong phiên này. |

## QA deliverables và giới hạn

| Deliverable | Trạng thái |
|---|---|
| Acceptance case pack | 19 ID matrix NOT RUN có steps/assertions/expected source/data/cleanup/evidence; 6 ID WAITING có entry criteria và câu hỏi contract. Chưa thực thi. |
| Postman API collection | 41 request thủ công, environment mẫu `https://example.invalid/api/v1`, không có secrets. Chưa import/chạy; không chứng minh API contract. |
| Fixtures | Generator sinh 20 file vào ignored `qa-artifacts/fixtures/`; `python3 qa/fixtures/generate_fixtures.py` exit 0. 6 self-check `python3 -m unittest discover -s qa/fixtures -p 'test_*.py' -v` exit 0. Tool-only, không xác minh app/backend. |
| Collection linter | `python3 qa/api/test_collection.py`: 3 unittest PASS, exit 0 trong working tree, không import Postman hoặc gửi API. |
| Risk review | RSK-01 redirect và RSK-02 concurrent refresh tái hiện hành vi client với transport giả. RSK-03 cache sau lỗi secure storage vẫn là static candidate cần device/contract evidence. Chưa xác nhận trigger trên backend, proxy hay thiết bị thật. |
| Unit/component tests | Regression mặc định có 95 test PASS ở source ghi trên. Kết quả không thay API/UI/E2E acceptance; test unit/component thuộc hỗ trợ dev. |

Không diễn giải trạng thái matrix 19/6 thành phần trăm hoàn tất. `NOT RUN`/`WAITING` là
trạng thái acceptance; PASS/FAIL của lệnh tự động và repro luôn ghi ở bảng/log riêng.

## Handoff cho phiên ngày mai

Đã dừng công việc kiểm thử hôm nay theo yêu cầu người dùng. Khi tiếp tục:

- [ ] Kiểm tra `/tmp/quizhub-qa-sdk/flutter` còn tồn tại; dùng Flutter 3.41.6/Dart 3.11.4 đã chuẩn bị, không cài thêm SDK.
- [ ] Chạy `flutter analyze` sau các file reproduction QA mới và format-check riêng `qa/repro/network_risks_test.dart`; lần analyze trước ở f5e chưa bao phủ các file mới.
- [ ] Cùng owner xem RSK-01/02 và quyết định fix runtime ở nhánh dev hay theo dõi; QA không tự sửa code production.
- [ ] Xác nhận Android JDK/adb/device, backend test/API host, tài khoản A/B, fixture disposable, quyền ghi và cleanup.
- [ ] Đối chiếu collection với OpenAPI đã tải ở `qa-artifacts/swagger/openapi.json`; metadata có URL và SHA-256. Phần so sánh contract chưa hoàn tất; lỗi DNS sandbox trước đó không chứng minh server ngừng hoạt động.
- [ ] Thực hiện acceptance P0 trước trên build được bàn giao; ghi từng case và evidence. Không đổi 19 NOT RUN trước khi case chạy thật.

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
| 2026-10-21 23:32 +07 | Runtime không đổi | cùng snapshot | — | GET tài liệu Swagger/OpenAPI công khai | HTTP 200, TLS được kiểm tra; OpenAPI 3.1.0, 128 paths. Chỉ đọc tài liệu; đối chiếu contract chưa xong. Metadata: `qa-artifacts/swagger/metadata.json`. |
| _Thêm dòng sau lần chạy mới_ |  |  |  |  |  |
