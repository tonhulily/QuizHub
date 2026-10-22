# Theo dõi tiến độ QA

Snapshot vận hành 2026-10-22 (Asia/Bangkok). Số matrix bên dưới là acceptance của app,
không gộp với regression tự động hoặc reproduction harness. Chi tiết: [TEST_CASES.md](TEST_CASES.md),
[TEST_PLAN.md](TEST_PLAN.md), [QA.md](../../QA.md).

## Trạng thái hiện tại

| Phạm vi | Kết quả |
|---|---|
| Acceptance API/UI/E2E matrix | **19 NOT RUN, 6 WAITING, 0 PASS, 0 FAIL**. Chưa có request API thật hoặc app UI/device run. |
| Regression Flutter mặc định | **NOT RUN hôm nay; chờ setup SDK persistent đã được Sơn duyệt** tại `.qa-tools/flutter`. Lần gần nhất: **95 PASS**, exit 0 tại source `d58cdf01a4b2e04a41901e8804fe1d49847faccf`; log `qa-artifacts/flutter-regression-d58cdf0-local-runner.log`. |
| Network risk reproductions | **2 FAIL** trong client fake-transport/in-memory repro tại source `d58cdf01a4b2e04a41901e8804fe1d49847faccf`; exit 1, log `qa-artifacts/network-risks-repro.log`. Đây là kết quả ở SHA cũ, chưa chạy trên merge mới. |
| Dart formatter | **NOT RUN hôm nay; chờ setup SDK persistent**. Lần gần nhất: 112 file `lib test`, exit 0, không đổi file tại source `d58cdf01a4b2e04a41901e8804fe1d49847faccf`; log `qa-artifacts/dart-format-d58cdf0.log`. |
| `flutter analyze` | **NOT RUN trên merge mới; chờ setup SDK persistent**. Lịch sử tại `f5e225a5d4aa5d8e8e366770eb2bb4b0212621a6`: output “No issues found”; exit code/log không được ghi lại. |
| `TESTED_SHA` acceptance app | **NONE** — không có app/backend/device acceptance run. |
| OpenAPI / collection static review | **Hoàn tất tĩnh**: 41 request, 33 operation duy nhất (method/path) trên 128 paths; OpenAPI SHA-256 `63dc2323…939cc5`. `python3 qa/api/test_collection.py`: 3 PASS, exit 0 tại source `74c8ea16b05733a2e5620dc48f3c52cc6867c3b6`; log `qa-artifacts/2026-10-22/api-contract-74c8ea1.log`. Sơn chưa có API host/account; chưa import Postman hoặc gửi request nghiệp vụ. |

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
| Điểm đồng bộ upstream | `QA_BEFORE=0d38d2c494299cfa43ca4358688f0e472d26276b`; `MAIN_SNAPSHOT=6ee7f6d9a9a9d2342803c41a32f8dd03ac7a0d48`; `BASE_BEFORE=0cfa3fba4cb1a8858e448b81b62954ebec9c277e`; merge commit `74c8ea16b05733a2e5620dc48f3c52cc6867c3b6`. No-conflict; runtime/dependency/platform diff against main exit 0. |
| Flutter / Dart | Bản tạm 3.41.6 / 3.11.4 và cache trong `/tmp` từ 21/10 đã mất. Sơn đã duyệt cài SDK persistent trong `.qa-tools/flutter` với package cache `.qa-tools/pub-cache`; delegate đang setup và chưa báo xác minh hoàn tất. Không cần hỏi lại quyền cài. |
| Android build/device tools | JDK/adb và Android device chưa chuẩn bị/xác nhận; UI/device E2E chưa chạy |
| Backend và Postman | User chưa cung cấp API host/account test; collection chưa import, chưa gửi request nghiệp vụ. OpenAPI static review đã hoàn tất, không chứng minh API thật. |
| Công việc hiện tại | Setup SDK persistent đã được duyệt và đang chạy. Tại checkpoint merge `74c8ea1`, Flutter analyze, regression, formatter và reproduction mới chưa chạy. Acceptance matrix giữ nguyên 19 NOT RUN / 6 WAITING. |

## QA deliverables và giới hạn

