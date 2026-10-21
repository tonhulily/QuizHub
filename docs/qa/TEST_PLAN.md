# Kế hoạch thực thi QA — Sơn (TV4)

Tài liệu này chuyển test matrix ở [QA.md](../../QA.md) thành cách chạy và ghi nhận
kiểm thử. Matrix là danh mục phạm vi; dùng tài liệu này để chuẩn bị phiên test, viết
case chi tiết và quyết định khi nào đủ bằng chứng để báo PASS. Không thay đổi nghiệp vụ
app trong công việc QA. Quy tắc nhánh, phạm vi agent và handoff xem
[AGENT_SETUP.md](AGENT_SETUP.md) cùng [GIT_WORKFLOW.md](GIT_WORKFLOW.md).

## Vai trò và giới hạn

- Sơn phụ trách acceptance criteria, kiểm thử API/UI/E2E, mạng và thiết bị; ghi bug,
  xác minh bản sửa và hồi quy luồng liên quan.
- QA API/UI/E2E trên build bàn giao là phần nghiệm thu bắt buộc trong phạm vi đã chốt;
  unit/component test Dart là trách nhiệm dev và chỉ là bằng chứng hỗ trợ, không thay cho
  QA manual/integration. Chỉ coi unit test là cổng bắt buộc nếu nhóm ghi rõ tiêu chí đó.
- Dev sở hữu unit/component test của logic Dart trong module. QA có thể đề xuất hoặc
  bổ sung test hỗ trợ hồi quy khi đã thống nhất với nhóm; các test đó không thay cho
  kiểm thử tích hợp và người dùng.
- Test chỉ dựa trên tính năng đã bàn giao. Placeholder được ghi WAITING, không đánh
  FAIL chỉ vì chưa được triển khai.
- Dùng tài khoản và môi trường được cấp cho kiểm thử. Không ghi password, token, email
  cá nhân hoặc dữ liệu nhạy cảm vào ảnh, log hay báo cáo.

## Trạng thái hiện tại

