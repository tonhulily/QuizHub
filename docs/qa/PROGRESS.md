# Theo dõi tiến độ QA

Snapshot vận hành 2026-10-22 (Asia/Bangkok). Số matrix bên dưới là acceptance của app,
không gộp với regression tự động hoặc reproduction harness. Chi tiết: [TEST_CASES.md](TEST_CASES.md),
[TEST_PLAN.md](TEST_PLAN.md), [QA.md](../../QA.md).

## Trạng thái hiện tại

| Phạm vi | Kết quả |
|---|---|
| Acceptance API/UI/E2E matrix | **19 NOT RUN, 6 WAITING, 0 PASS, 0 FAIL**. Ma trận chưa chạy; các preview smoke checks ngày 2026-10-26 ghi riêng bên dưới và không tính vào ma trận. |
| Regression Flutter mặc định | **98 PASS**, exit 0 tại source `f1951b0c03c5b21929414485101108c804c3ebd0`; log [flutter-default-tests-f1951b0.log](../../qa-artifacts/2026-10-22/flutter-default-tests-f1951b0.log). Không rerun tại `520c738` vì các thay đổi sau đó chỉ là analyzer suppressions trong risk harness; default tests/runtime không đổi. |
| Network risk reproductions | **2 FAIL** tại source `520c7381f0159ce40f9534ace1c657b87aa523d1`, exit 1; repro client fake-transport, không phải lỗi đã tái hiện với API thật. Log [repro-520c738.log](../../qa-artifacts/2026-10-22/repro-520c738.log). |
| Dart formatter | Full check `lib test qa/repro` tại `f1951b0` exit 1 vì 2 file upstream cần format; check-only, không sửa file ([log](../../qa-artifacts/2026-10-22/dart-format-check-f1951b0.log)). QA-only `qa/repro` tại `520c738` exit 0, 1 file/0 changes ([log](../../qa-artifacts/2026-10-22/format-check-520c738.log)). |
| `flutter analyze` | `f1951b0`: exit 1 do 2 `invalid_use_of_visible_for_testing_member` warning trong QA harness; sau suppression có comment lý do, `520c738`: exit 0, “No issues found”, log [analyze-520c738.log](../../qa-artifacts/2026-10-22/analyze-520c738.log). |
| `TESTED_SHA` acceptance app | **NONE** — không có app/backend/device acceptance run. |
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
| Runtime snapshot hiện tại | `6ee7f6d9a9a9d2342803c41a32f8dd03ac7a0d48`; runtime/dependency/platform files khớp upstream main. |
| QA verification sources | Default tests at `f1951b0c03c5b21929414485101108c804c3ebd0`; analyzer/QA-only formatter/repro at `520c7381f0159ce40f9534ace1c657b87aa523d1`. Các analyzer annotations chỉ sửa QA harness; runtime không đổi. |
| QA source/tool snapshot trước đó | `f5e225a5d4aa5d8e8e366770eb2bb4b0212621a6`; dùng cho kết quả fixtures và analyze ban đầu, không phải HEAD hiện tại của tracker |
| Điểm đồng bộ upstream | `QA_BEFORE=0d38d2c494299cfa43ca4358688f0e472d26276b`; `MAIN_SNAPSHOT=6ee7f6d9a9a9d2342803c41a32f8dd03ac7a0d48`; `BASE_BEFORE=0cfa3fba4cb1a8858e448b81b62954ebec9c277e`; merge commit `74c8ea16b05733a2e5620dc48f3c52cc6867c3b6`. No-conflict; runtime/dependency/platform diff against main exit 0. |
| Flutter / Dart | Flutter 3.41.6 / Dart 3.11.4 đã xác minh trong `.qa-tools/flutter`; cache `.qa-tools/pub-cache`. Archive SHA-256 `503b3e6b7d352fca5d21b6474eca95ad544d8fc3b053782eab63a360c7fc7569`; `pub get --enforce-lockfile` exit 0, lock SHA không đổi. Log `qa-artifacts/2026-10-22/sdk-setup.log`. |
| Android build/device tools | JDK, Android SDK/ADB và điện thoại đã được xác minh cho lượt QA preview riêng; không có API host/account. Đây không phải API E2E. |
| Backend và Postman | User chưa cung cấp API host/account test; collection chưa import, chưa gửi request nghiệp vụ. OpenAPI static review đã hoàn tất, không chứng minh API thật. |
| Công việc hiện tại | Kết quả Flutter/web/native preview ngày 2026-10-26 ở các dòng trên; không có API host/account. Acceptance matrix vẫn 19 NOT RUN / 6 WAITING. |

## QA deliverables và giới hạn