| Deliverable | Trạng thái |
|---|---|
| Acceptance case pack | 19 ID matrix NOT RUN có steps/assertions/expected source/data/cleanup/evidence; 6 ID WAITING có entry criteria và câu hỏi contract. Chưa thực thi. |
| Postman API collection | 41 request thủ công, environment mẫu `https://example.invalid/api/v1`, không có secrets. Chưa import/chạy; không chứng minh API contract. |
| Fixtures | Generator sinh 20 file vào ignored `qa-artifacts/fixtures/`; `python3 qa/fixtures/generate_fixtures.py` exit 0. 6 self-check `python3 -m unittest discover -s qa/fixtures -p 'test_*.py' -v` exit 0. Tool-only, không xác minh app/backend. |
| Collection linter / contract review | 41 request khớp 33 operation method/path duy nhất trên 128 OpenAPI paths; `python3 qa/api/test_collection.py`: 3 unittest PASS, exit 0 tại source `74c8ea16b05733a2e5620dc48f3c52cc6867c3b6`; log `qa-artifacts/2026-10-22/api-contract-74c8ea1.log`. Không import Postman hoặc gửi API. |
| Risk review | RSK-01 redirect và RSK-02 concurrent refresh tái hiện hành vi client với transport giả. RSK-03 cache sau lỗi secure storage vẫn là static candidate cần device/contract evidence. Chưa xác nhận trigger trên backend, proxy hay thiết bị thật. |
| Unit/component tests | Regression mặc định có 95 test PASS ở source ghi trên. Kết quả không thay API/UI/E2E acceptance; test unit/component thuộc hỗ trợ dev. |

Không diễn giải trạng thái matrix 19/6 thành phần trăm hoàn tất. `NOT RUN`/`WAITING` là
trạng thái acceptance; PASS/FAIL của lệnh tự động và repro luôn ghi ở bảng/log riêng.

## Handoff

Trong khi SDK persistent đang được chuẩn bị và API host/account chưa có:

- [ ] Sau khi setup `.qa-tools/flutter` và cache hoàn tất, xác minh phiên bản/path rồi chạy `flutter analyze`, formatter check và regression/repro trên merge SHA mới; không gắn kết quả cũ vào SHA mới.
- [ ] Cùng owner xem RSK-01/02 và quyết định fix runtime ở nhánh dev hay theo dõi; QA không tự sửa code production.
- [ ] Xác nhận Android JDK/adb/device, API host và account test, tài khoản A/B, fixture disposable, quyền ghi và cleanup. Chưa có API host/account nên chưa chạy API/UI acceptance.
- [x] OpenAPI static review và collection checks đã hoàn tất tại SHA `74c8ea16b05733a2e5620dc48f3c52cc6867c3b6`; xem `qa-artifacts/2026-10-22/api-contract-74c8ea1.log`. Không thay thế API test thật.
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
| 2026-10-21 23:32 +07 | Runtime không đổi | cùng snapshot | — | GET tài liệu Swagger/OpenAPI công khai | HTTP 200, TLS được kiểm tra; OpenAPI 3.1.0, 128 paths. Chỉ đọc tài liệu; đối chiếu contract chưa xong tại thời điểm đó. Metadata: `qa-artifacts/swagger/metadata.json`. |
| 2026-10-22 | QA `74c8ea16b05733a2e5620dc48f3c52cc6867c3b6` | `6ee7f6d9a9a9d2342803c41a32f8dd03ac7a0d48`; baseline `0cfa3fba4cb1a8858e448b81b62954ebec9c277e` | — | Merge main vào QA | QA trước merge `0d38d2c494299cfa43ca4358688f0e472d26276b`; merge không conflict, staged diff check exit 0, runtime/dependency/platform diff với main exit 0. Không push. |
| 2026-10-22 | `74c8ea16b05733a2e5620dc48f3c52cc6867c3b6` | `6ee7f6d9a9a9d2342803c41a32f8dd03ac7a0d48` | `74c8ea16b05733a2e5620dc48f3c52cc6867c3b6` | `python3 qa/api/test_collection.py` + static OpenAPI/collection review | 3 Python tests PASS, exit 0; 41 requests / 33 operations / 128 paths; OpenAPI hash `63dc2323…939cc5`; `qa-artifacts/2026-10-22/api-contract-74c8ea1.log`. Không import Postman/gọi API thật. |
| _Thêm dòng sau lần chạy mới_ |  |  |  |  |  |