Repo đã có nền tảng Auth, profile, feed/post/comment/Like, quan hệ và tìm kiếm người
dùng. Xem phạm vi chính xác trong [README](../../README.md#phạm-vi) và các ID cùng owner
trong [QA.md](../../QA.md#test-matrix-khởi-đầu). Đây là cơ sở để QA bắt đầu với Auth,
phân trang, hồ sơ và social; chưa có nghĩa các luồng đã được nghiệm thu.

Các module ngân hàng câu hỏi, đề thi, chat, notification/push, search nâng cao và
gamification/AI được để WAITING cho đến khi có build tích hợp và contract kiểm thử. Khi
module được bàn giao, owner dev cung cấp build/commit, API host, tài khoản/fixture test,
expected behavior và known limitations; QA cập nhật case thay vì đoán expected.

Flutter 3.41.6 / Dart 3.11.4 hiện đã được chuẩn bị riêng dưới `/tmp/quizhub-qa-sdk`.
JDK/adb và thiết bị Android chưa sẵn sàng; backend test, tài khoản/fixture API cũng chưa
được xác nhận. Regression Dart mặc định chạy 95/95 PASS tại source SHA
`d58cdf01a4b2e04a41901e8804fe1d49847faccf`; hai test repro rủi ro chạy riêng và FAIL
đúng các invariant client đang kiểm tra. Đây không phải acceptance API/UI/E2E; matrix
nghiệm thu vẫn 19 NOT RUN và 6 WAITING. Analyze có output “No issues found” ở snapshot
f5e trước khi repro được thêm, chưa rerun sau thay đổi QA đó. Sơn yêu cầu dừng test hôm
nay; phiên tiếp theo tiếp tục từ handoff trong [PROGRESS.md](PROGRESS.md).

## Bộ công cụ QA đã chuẩn bị

- [TEST_CASES.md](TEST_CASES.md) có bước, assertion, expected source, dữ liệu, cleanup
  và evidence cho đủ 19 ID matrix đang NOT RUN; sáu ID WAITING có tiêu chí bàn giao và
  câu hỏi contract, không tự dựng expected cho module chưa có.
- [Postman collection](../../qa/api/README.md) có 41 request thủ công theo repository
  hiện tại và environment mẫu. Chỉ host `example.invalid`, chưa có secrets, không chạy
  tự động; import/chạy Postman và mọi request backend vẫn chưa được xác minh. Chỉ đổi
  sang backend test được cấp, rà soát nhãn ghi/xóa rồi gửi thủ công; không chạy Runner.
- [Fixture biên](../../qa/fixtures/README.md) tạo dữ liệu local với Python chuẩn, không
  cần package ngoài. Generator tạo 20 file vào `qa-artifacts/fixtures/`; self-check có
  6 test. Log hiện tại ghi self-check 6/6 và generator 20 file đã xác minh; đây chỉ là
  kiểm tra công cụ/fixture, không phải PASS cho app, picker hay backend. Picker có thể
  re-encode ảnh, nên boundary UI cần đo byte thực tế ở repository.
- [Static collection linter](../../qa/api/test_collection.py) có ba unittest offline;
  3/3 đã chạy thành công để kiểm tra cấu trúc/guard local, không gọi Postman hay backend.
- [RISKS.md](RISKS.md) ghi hai invariant client đã tái hiện trong fake transport
  (redirect gửi token/body ngoài origin; caller chờ refresh timeout nhận sai loại lỗi),
  cùng một candidate cache sau lỗi secure storage còn static-only. Fake transport không
  chứng minh server, proxy, thiết bị hoặc production đã gặp trigger.
- [ENVIRONMENT.md](ENVIRONMENT.md) là nhật ký lệnh, điều kiện môi trường và giới hạn
  thử nghiệm; [PROGRESS.md](PROGRESS.md) là nguồn trạng thái/số đếm duy nhất.

Các request Postman và fixtures giúp thao tác lặp lại; chúng không thay acceptance UI,
API với backend thật, quyền/side effect server hay test thiết bị. Chưa import Postman,
chưa gửi API request; `TESTED_SHA` cho acceptance case vẫn NONE.

## Các giai đoạn

### Kế hoạch các phiên QA kế tiếp

Thực hiện theo thứ tự dưới đây, không gán ngày hoàn thành trước khi có môi trường,
backend test và build bàn giao:

1. **Chốt baseline:** ghi commit hiện tại, build, API host và trạng thái công cụ; xin
   owner cấp tài khoản A/B cùng hướng dẫn reset dữ liệu. Deliverable: phiếu môi trường
   có các mục READY/BLOCKED và bằng chứng cấu hình, không chứa credential.
2. **Mở đường chạy:** sau khi môi trường được chuẩn bị bởi người có quyền, chạy format
   check, analyze và test tự động hiện có. Deliverable: từng lệnh, exit code, log và danh
   sách lỗi; nếu Flutter/Dart còn thiếu, giữ BLOCKED. Không tự tải/cài SDK hay dependency
   như một bước tự động của tài liệu/kịch bản QA.
3. **Nghiệm thu Auth/session:** chạy AUTH-01…06 theo QA.md trên test backend, sau đó
   kiểm tra phiên hết hạn, logout và đổi tài khoản. Deliverable: case đã điền kết quả,
   evidence đã che dữ liệu, bug chuyển Như hoặc danh sách BLOCKED có lý do.
4. **Nghiệm thu nền tảng/social:** chạy profile, pagination/cache, post/privacy,
   comment/Like, media và quan hệ theo owner. Dùng hai tài khoản cho quyền; dùng thiết bị
   thật cho quyền OS và upload. Deliverable: kết quả theo ID, dữ liệu test được dọn hoặc
   ghi rõ chưa dọn, bug chuyển đúng owner.
5. **Lặp theo bàn giao:** với mỗi module mới, chốt contract và case trước khi thực thi;
   nghiệm thu theo module, rồi chạy regression liên quan. Deliverable: decision PASS/FAIL/
   BLOCKED/WAITING có phạm vi và commit rõ.

Sau mỗi lần merge main vào nhánh QA, ghi SHA main trước merge và SHA main mới đã nhập;
xem diff để xác định luồng bị ảnh hưởng, rồi chạy smoke cùng regression liên quan trên
đúng source SHA mới. Mỗi báo cáo phải ghi `QA tested source SHA` trùng với commit code
thực sự đã cài/chạy. Không ghi kết quả của nhánh cũ như kết quả cho main mới; nếu chưa
thể chạy lại, trạng thái các case chịu ảnh hưởng là NOT RUN/BLOCKED cho SHA mới. Cách
đồng bộ nhánh và ghi các mốc SHA xem [GIT_WORKFLOW.md](GIT_WORKFLOW.md).

### Giai đoạn 0 — chuẩn bị môi trường và dữ liệu

1. Chuẩn bị Flutter/Dart theo [REQUIREMENTS](../../REQUIREMENTS.md) qua người quản lý
   môi trường; không cài SDK/dependency tự động trong bước QA. Khi đã sẵn sàng, chạy
   `flutter pub get`, `flutter doctor -v` và xác nhận `flutter devices` nhận thiết bị.
2. Lấy commit/build hash, phiên bản app, OS, model thiết bị, API base URL và cấu hình
   mạng. Không đưa credential vào hồ sơ test.
3. Chạy `flutter test` và `flutter analyze`; lưu exit code và log. Nếu SDK chưa sẵn
   sàng, ghi BLOCKED cùng công cụ còn thiếu, không ghi PASS.
4. Xin backend test host và tài khoản riêng cho từng vai trò. Với test quyền riêng tư,
   cần ít nhất tài khoản A là chủ nội dung và B là người xem; xác nhận A/B có quyền dùng
   dữ liệu test và cách dọn dữ liệu.
5. Kiểm tra preview riêng để học UI/luồng. Preview có thể giả lập thành công cả route
   chưa cài; không dùng nó để nghiệm thu xác thực, phân quyền, upload hoặc lỗi backend.

### Giai đoạn 1 — nền tảng đang có

Chạy theo thứ tự: Auth/session → profile → pagination/cache → post/comment/media →
Like → friend/follow/block/report/search người dùng. Ưu tiên P0 về session, quyền và
dữ liệu; tiếp đó kiểm tra luồng chính và khả năng phục hồi mạng. Case chi tiết được
chọn từ các ID trong QA.md; không cần chạy mọi tổ hợp trên mọi thiết bị ở mỗi lần build.

Với mỗi build mới, chạy smoke Auth → Home → Profile → một luồng social cơ bản. Với thay
đổi liên quan quyền riêng tư hoặc quan hệ, dùng hai tài khoản và kiểm tra cả UI lẫn API
được phép. Với thay đổi paging/feed, thử refresh, tải tiếp, hết dữ liệu và mất mạng.

### Giai đoạn 2 — module mới bàn giao

Mỗi module chỉ chuyển WAITING → NOT RUN khi có build và acceptance criteria cụ thể.
Trước khi test, chốt với owner các trạng thái nghiệp vụ, mã lỗi/HTTP dự kiến, vai trò
được phép, tính bền dữ liệu sau restart, xử lý offline và cách dọn dữ liệu. Tạo case mới
theo quy tắc ID bên dưới rồi mới chạy trên backend test. Chat và push cần nhiều thiết bị
thật; test push thêm các trạng thái foreground, background và app đã bị đóng.

### Giai đoạn 3 — hồi quy và báo cáo bàn giao

Chạy lại các case FAIL đã sửa và những case cùng luồng có khả năng bị ảnh hưởng. Ghi
build sửa, kết quả retest và bằng chứng. Trước demo/release, dùng checklist trong QA.md;
đánh dấu PASS chỉ khi mọi case trong phạm vi có expected rõ và bằng chứng tương ứng.

## Cách viết test case

Expected phải lấy từ requirement đã duyệt hoặc contract backend đã xác nhận. Source code
giúp tìm nơi cần kiểm tra và ghi nhận hành vi đang có, nhưng không tự nó quyết định đúng
sai: nếu code có thể đang sai, ghi actual hiện tại làm evidence và giữ expected theo
requirement/contract. Nếu chưa có normative source thì hỏi owner, để WAITING/BLOCKED.

Mỗi case là một hành động kiểm tra được, có kết quả quan sát được. Dùng ID theo module
đã có trong QA.md; thêm số tiếp theo, ví dụ `AUTH-07`. Case riêng của Sơn được lưu ở
`docs/qa/TEST_PLAN.md` hoặc tài liệu phiên chạy, còn unit test tương lai có thể nằm dưới
`test/qa/`. Không di chuyển hoặc đổi owner cho các test hiện có.

Ghi các trường sau cho mỗi case:

| Trường | Nội dung |
|---|---|
| ID / tên | ID ổn định và hành vi ngắn gọn cần xác nhận |
| Mức / owner | P0/P1/P2 theo rủi ro; owner dev để chuyển bug |
| Loại | API, UI, E2E, mạng, thiết bị hoặc hồi quy |
| Nguồn expected | Requirement, README, API contract/Swagger hoặc quyết định owner; ghi URL/commit/đoạn cụ thể |
| Build / môi trường | Commit, app version, API base URL, OS/model, mạng |
| Điều kiện trước | Vai trò, trạng thái dữ liệu, quyền OS, phiên đăng nhập và fixture cần thiết |
| Dữ liệu | Giá trị hợp lệ/biên/không hợp lệ; dùng dữ liệu giả, chỉ rõ A/B nếu cần |
| Bước + assertion | Mỗi bước một thao tác và ghi ngay quan sát/điều kiện cần đúng sau bước đó; bước cuối xác nhận kết quả tổng |
| Kết quả mong đợi | UI, request/response, state và dữ liệu sau restart nếu thuộc phạm vi; tách theo từng bước khi có nhiều kết quả |
| Kết quả thực tế | Ghi đúng quan sát; không diễn giải khi chưa có nguồn expected |
| Trạng thái / bằng chứng | NOT RUN, BLOCKED, PASS, FAIL hoặc WAITING; log/ảnh/video đã che dữ liệu nhạy cảm |
| Dọn dẹp | Xoá bài/tài khoản test hoặc khôi phục trạng thái đã thay đổi |

Một case có thể có nhiều biến thể đầu vào, nhưng tách thành case mới nếu quyền, kết
quả mong đợi hoặc cách tái hiện khác nhau. Với giá trị biên, ghi cụ thể số lượng và đơn
vị; phân biệt byte với MB/MiB. Với API, lưu method, path, status/body và request ID nếu
có; che Authorization header, cookie và token. Với lỗi UI, lưu ảnh hoặc video cùng log
thời điểm tương ứng.

### Ví dụ — AUTH validate trước API

| Trường | Giá trị |
|---|---|
| ID / tên | `AUTH-01A` — chặn đăng nhập khi email trống hoặc sai định dạng |
| Mức / owner / loại | P0 / Như / UI + API |
| Nguồn expected | Requirement đã duyệt trong README: client validate trước API; `Validators` chỉ giúp định vị code cần quan sát, không phải oracle độc lập |
| Điều kiện | App ở màn login; backend test hoặc proxy/log request quan sát được |
| Dữ liệu | Email rỗng, `abc`, sau đó email hợp lệ với password trống |
| Bước | 1. Để trống cả hai ô và bấm đăng nhập. 2. Nhập `abc` và password bất kỳ. 3. Nhập email hợp lệ, xoá password, bấm đăng nhập. |
| Mong đợi | Mỗi lần báo đúng lỗi tại ô liên quan, giữ màn login và không gửi `POST /auth/login` khi dữ liệu không hợp lệ. |
| Bằng chứng / dọn dẹp | Ảnh lỗi và log khoảng thời gian thao tác; không cần xoá dữ liệu. |

Không dùng preview để xác minh password sai bị backend từ chối. Để kiểm tra thành công/
thất bại xác thực, dùng tài khoản QA và backend test; không thử nhiều mật khẩu ngẫu nhiên
trên tài khoản thật.

### Ví dụ — quyền xem bài ONLY_ME

| Trường | Giá trị |
|---|---|
| ID / tên | `POST-02A` — chỉ chủ xem được bài ONLY_ME |
| Mức / owner / loại | P0 / Quốc Anh / API + E2E trên hai thiết bị |
| Nguồn expected | Requirement README xác nhận visibility `ONLY_ME` và contract hiện hành về truy cập bài; nếu contract access chưa được xác nhận thì BLOCKED |
| Điều kiện | Backend test, tài khoản A/B được phép, hai phiên đăng nhập, mạng ổn định |
| Dữ liệu | A tạo bài duyệt/ghi nhận ID; B là người xem không phải bạn nếu contract yêu cầu |
| Bước | 1. A tạo bài `ONLY_ME`. 2. B refresh feed và mở profile A. 3. B gọi endpoint đọc bài theo ID bằng phiên B. 4. A đọc lại bài. |
| Mong đợi | A đọc được; B không nhận nội dung bài qua UI hoặc API. Status và mã lỗi cụ thể lấy từ contract, không tự mặc định 403/404. |
| Bằng chứng / dọn dẹp | ID, ảnh hai phía, response đã che token; A xoá bài sau khi hoàn tất nếu được phép. |

Nếu contract về quan hệ bạn bè hoặc lỗi access chưa rõ, dừng kết luận ở BLOCKED/WAITING
và hỏi owner. Không coi khác biệt mã lỗi là bug trước khi chốt expected.

## Tự động hoá theo thứ tự ưu tiên

Đây là backlog đề xuất; không cài package, thêm dependency, đổi config hay tạo pipeline
trong đợt lập kế hoạch này.

1. **QA acceptance trước:** trên build tích hợp, chạy case manual UI và API với backend
   test thật theo các ID P0/P1 đã sẵn sàng. Với quyền, dùng hai tài khoản; tạo fixture
   trong phạm vi được phép, ghi request/response (status/body đã che thông tin nhạy cảm)
   và side effects quan sát được, rồi dọn dữ liệu. Đây là bằng chứng bắt buộc cho server
   auth, authorization, persistence và upload. Mock/preview không thể thay thế chúng.
2. **Regression tự động sẵn có:** Flutter SDK cô lập hiện đã được chuẩn bị; ở phiên QA
   kế tiếp chạy test hiện có
   cùng ba test hỗ trợ QA trong `test/features/auth_session_test.dart`,
   `test/core/paged_cubit_test.dart`, `test/data/media_validation_test.dart`, rồi toàn
   bộ `flutter test`; chạy format-check và `flutter analyze`. Ghi lệnh, exit code và
   source SHA. Không tự cài SDK/dependency; nếu thiếu thì BLOCKED.
3. **API fake/component checks (hỗ trợ dev):** kiểm tra parsing, request shape, mapping
   lỗi và hành vi repository với `HttpClientAdapter`/backend giả theo convention trong
   README. Đây là component/contract helper test, không chứng minh server thật xác thực
   quyền xem, lưu side effect, nhận upload hay xử lý production behavior. Dùng backend
   test thật cho các acceptance này; không gọi production.
4. **Widget/UI tự động:** chọn các luồng ổn định có thể chạy không phụ thuộc server,
   như validation trước API, form lỗi/thành công, privacy UI và loading/empty/error.
   Dùng fake repository như convention trong README. Giữ selector/Tooltip hỗ trợ test
   tiếp cận được. Đây là hỗ trợ regression; không thay cho manual QA trên build.
5. **E2E thiết bị:** chỉ tự động hoá sau khi tài khoản test, dữ liệu reset và môi trường
   backend ổn định. Ưu tiên login → home, tạo/xem bài theo quyền, và phục hồi khi mất
   mạng. Camera/gallery, push, keyboard và hiệu năng cần kiểm tra thiết bị thật kể cả khi
   có một phần tự động. Nếu E2E chỉ dùng mock/preview, không coi là nghiệm thu backend.
6. **CI (tùy chọn về sau):** chỉ đề xuất pipeline khi team thống nhất SDK/version,
   ownership và cách cấp secret test. CI là việc chung của nhóm; không cấu hình hay đẩy
   pipeline từ nhánh QA cá nhân, và không dùng credential production.

Tổ chức test mới theo `test/qa/` nếu là kịch bản tích hợp do QA phối hợp viết; test logic
module vẫn ở vị trí và do dev module duy trì. Hiện repo chưa có thư mục `test/qa/` hay
pipeline CI theo khảo sát; tạo chúng chỉ khi có case tự động cụ thể và người sở hữu.

## Ghi nhận kết quả và chuyển bug

Trạng thái dùng đúng nghĩa: `WAITING` = chưa bàn giao/triển khai; `BLOCKED` = đã biết
case nhưng thiếu môi trường, dữ liệu, quyền hoặc contract; `NOT RUN` = sẵn sàng chạy nhưng
chưa chạy; `PASS`/`FAIL` chỉ sau khi thực thi và lưu evidence. Không đổi NOT RUN thành
PASS dựa trên code review hay test file tồn tại.

Khi FAIL, tạo bug theo mẫu ở QA.md, có commit/build, bước tái hiện, expected kèm nguồn,
actual, tần suất và bằng chứng đã che thông tin. Severity phản ánh ảnh hưởng người dùng;
P0/P1/P2 trong matrix chỉ là thứ tự test. Chuyển bug tới owner module, giữ case gốc để
retest, rồi chạy regression liên quan. Nếu thiếu contract, ghi câu hỏi cần quyết định
và chờ owner thay vì gắn nhãn bug nghiệp vụ.

Một phiên chạy tối thiểu ghi: ngày/người chạy, commit/build, host API, thiết bị/OS, danh
sách ID và trạng thái, lệnh tự động/exit code, bug mở, bằng chứng và kết luận có phạm
vi rõ. Báo cáo NOT RUN/BLOCKED là kết quả hợp lệ; không suy rộng thành release pass.