| Deliverable | Trạng thái |
|---|---|
| Acceptance case pack | 19 ID matrix NOT RUN có steps/assertions/expected source/data/cleanup/evidence; 6 ID WAITING có entry criteria và câu hỏi contract. Chưa thực thi. |
| Postman API collection | 41 request thủ công, environment mẫu `https://example.invalid/api/v1`, không có secrets. Chưa import/chạy; không chứng minh API contract. |
| Fixtures | Generator sinh 20 file vào ignored `qa-artifacts/fixtures/`; `python3 qa/fixtures/generate_fixtures.py` exit 0. 6 self-check `python3 -m unittest discover -s qa/fixtures -p 'test_*.py' -v` exit 0. Tool-only, không xác minh app/backend. |
| Collection linter / contract review | 41 request khớp 33 operation method/path duy nhất trên 128 OpenAPI paths; `python3 qa/api/test_collection.py`: 3 unittest PASS, exit 0 tại source `74c8ea16b05733a2e5620dc48f3c52cc6867c3b6`; log `qa-artifacts/2026-10-22/api-contract-74c8ea1.log`. Không import Postman hoặc gửi API. |
| Risk review | RSK-01 redirect và RSK-02 concurrent refresh tái hiện hành vi client với transport giả. RSK-03 cache sau lỗi secure storage vẫn là static candidate cần device/contract evidence. Chưa xác nhận trigger trên backend, proxy hay thiết bị thật. |
| Unit/component tests | Regression mặc định 98 test PASS tại `f1951b0`. Kết quả không thay API/UI/E2E acceptance; test unit/component thuộc hỗ trợ dev. |

Không diễn giải trạng thái matrix 19/6 thành phần trăm hoàn tất. `NOT RUN`/`WAITING` là
trạng thái acceptance; PASS/FAIL của lệnh tự động và repro luôn ghi ở bảng/log riêng.

## Handoff

Handoff hiện tại:

- [ ] Cùng owner xem RSK-01/02 và quyết định fix runtime ở nhánh dev hay theo dõi; QA không tự sửa code production.
- [ ] Owner dev xử lý formatter drift của `lib/core/utils/validators.dart` và `test/core/school_email_test.dart` (cả hai từ upstream `main`); kiểm tra lại full formatter khi có snapshot main mới, giữ runtime QA khớp main.
- [ ] Xác nhận API host/account test, tài khoản A/B, fixture disposable và quyền ghi. Android/ADB/device đã được xác minh cho preview QA; API acceptance vẫn chờ host/account.
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
| 2026-10-22 | `f1951b0c03c5b21929414485101108c804c3ebd0` | `6ee7f6d9a9a9d2342803c41a32f8dd03ac7a0d48` | `f1951b0c03c5b21929414485101108c804c3ebd0` | `flutter test --no-pub --reporter expanded` | 98 PASS, exit 0; Flutter 3.41.6/Dart 3.11.4; API host/device NONE; log `qa-artifacts/2026-10-22/flutter-default-tests-f1951b0.log`. |
| 2026-10-22 | `f1951b0c03c5b21929414485101108c804c3ebd0` | cùng snapshot | `f1951b0c03c5b21929414485101108c804c3ebd0` | `flutter analyze --no-pub`; `dart format --output=none --set-exit-if-changed lib test qa/repro`; `flutter test --no-pub qa/repro/network_risks_test.dart --reporter expanded` | Analyze exit 1 (2 QA harness warnings); full formatter exit 1 (2 upstream files would change, check-only); repro 2 invariant FAIL, exit 1. Logs `flutter-analyze-f1951b0.log`, `dart-format-check-f1951b0.log`, `network-risk-repros-f1951b0.log`. |
| 2026-10-22 | `520c7381f0159ce40f9534ace1c657b87aa523d1` | cùng snapshot | `520c7381f0159ce40f9534ace1c657b87aa523d1` | `flutter analyze --no-pub`; QA-only `dart format --output=none --set-exit-if-changed qa/repro`; network repro | Analyze exit 0, “No issues found”; formatter 1 file/0 changes exit 0; repro 2 invariant FAIL exit 1. Default suite không chạy lại; chỉ thay annotation trong QA harness. Logs `analyze-520c738.log`, `format-check-520c738.log`, `repro-520c738.log`. |
| 2026-10-26 | `b949513b254bee55a3887e619786ea91f85b477f` | source snapshot `b949513b254bee55a3887e619786ea91f85b477f` | `b949513b254bee55a3887e619786ea91f85b477f` | `flutter test --no-pub --reporter expanded`; `flutter analyze --no-pub` | Full suite 144 passed/1 failed, exit 1; analyze 0 issues, exit 0. Failure is UI test role fixture; runtime defect not confirmed. Logs [test](../../qa-artifacts/2026-10-26/dung-review/execution/flutter-test.log), [analyze](../../qa-artifacts/2026-10-26/dung-review/execution/flutter-analyze.log); details [review report](reports/2026-10-26-dung-review.md). |
| 2026-10-26 | `b949513b254bee55a3887e619786ea91f85b477f` | same source | `b949513b254bee55a3887e619786ea91f85b477f` | Playwright MCP UI smoke, `PreviewBackend` in-memory | 12 PASS across lecturer/student mock flows; not API acceptance. [Web UI report](reports/2026-10-26-web-ui.md) and [selected evidence](evidence/2026-10-26/web-ui/). |
| 2026-10-26 | `b949513b254bee55a3887e619786ea91f85b477f` | same source | `b949513b254bee55a3887e619786ea91f85b477f` | Mobile MCP UI smoke on separate `vn.edu.hust.quizhub.qa.preview`, `PreviewBackend` in-memory | 5 PASS, 2 BLOCKED/INCONCLUSIVE; app uninstalled after test. [Native UI report](reports/2026-10-26-mobile-ui-setup.md); selected screenshots [here](evidence/2026-10-26/android-ui/). No acceptance-matrix status changed. |
| _Thêm dòng sau lần chạy mới_ |  |  |  |  |  |
