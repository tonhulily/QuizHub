# Bộ test case chấp nhận — Sơn (TV4)

Bộ case này triển khai chi tiết 19 ID đang `NOT RUN` trong [QA.md](../../QA.md#test-matrix-khởi-đầu).
Giữ nguyên ID để truy vết matrix; các hậu tố như `AUTH-01a` là biến thể cùng phạm vi.
[TEST_PLAN.md](TEST_PLAN.md) mô tả chuẩn bị phiên chạy, evidence, bug và thứ tự QA;
[PROGRESS.md](PROGRESS.md) là nguồn duy nhất cho trạng thái và số liệu chạy hiện thời.

## Baseline và quy tắc kết luận

- Source snapshot được đọc khi soạn: nhánh `qa/khanhson2005`, QA HEAD
  `2af89368608946ac8949766776f527d589495fe8`; local `main` và `origin/main` đều trỏ
  `0cfa3fba4cb1a8858e448b81b62954ebec9c277e`. Không fetch; độ mới của ref remote chưa
  được xác minh.
- Không có ca nào được chạy trong lúc soạn. Matrix vẫn giữ 19 ID `NOT RUN` như lịch sử
  thực thi; readiness hiện tách riêng là `BLOCKED` vì Flutter/Dart vắng mặt và backend,
  tài khoản/thiết bị chưa được xác minh/cấp. Ghi blocker đã biết mà không ám chỉ app case
  đã được thử. Không ghi `PASS` từ code, mock hay nội dung case.
- Expected bắt buộc đến từ requirement đã duyệt trong [README — quy tắc nghiệp vụ](../../README.md#quy-tắc-nghiệp-vụ-phải-giữ)
  hoặc contract backend mà owner đã xác nhận. Code links bên dưới chỉ cho biết nơi
  quan sát UI/request hiện tại; khi code và requirement khác nhau, không dùng code làm
  oracle và mở bug với evidence.
- QA acceptance trên build tích hợp gồm thao tác UI/API tới backend test thật. Backend
  giả, preview và unit/component test hỗ trợ hồi quy nhưng không xác minh server auth,
  quyền truy cập, persistence, upload hoặc side effect.
- API contract có thể đổi: trước lần chạy đầu, ghi `API_BASE_URL`, ngày/phiên bản
  Swagger hoặc xác nhận owner cho endpoint, payload và status/body. Nếu chưa rõ expected
  về HTTP/mã lỗi thì case con liên quan giữ `BLOCKED`, không tự chọn 403/404.
- Dữ liệu chỉ tạo trên backend test với tài khoản được cấp. Ghi SHA chạy, ID case,
  thiết bị/OS, API host, request/response đã che credential, ảnh/video, thời gian và
  cleanup. Không lưu password/token, không thao tác ghi trên tài khoản người khác.

### Điều kiện lúc soạn

Ở snapshot ghi trên, `flutter`, `dart`, `java`, `adb` không có trong PATH; các thư mục
SDK thường gặp cũng chưa được xác nhận. Persistent Flutter SDK 3.41.6/Dart 3.11.4 và
cache/config hiện đã sẵn; lệnh môi trường xem [ENVIRONMENT.md](ENVIRONMENT.md). Không
dùng SDK/cache tạm trong `/tmp`. Acceptance case bên dưới vẫn cần chạy trên build tích hợp
với backend test và thiết bị phù hợp; trạng thái/số liệu của các lượt chạy thực tế chỉ ghi
trong [PROGRESS.md](PROGRESS.md). Đây không phải lỗi app.

## 1. Authentication và session

### AUTH-01 — validate login phía client trước request

- **Mức/owner/loại/trạng thái:** P0 · Như · UI + quan sát API · `NOT RUN`.
- **Expected:** [README, validate ở client](../../README.md#quy-tắc-nghiệp-vụ-phải-giữ) yêu cầu validate trước API. QA cập nhật feature scope theo source delta `main` commit `6ee7f6d9a9a9d2342803c41a32f8dd03ac7a0d48`: username không có `@` được hiểu là prefix trường và hoàn thiện thành `@sis.hust.edu.vn`; email đã có `@` giữ nguyên sau trim, không nối domain lần hai. Đây là acceptance intent của feature delta; owner cần xác nhận domain/username policy nếu khác đặc tả trường. Email empty/malformed và password rỗng phải bị chặn ở field đúng; password login cũ chỉ cần không rỗng.
- **Điều kiện/dữ liệu:** chỉ chạy trên build đã tích hợp commit trên. Cần tài khoản QA disposable hoặc request-capture proxy/test backend; không log password/token. Dữ liệu: empty, username `s12345`, malformed `abc@`, ` s12345 `, `s12345@sis.hust.edu.vn`, ` s12345@sis.hust.edu.vn `, full email ngoài trường `qa@example.invalid`.
- **Bước/assertion:** (1) Email/password rỗng rồi submit → báo đúng hai lỗi, không phát `POST /auth/login`. (2) Nhập username `s12345`, để password rỗng → lỗi riêng ở password, không request. (3) Nhập `abc@` với mật khẩu bất kỳ → lỗi email, không request; `abc` không dùng làm malformed nữa vì username trần được normalize. (4) Focus email, nhập ` s12345 ` → chip gợi ý đúng `s12345@sis.hust.edu.vn`; blur làm chip ẩn. (5) Focus lại, click chip → field là email đầy đủ, cursor ở cuối, chip ẩn; submit bằng nút và kiểm tra request. Ở lượt riêng, nhập lại username có spaces, không click chip, dùng Next rồi Done; request vẫn phải có đúng một email normalized. (6) Nhập full email trường có spaces → chip không xuất hiện; request trim, không append domain lần nữa. (7) Nhập `qa@example.invalid` → request giữ nguyên email ngoài trường; server acceptance không thuộc case này nếu chưa có contract. (8) Nếu có saved account full email, quick-login request không đổi email. (9) Với credentials hợp lệ của tài khoản QA trường, request thành công đưa app tới Home hoặc luồng hoàn tất hồ sơ theo session.
- **Expected/result:** empty/malformed và password rỗng đều bị chặn; username hợp lệ/password rỗng phải báo password riêng. Username trần/full email gửi đúng giá trị client chuẩn hoá; domain ngoài trường không bị helper tự viết lại nhưng server policy còn cần owner xác nhận. Preview/proxy giả chỉ chứng minh client behavior, không chứng minh xác thực backend. Nếu login thành công, logout/cleanup.
- **Nguồn để quan sát:** source delta được đọc qua `git show 6ee7f6d9a9a9d2342803c41a32f8dd03ac7a0d48` (`lib/core/utils/validators.dart`, `lib/features/auth/view/login_view.dart`); caller cuối là `LoginCubit.submit`. Code giúp xác định điểm quan sát, không tự thay requirement/owner policy.
- **Dọn dẹp/evidence:** logout account QA; giữ ảnh chip focus/blur/click và network capture đã redact email/password/token; ghi build SHA, API host, device/OS và trạng thái `NOT RUN` cho tới khi chạy.

### AUTH-02 — buộc hoàn thiện hồ sơ cho tài khoản mới

- **Mức/owner/loại/trạng thái:** P0 · Như · UI + API + restart · `NOT RUN`.
- **Expected:** [README phạm vi](../../README.md#phạm-vi) nói tài khoản mới cần họ tên và avatar trước khi dùng app. Contract cần xác nhận trường server biểu thị incomplete profile và việc lưu bắt buộc.
- **Điều kiện/dữ liệu:** tài khoản QA mới, được cấp quyền login; profile chưa hoàn tất; backend test upload ảnh ổn định.
- **Bước/assertion:** (1) Login → màn hoàn thiện hồ sơ, Home không truy cập được. (2) Bỏ tên hoặc avatar rồi Save → giữ màn, trường thiếu được báo rõ, không có thành công. (3) Thử Back/nút đóng và mở lại app khi chưa hoàn tất → vẫn không vào luồng Home. (4) Nhập tên hợp lệ và chọn avatar → API nhận các field đã duyệt, hồ sơ tải lại có tên/avatar và vào Home. (5) Logout/login lại → không bị hỏi hoàn thiện lại.
- **Nguồn kỹ thuật/điểm cần xác nhận:** [LoginView điều hướng theo profileCompleted](../../lib/features/auth/view/login_view.dart#L163), [EditProfileView](../../lib/features/profile/view/edit_profile_view.dart#L110). Cách server xác định avatar hợp lệ là contract cần owner xác nhận.
- **Dọn dẹp/evidence:** giữ tài khoản test theo chính sách reset; ghi screenshot từng bước, request/response đã che bí mật và kết quả sau relaunch.

### AUTH-03 — access token hết hạn, refresh invalid và lỗi mạng

- **Mức/owner/loại/trạng thái:** P0 · Như · API + UI + mạng · `NOT RUN`.
- **Expected:** README xác nhận app hỗ trợ refresh token. Contract owner phải xác nhận response refresh hợp lệ/không hợp lệ và kỳ vọng lỗi mạng. Mã hiện tại dự kiến retry request gốc một lần sau refresh; network failure được xem là lỗi có thể retry, nhưng code này chỉ là mục tiêu quan sát, chưa phải chuẩn đã nghiệm thu.
- **Điều kiện/dữ liệu:** tài khoản backend test; cách cấp access token hết hạn, refresh hợp lệ/thu hồi, và proxy có thể ngắt refresh riêng. Không dùng token production.
- **Bước/assertion:** (1) Gửi request protected với access hết hạn + refresh hợp lệ → đúng một refresh; request gốc được retry với token mới và chỉ trả một kết quả UI. (2) Lặp với refresh bị thu hồi → không retry lặp vô hạn, app về Login, local session/cache user-feed bị xoá theo contract. (3) Lặp với refresh bị timeout/mất mạng → quan sát phiên giữ hay kết thúc đúng expected đã chốt; khi mạng hồi phục, thao tác retry không bị nhân đôi.
- **Nguồn kỹ thuật:** [AuthInterceptor](../../lib/core/network/auth_interceptor.dart#L52) và [AuthCubit](../../lib/features/auth/cubit/auth_cubit.dart#L39). Server semantics và việc giữ phiên khi lỗi mạng cần confirmed contract.
- **Dọn dẹp/evidence:** revoke/reset token QA theo backend; log số request và thứ tự status, che header/body token; lưu video điều hướng.

### AUTH-04 — logout xoá phiên và cache dù server lỗi

- **Mức/owner/loại/trạng thái:** P0 · Như · API + UI + storage · `NOT RUN`.
- **Expected:** [AuthRepository logout](../../lib/data/repositories/auth_repository.dart#L58) hiện thiết kế luôn clear local session/cache khi server lỗi; README xác nhận logout là chức năng. Dùng product requirement/owner xác nhận việc giữ `device_id` và dữ liệu nào được xoá; không suy rộng “clear cache” thành xoá mọi cài đặt.
- **Điều kiện/dữ liệu:** tài khoản QA login, Home/Profile đã có dữ liệu cache; backend test có thể trả 5xx hoặc proxy ngắt request logout.
- **Bước/assertion:** (1) Khi mạng tốt, logout → về Login; token không còn, cached user/feed không còn. (2) Khởi tạo lại cùng fixture nhưng làm logout trả 503 → UI vẫn về Login, session/cache user/feed vẫn bị xoá cục bộ. (3) Tắt mạng rồi logout → cùng kết quả local; mở lại app không tự vào phiên cũ. (4) Login lại và kiểm tra không thấy cache của phiên trước.
- **Nguồn kỹ thuật:** [AuthRepository](../../lib/data/repositories/auth_repository.dart#L58), [LocalStorage](../../lib/core/storage/local_storage.dart#L66).
- **Dọn dẹp/evidence:** dừng proxy fault, logout phiên mới; ghi cache trước/sau bằng UI/log test an toàn, không trích token.

### AUTH-05 — đổi A sang B không rò dữ liệu và nhớ đúng tài khoản

- **Mức/owner/loại/trạng thái:** P0 · Như · E2E hai tài khoản + storage · `NOT RUN`.
- **Expected:** [README](../../README.md#phạm-vi) có lưu tài khoản và cache theo user; khi B đăng nhập không được trình bày dữ liệu cá nhân của A như dữ liệu B. Chính sách chỉ giữ một hay nhiều saved account phải được owner chốt; hiện UI/repo có một saved account, đó là quan sát mã chứ không tự coi là yêu cầu.
- **Điều kiện/dữ liệu:** hai tài khoản QA A/B, fixture riêng (profile/feed A và B dễ nhận biết), một thiết bị test riêng không dùng production; bắt đầu với app data reset được.
- **Bước/assertion:** (1) Login A, bật ghi nhớ; đợi profile/feed A tải và xác nhận marker A trên Home. (2) Logout, login B với ghi nhớ bật → trước khi response B đến không được render nội dung A như dữ liệu B; sau khi load chỉ marker B xuất hiện. (3) Logout/restart, dùng quick login → email hiển thị và user tải là B theo chính sách đã chốt. (4) Lặp login B với ghi nhớ tắt → không còn quick-login credential sau logout; mở lại app không hiện password/tài khoản cũ. (5) Thử flow B đổi password khi saved credential đang thuộc B và kiểm tra chỉ entry hợp lệ cập nhật; trường hợp A còn lưu phải được xử lý theo policy trước khi đánh giá.
- **Nguồn kỹ thuật/contract cần rõ:** [LoginView lưu/forget account](../../lib/features/auth/view/login_view.dart#L163), [UserRepository cache profile](../../lib/data/repositories/user_repository.dart#L16), [logout storage](../../lib/data/repositories/auth_repository.dart#L71). Cô lập cache theo account là expected riêng cần xác nhận.
- **Dọn dẹp/evidence:** logout, forget account, clear fixture/cache qua app test; ảnh A/B với marker giả, log không có credential.

### AUTH-06 — đổi mật khẩu, biên và xác nhận

- **Mức/owner/loại/trạng thái:** P1 · Như · UI + API · `NOT RUN`.
- **Expected:** [README](../../README.md#quy-tắc-nghiệp-vụ-phải-giữ) quy định mật khẩu mới 6–32 ký tự, chỉ chữ/số; xác nhận phải khớp và lỗi server không được báo thành công. Expected của password cũ sai/status cần contract backend.
- **Điều kiện/dữ liệu:** tài khoản disposable/test có thể reset; API test; bộ chuỗi gồm chữ/số ASCII. Không ghi mật khẩu vào evidence; chỉ ghi nhãn `p5`, `p6`, `p32`, `p33`.
- **Bước/assertion:** (1) Submit mật khẩu mới 5 ký tự → lỗi, không có POST change-password. (2) 6 và 32 ký tự chữ/số, confirm khớp, mật khẩu khác hiện tại → form cho gửi; backend thành công thì báo thành công và account đăng nhập được bằng password mới. (3) 33 ký tự, có dấu cách/ký tự đặc biệt, confirm lệch hoặc bằng mật khẩu cũ → bị chặn tại UI, không gọi API. (4) Nhập password cũ sai với password mới hợp lệ → API lỗi theo contract; không báo thành công, không cập nhật saved credential; password cũ vẫn hoạt động. (5) Sau đổi thành công, kiểm tra login mới; saved credential chỉ cập nhật theo account đúng.
- **Nguồn kỹ thuật:** [Validators](../../lib/core/utils/validators.dart#L12), [ChangePasswordView](../../lib/features/profile/view/change_password_view.dart#L40), [AuthRepository](../../lib/data/repositories/auth_repository.dart#L77). UI code giúp tìm điểm assert, README là rule oracle.
- **Dọn dẹp/evidence:** dùng tài khoản có thể reset; trả password về trạng thái ban đầu qua flow được cấp; giữ nhãn case thay vì giá trị bí mật.

## 2. Hồ sơ

### PROF-01 — sửa, gỡ ảnh, cancel và API lỗi

- **Mức/owner/loại/trạng thái:** P1 · Như · UI + API + restart · `NOT RUN`.
- **Expected:** README xác nhận profile edit/avatar/cover; chính sách field nào được lưu và gỡ ảnh cần API contract. Một lần chỉ sửa tên/bio không được vô tình gửi URL ảnh; UI hiện có đường gửi chuỗi rỗng để gỡ, cần xác nhận backend support.
- **Điều kiện/dữ liệu:** tài khoản test với tên, bio, avatar, cover đã biết; ảnh QA hợp lệ; fault injection API test nếu cần kiểm lỗi.
- **Bước/assertion:** (1) Mở Edit rồi Cancel/Back → profile và API không đổi. (2) Chỉ sửa tên/bio, Save → response/reopen có giá trị mới; request không gửi avatar_url/cover_url. (3) Gỡ avatar, Save → chỉ avatar bị gỡ; cover giữ nguyên; restart vẫn vậy. (4) Lặp với cover; mỗi lần field còn lại không bị xoá. (5) Cho PUT profile lỗi → thông báo lỗi, màn không báo success, server và UI sau reload giữ giá trị cũ. (6) Nếu server bỏ qua empty URL, UI báo rõ và không giả vờ đã gỡ.
- **Nguồn kỹ thuật:** [EditProfileView](../../lib/features/profile/view/edit_profile_view.dart#L84), [UserRepository update body](../../lib/data/repositories/user_repository.dart#L46), test hiện có [remove_photos_test](../../test/features/remove_photos_test.dart#L96). Requirement/contract lưu field là oracle.
- **Dọn dẹp/evidence:** khôi phục tên/ảnh ban đầu nếu được phép; lưu payload đã loại token, ảnh trước/sau, response và kết quả sau relaunch.

## 3. Bảng tin và phân trang

### PAGE-01 — cursor, append, trang cuối và chặn request trùng

- **Mức/owner/loại/trạng thái:** P1 · Như · API + UI + network log · `NOT RUN`.
- **Expected:** [README phân trang](../../README.md#giới-hạn-của-backend-đã-kiểm-chứng-cần-backend-bổ-sung) dùng cursor `after`; yêu cầu không gửi trùng request đang chạy có trong matrix.
- **Điều kiện/dữ liệu:** backend test feed với ít nhất 2 trang biết ID/mốc thời gian; proxy log request/cursor; kết nối tốt.
- **Bước/assertion:** (1) Mở Home → trang đầu hiển thị; request `GET /activity-feeds` không có cursor (theo contract). (2) Cuộn sát cuối → trang tiếp dùng `after` trả về từ trang trước; item mới được append đúng thứ tự theo API contract. (3) Gây delay trang 2, cuộn nhiều lần → chỉ một request cho cùng cursor khi request còn chạy. (4) Tới trang `has_next=false`/hết dữ liệu → không tiếp tục gọi và UI không lặp item ngoài trường hợp feed contract cho phép.
- **Nguồn kỹ thuật:** [FeedRepository](../../lib/data/repositories/feed_repository.dart#L31), [HomeTab dùng PagedCubit](../../lib/features/home/home_tab.dart#L37), [PagedCubit](../../lib/core/bloc/paged_cubit.dart#L80), [bộ test component](../../test/core/paged_cubit_test.dart#L9). Dữ liệu/ordering cụ thể cần fixture backend.
- **Dọn dẹp/evidence:** không tạo dữ liệu; log method/path/cursor đã bỏ token, ảnh/video cuộn và ID từng trang.

### PAGE-02 — load more lỗi, retry và mã hết dữ liệu

- **Mức/owner/loại/trạng thái:** P1 · Như · API + UI + fault injection · `NOT RUN`.
- **Expected:** matrix yêu cầu lỗi load-more giữ items/cursor để retry; code backend dùng `9994` cho hết dữ liệu theo README response behavior. Confirm backend test dùng đúng contract/code.
- **Điều kiện/dữ liệu:** Home có ít nhất trang đầu và trang kế; proxy/backend test cho lỗi tạm thời rồi phục hồi, và fixture trang cuối/9994.
- **Bước/assertion:** (1) Tải trang đầu, ghi IDs. (2) Làm request kế tiếp timeout/5xx → trang đầu vẫn hiện, không duplicate/loss, có affordance lỗi/retry nếu contract UI yêu cầu. (3) Phục hồi mạng và retry → cùng cursor được gửi lại, trang 2 xuất hiện đúng một lần. (4) Tiếp tục tới `9994`/terminal page → tải dừng, item trước còn nguyên, không spinner vô hạn/crash. (5) Cuộn thêm → không request tiếp sau terminal.
- **Nguồn kỹ thuật:** [PagedCubit error paths](../../lib/core/bloc/paged_cubit.dart#L99), [ApiException no-more-data](../../lib/core/network/api_exception.dart#L40), [README response/paging](../../README.md#giới-hạn-của-backend-đã-kiểm-chứng-cần-backend-bổ-sung). Mã server cần xác nhận.
- **Dọn dẹp/evidence:** khôi phục proxy; lưu request sequence, cursor, IDs trước/sau và video không ghi thông tin tài khoản.

### PAGE-03 — cache trang đầu, refresh success/failure và empty state

- **Mức/owner/loại/trạng thái:** P1 · Như · UI + API + offline/restart · `NOT RUN`.
- **Expected:** [README](../../README.md#quy-tắc-nghiệp-vụ-phải-giữ) yêu cầu cache trang đầu để Home có nội dung khi mở app. Với lỗi refresh, giữ dữ liệu hiện có là target ở matrix; empty state chỉ khi response thành công rỗng.
- **Điều kiện/dữ liệu:** backend test có feed nhận biết; tài khoản QA riêng; khả năng tắt mạng và response rỗng/refresh fail.
- **Bước/assertion:** (1) Online tải feed A thành công, force-close/reopen offline → A xuất hiện ngay từ cache. (2) Pull-to-refresh khi offline → A vẫn giữ, báo trạng thái lỗi phù hợp, không bị thay bằng empty. (3) Online trả feed B → refresh thay danh sách theo trang đầu mới và cache sau restart là B. (4) Fixture thành công rỗng → empty view; không nhầm lỗi mạng/9994 với empty ngoài contract.
- **Nguồn kỹ thuật:** [FeedRepository cache](../../lib/data/repositories/feed_repository.dart#L20), [HomeTab khởi tạo từ cache](../../lib/features/home/home_tab.dart#L37), [PagedCubit refresh](../../lib/core/bloc/paged_cubit.dart#L93). Retry/error UI observable theo contract đã bàn giao.
- **Dọn dẹp/evidence:** khôi phục mạng; ghi fixture IDs, thời gian cold/warm open, ảnh cache và response refresh đã che dữ liệu.

## 4. Bài viết và quyền xem

### POST-01 — nội dung biên, số ảnh và đồng bộ feed/profile

- **Mức/owner/loại/trạng thái:** P1 · Quốc Anh · UI + API + E2E · `NOT RUN`.
- **Expected:** README: tối đa 500 từ/bài, tối đa 4 ảnh, nội dung/ảnh hợp lệ đăng được. `0` ảnh hợp lệ khi có text; thử riêng ảnh-only nếu product owner xác nhận API cho phép content rỗng.
- **Điều kiện/dữ liệu:** user A test; content generator thành 499/500/501 token cách nhau bằng whitespace; 5 ảnh giả QA được chọn nhanh; từng ảnh <=4 MiB; Home và profile A có thể refresh.
- **Bước/assertion:** (1) 499 từ + 0 ảnh → nút đăng hoạt động, POST thành công. (2) 500 từ + 1 ảnh → thành công; body ghi đúng content/visibility/media count theo contract. (3) 501 từ → UI chặn và không gọi create-post endpoint. (4) 0, 1, 4 ảnh với content hợp lệ → post lưu đúng số ảnh. (5) Chọn 5 ảnh → không upload/lưu quá 4; UI cho biết giới hạn hoặc cách cắt lựa chọn theo design đã duyệt. (6) Sau mỗi post thành công, marker xuất hiện một lần trên Home và profile A sau reload.
- **Nguồn kỹ thuật:** [README business rules](../../README.md#quy-tắc-nghiệp-vụ-phải-giữ), [CreatePostView limits/submit](../../lib/features/post/create_post_view.dart#L60), [PostRepository.create](../../lib/data/repositories/post_repository.dart#L18). Code locator, requirement là expected.
- **Dọn dẹp/evidence:** xoá các bài do A tạo, xác nhận không còn sau refresh; lưu labels word-count/image-count, IDs, request payload không chứa bí mật.

### POST-02 — PUBLIC / FRIENDS / ONLY_ME qua feed và truy cập trực tiếp

- **Mức/owner/loại/trạng thái:** P0 · Quốc Anh · API + E2E hai thiết bị/tài khoản · `NOT RUN`.
- **Expected:** README xác nhận ba visibility `PUBLIC`, `FRIENDS`, `ONLY_ME`. Contract phải xác nhận ai được xem FRIENDS, cách xử lý blocked, status/body khi bị từ chối; không giả định HTTP 403 hay 404.
- **Điều kiện/dữ liệu:** backend test; A là tác giả, B là bạn của A, C là người không phải bạn; 3 phiên được phép, mỗi post có ID/text marker riêng. Nếu chỉ cấp 2 account, test PUBLIC/ONLY_ME và giữ FRIENDS ngoài phạm vi đến khi có role cần.
- **Bước/assertion:** (1) A tạo PUBLIC → A/B/C thấy marker trong feed/profile theo contract và đọc trực tiếp theo ID được phép. (2) A tạo FRIENDS → A và B thấy; C không nhận nội dung qua feed hay endpoint đọc trực tiếp. (3) A tạo ONLY_ME → A thấy; B/C không nhận nội dung qua feed hoặc API. (4) Reload/relogin B/C → visibility không bị lộ do cache. (5) So sánh response rejection với contract đã confirmed, chỉ ghi “không có nội dung” khi body thật đã kiểm tra.
- **Nguồn kỹ thuật/contract:** [README visibility](../../README.md#giới-hạn-của-backend-đã-kiểm-chứng-cần-backend-bổ-sung); endpoints hiện được khai báo ở [ApiEndpoints posts](../../lib/core/network/api_endpoints.dart#L21), repository [getById](../../lib/data/repositories/post_repository.dart#L37). Endpoint/semantics access phải xác nhận với owner/backend.
- **Dọn dẹp/evidence:** A xoá ba bài; ghi account role labels không ghi emails, post IDs, screenshots của từng viewer và response bodies đã che token.

### POST-03 — xoá, huỷ xác nhận và ẩn bài đã xoá

- **Mức/owner/loại/trạng thái:** P1 · Quốc Anh · UI + API + refresh/restart · `NOT RUN`.
- **Expected:** README nêu backend soft-delete có thể để ghost trong feed và app tự ẩn; delete UI thuộc bài của mình. Status của bài đã xoá khi gọi trực tiếp phải theo contract, không bắt buộc 404 nếu soft-delete dùng status khác.
- **Điều kiện/dữ liệu:** A có một post duy nhất; B có phiên riêng; marker và ID nhận biết; backend test hỗ trợ owner authorization.
- **Bước/assertion:** (1) A tạo hai bài riêng P1/P2. B thử xoá P2 khi P2 vẫn còn trên server bằng request/flow được contract cho phép → server từ chối theo contract; sau đó A vẫn đọc được P2 qua feed/direct read. B UI phải phản ánh response đúng contract; 404 không mặc định nghĩa là bài đã bị xoá toàn cục. Không đặt negative attempt sau khi A đã xoá P2. (2) A mở menu P1, chọn Cancel → P1 còn trong feed/profile và không có DELETE. (3) A confirm xoá P1 → P1 biến khỏi list; response/UI phù hợp. (4) Refresh Home/profile, thoát/mở lại → P1 không hiện lại theo requirement local hiding. (5) Trigger lỗi server không phải “đã không tồn tại” cho thao tác xoá của A → UI không báo success, và post còn lại không bị đánh dấu xoá local.
- **Nguồn kỹ thuật:** [README soft delete](../../README.md#giới-hạn-của-backend-đã-kiểm-chứng-cần-backend-bổ-sung), [PostCard confirm/delete](../../lib/shared/post/post_card.dart#L142), [PostRepository.delete](../../lib/data/repositories/post_repository.dart#L59), [FeedRepository ghost filtering](../../lib/data/repositories/feed_repository.dart#L51).
- **Dọn dẹp/evidence:** nếu huỷ case trước delete, giữ post; sau delete xác nhận đã ẩn và ghi ID/response/refresh evidence; không xoá bài của người khác.

## 5. Like và bình luận

### REACT-01 — Like/unlike, count, rollback và đồng bộ

- **Mức/owner/loại/trạng thái:** P1 · Quốc Anh · UI + API + fault injection · `NOT RUN`.
- **Expected:** README quy định chỉ một cảm xúc LIKE, bấm lại để gỡ; lỗi optimistic action phải hoàn tác state/count theo kiến trúc app. Xác nhận với owner quy ước totalCount/reacted trong response.
- **Điều kiện/dữ liệu:** post test công khai từ A, viewer B; số like ban đầu biết được; hai màn hình session B hoặc reload; proxy/backend fault để trả lỗi một request.
- **Bước/assertion:** (1) B bấm Like chưa react → icon/state thành reacted, count +1; backend ghi đúng một LIKE. (2) B bấm lại → bỏ react, count trở baseline; không tạo loại cảm xúc thứ hai. (3) Trigger API error khi toggle → UI quay về đúng state và count trước thao tác, có lỗi rõ. (4) Reload/mở post ở màn liên quan → server state cuối cùng khớp UI, không đếm trùng.
- **Nguồn kỹ thuật:** [README Like](../../README.md#quy-tắc-nghiệp-vụ-phải-giữ), [PostCard optimistic logic](../../lib/shared/post/post_card.dart#L88), [ReactionRepository endpoint](../../lib/data/repositories/reaction_repository.dart#L7). Không dùng phản hồi mock làm bằng chứng server.
- **Dọn dẹp/evidence:** bỏ Like test còn sót; ghi count trước/sau, reaction history nếu backend cho phép, video và fault profile đã dùng.

### COMM-01 — giới hạn 500 từ và quyền xoá bình luận

- **Mức/owner/loại/trạng thái:** P0 · Quốc Anh · UI + API hai tài khoản · `NOT RUN`.
- **Expected:** [README](../../README.md#quy-tắc-nghiệp-vụ-phải-giữ): comment tối đa 500 từ, không sửa; chỉ chủ comment được xoá. Xác nhận access/error contract của API khi người khác thử xoá.
- **Điều kiện/dữ liệu:** bài A; A là chủ bài, B là người viết comment; generator 499/500/501 từ; có endpoint/log API test và hai phiên.
- **Bước/assertion:** (1) B gửi 499 rồi 500 từ → mỗi comment được lưu đúng một lần và hiển thị đầy đủ. (2) Submit 501 từ → báo giới hạn, không có POST mới. (3) Mở menu comment của B → không có chức năng sửa; API surface/contract không cung cấp edit nếu contract xác nhận không hỗ trợ. (4) A thử xoá comment do B viết qua UI và endpoint được xác nhận → không xoá được, B vẫn thấy; body/status phải đúng contract. (5) B xoá comment của mình và xác nhận → biến khỏi danh sách sau reload; count cập nhật chính xác. (6) B thử huỷ xác nhận xoá → comment còn nguyên, không gửi DELETE.
- **Nguồn kỹ thuật:** [CommentRepository rules](../../lib/data/repositories/comment_repository.dart#L7), [CommentsSheet limit/delete](../../lib/shared/comment/comments_sheet.dart#L89), [CommentsCubit actions](../../lib/shared/comment/comments_cubit.dart#L224). Không gọi route edit tự suy đoán; xác nhận contract trước direct API attempt.
- **Dọn dẹp/evidence:** xoá các comment test do chính B tạo nếu policy cho phép; lưu marker/ID, request count, response đã che bí mật và ảnh menu.

## 6. Media

### MEDIA-01 — biên 4 MiB và GIF bị chặn trước upload

- **Mức/owner/loại/trạng thái:** P1 · Quốc Anh · UI + API thật · `NOT RUN`.
- **Expected:** README quy định ảnh không quá 4 MiB và không nhận GIF. MiB chính xác là 4,194,304 bytes. Server có thể có validation riêng; contract/status cần xác nhận.
- **Điều kiện/dữ liệu:** backend test upload, tài khoản QA; file hợp lệ được xác nhận byte length và GIF `x.gif`/`x.GIF`. ImagePicker có thể resize/reencode, nên kích thước file được chọn ban đầu không chứng minh kích thước file đi vào MediaRepository.
- **Bước/assertion:** (1) **UI picker:** chọn ảnh gần biên; đo/ghi byte length của chính file sau ImagePicker và trước upload bằng harness/breakpoint QA đã duyệt. Chỉ assert client accept/reject theo kích thước đo được; nếu không thể quan sát file hiệu dụng hoặc không tạo được đúng biên thì subcase `BLOCKED`, không kết luận từ file đầu vào. (2) **Repository boundary:** với file runtime 4,194,304 bytes gọi MediaRepository → request helper được gọi; với 4,194,305 bytes và `.gif`/`.GIF` → ApiClient không bị gọi. Subcase này là component/helper check, blocked đến khi Dart harness chạy; mock không chứng minh backend. (3) **Backend upload riêng:** POSTMAN/API test gửi payload có byte length đã đo, gồm đúng 4,194,304 và 4,194,305 → ghi status/body/side effects theo contract; kết quả này chỉ nghiệm thu server, không chứng minh UI client đã chặn.
- **Nguồn kỹ thuật:** [README limits](../../README.md#quy-tắc-nghiệp-vụ-phải-giữ), [ComponentTokens](../../lib/core/design_system/component_tokens.dart#L43), [ImagePicker transform](../../lib/features/post/create_post_view.dart#L65), [MediaRepository boundary](../../lib/data/repositories/media_repository.dart#L37), [test helper hiện có](../../test/data/media_validation_test.dart#L49). Test helper fake không chứng minh upload thật.
- **Dọn dẹp/evidence:** xoá media test qua backend owner/tool được phép; giữ filename, input và effective byte length riêng, response metadata, log request đã che token. Không ghi “4 MiB UI pass” nếu chỉ file gốc 4 MiB được chọn.

### MEDIA-02 — quyền camera/gallery, huỷ picker và upload timeout

- **Mức/owner/loại/trạng thái:** P1 · Quốc Anh · thiết bị thật + API/mạng · `NOT RUN`.
- **Expected:** matrix yêu cầu không crash khi từ chối permission, huỷ chọn, timeout; nội dung/thông báo/retry phải được xác nhận theo UX requirement và platform. Không suy ra quy tắc quyền Android/iOS chỉ từ thiết bị khác.
- **Điều kiện/dữ liệu:** build thật trên ít nhất một Android và một iPhone nếu release bao gồm cả hai; quyền app reset được; backend test/proxy timeout; ảnh QA không chứa dữ liệu cá nhân.
- **Bước/assertion:** (1) Từ chối quyền gallery rồi bấm thêm ảnh → app không crash, không tạo post/upload, hướng dẫn tương ứng OS. (2) Từ chối quyền camera rồi chụp → cùng assertion. (3) Mở picker rồi Cancel → composer giữ nguyên, không tăng ảnh và không upload. (4) Cho quyền, chọn ảnh rồi làm upload timeout → không báo thành công/đăng bài; thông báo và retry theo UX đã chốt, không upload trùng sau retry. (5) Thu hồi permission từ Settings rồi quay lại app → không crash, UI phản ánh lỗi quyền và hoạt động khác còn responsive.
- **Nguồn kỹ thuật:** [image picker error handling](../../lib/features/post/create_post_view.dart#L65), [media upload](../../lib/data/repositories/media_repository.dart#L79), [README platform](../../README.md#quy-tắc-nghiệp-vụ-phải-giữ). Product owner cần xác nhận copy/error retry.
- **Dọn dẹp/evidence:** reset quyền về trạng thái ban đầu; xóa orphan upload nếu API đã nhận; video màn hình, OS version/permission state, request trace và thời gian timeout.

## 7. Bạn bè, theo dõi, chặn và tìm người

### REL-01 — friendship cùng vai trò, requests, follow khác vai trò

- **Mức/owner/loại/trạng thái:** P1 · Quốc Anh · UI + API ít nhất ba role/user fixture · `NOT RUN`.
- **Expected:** [README](../../README.md#quy-tắc-nghiệp-vụ-phải-giữ) xác nhận chỉ kết bạn cùng vai trò, follow không phân biệt; response trạng thái và thao tác cancel pending cần owner/backend contract.
- **Điều kiện/dữ liệu:** A là Student; B là Student; C là Lecturer; các tài khoản test thuộc owner/được cấp. Biết trạng thái ban đầu và request IDs. Không tạo request cho user thật.
- **Bước/assertion:** (1) A mở B → có hành động kết bạn; gửi request → A thấy pending, B thấy incoming. (2) B accept → cả hai thấy friend sau refresh. (3) Dùng cặp Student khác, recipient decline → không thành friend, request biến khỏi hai phía theo contract. (4) Test cancel outgoing request theo khả năng sản phẩm; UI source hiện chưa có nút cancel, nên chốt API/UX với owner trước; nếu không có capability giữ subcase `BLOCKED`. (5) Tìm user bằng tên riêng, mã SV/GV đầy đủ, và email trường đầy đủ → mỗi query chỉ trả đúng user ID khớp theo contract; email mode tối đa một kết quả. Một query không tồn tại → empty state, không trả user gần giống ngoài expected. (6) Với query tên/mã có nhiều trang, cuộn tiếp → gửi offset `after` từ search page, append đúng trang, không dùng cursor feed; email query không load-more. (7) A mở C khác role → UI không có add-friend action, có giải thích; follow bật/tắt vẫn được. Chỉ thử direct API cross-role khi contract/policy test đã xác nhận, không tự giả định HTTP status.
- **Nguồn kỹ thuật:** [README role/search scope](../../README.md#quy-tắc-nghiệp-vụ-phải-giữ), [FriendRepository routes](../../lib/data/repositories/friend_repository.dart#L61), [FriendActions UI](../../lib/features/profile/widgets/friend_actions.dart#L70), [UserSearchRepository name/code/email + offset](../../lib/data/repositories/user_search_repository.dart#L26), [UserSearchCubit paging](../../lib/features/friends/cubit/user_search_cubit.dart#L109), test helper existing [friends_test](../../test/data/friends_test.dart#L434). README/backend contract phân biệt tên/mã được backend search và full-email app-side mapping; nếu email scheme không thuộc fixture thì giữ subcase `BLOCKED`.
- **Dọn dẹp/evidence:** accept/decline/unfriend các fixture theo owner; bỏ follows nếu chính sách cho; log user IDs giả/role, statuses và request payload đã che dữ liệu cá nhân.

### REL-02 — block/unblock hai chiều và ảnh hưởng tương tác

- **Mức/owner/loại/trạng thái:** P0 · Quốc Anh · API + UI hai tài khoản; một phần chờ contract · `NOT RUN`.
- **Expected:** Matrix yêu cầu test cả hai phía; README có block/unblock nhưng không mô tả đầy đủ quyền truy cập sau block. Trước khi assert feed/profile/comment/follow, owner phải chốt semantics, cách xem block list và liệu unblock có tự phục hồi friendship/follow không.
- **Điều kiện/dữ liệu:** A/B test; ban đầu friend + follow hai chiều; posts riêng có marker; owner xác nhận endpoint/policy, thứ tự block, side effects và cleanup.
- **Bước/assertion:** (1) A block B qua UI → dialog nêu consequence đúng requirement; request hoàn tất và UI không còn friend/follow theo contract. (2) B làm mới profile/feed của A và thử đọc/tương tác trực tiếp → không lộ/không cho phép đúng policy đã chốt. (3) Lặp block từ B sang A nếu contract quy định cùng kết quả hai chiều. (4) Unblock qua UI/API đã duyệt → trạng thái block mất; không assert friendship/follow tự bật lại nếu owner chưa xác nhận. (5) Sau relaunch, block list và mọi luồng quyền vẫn nhất quán.
- **Nguồn kỹ thuật:** [README scope](../../README.md#phạm-vi), [FriendRepository block endpoints](../../lib/data/repositories/friend_repository.dart#L94), [FriendActions dialog](../../lib/features/profile/widgets/friend_actions.dart#L236), [FriendRepository tests](../../test/data/friends_test.dart#L495). Mô tả trong code/UI là observation, không thay contract.
- **Dọn dẹp/evidence:** unblock A/B, restore friendship/follow chỉ theo policy; xác nhận trạng thái cuối cùng cả hai account, lưu request/response đã che token và screenshot.

## 8. Sáu ID chờ bàn giao

Các ID sau hiện là `WAITING` trong matrix. Chỉ đổi sang `NOT RUN` khi có code/build tích hợp,
acceptance criteria được duyệt, test host/fixture và expected response. Đây là câu hỏi
để chốt trước; chưa phải bộ test chi tiết hoặc API spec.

| ID / owner | Draft phạm vi acceptance | Cần chốt với owner / prerequisite |
|---|---|---|
| QUESTION-01 · Dũng | Tạo submission, duplicate question, moderation/approval, answer và rating; xác nhận feed cập nhật sau trạng thái được duyệt. | Vai trò được tạo/duyệt; định nghĩa câu trùng; trạng thái, ai được trả lời/rate, range rating và cách sửa/xoá; fixture subject/session. Routes chỉ được khai báo tại [ApiEndpoints](../../lib/core/network/api_endpoints.dart#L64), chưa đủ xác nhận behavior. |
| EXAM-01 · Dũng | Sinh đề từ nguồn đã chọn; mở danh sách/detail và export; xác nhận quyền sở hữu và kết quả export. | Tham số bắt buộc, số câu/subject/range; đồng bộ hay async; file format/size; quyền tải/xoá; dữ liệu test. Route declarations [exam](../../lib/core/network/api_endpoints.dart#L80) không xác định schema. |
| CHAT-01 · Quốc Anh | Send/receive/read/delete qua hai user; thử reconnect, duplicate/lost message, block behavior. | WebSocket URL/auth/protocol, ordering/delivery guarantee, retry/idempotency, receipts, delete semantics, block policy và test account/device; chưa có client implementation. |
| PUSH-01 · Nam | Permission, device token registration/unregistration, foreground/background/terminated delivery và deep link. | FCM project/test credentials qua kênh bảo mật, payload contract, token refresh, denied-permission behavior, supported OS/devices; endpoint declarations [devices/settings](../../lib/core/network/api_endpoints.dart#L54) không chứng minh push integration. |
| SEARCH-01 · Nam | Search nội dung câu hỏi/bài, pagination/history/saved search; xác nhận refresh và quyền riêng tư kết quả. | Searchable entity/fields, ranking, offset/cursor, history retention/delete, saved search API schema, private content filtering; không trùng REL-01 search người dùng đã có. |
| ADV-01 · Dũng | Khi AI/gamification/badges/cosmetics được tích hợp: kiểm tra action tạo reward, leaderboard, inventory/badge và consistency sau reload. | Tính năng nào thuộc release; rules/eligibility, idempotency, ranking tie-break, reward ledger, AI fallback/quota/privacy; endpoints được khai báo trong [ApiEndpoints](../../lib/core/network/api_endpoints.dart#L86) nhưng chưa phải scope đã nghiệm thu. |

## Phiếu ghi kết quả mỗi case

Sao chép phần này vào log phiên chạy; thêm một dòng cho từng ID/subcase, không điền trước
khi chưa chạy:

```text
ID / biến thể:
Trạng thái: NOT RUN | BLOCKED | WAITING | PASS | FAIL
Expected source + ngày/version contract:
SOURCE_SHA / MAIN_SNAPSHOT / TESTED_SHA:
Build / API_BASE_URL / thiết bị-OS / mạng:
Tài khoản test theo vai trò (alias A/B/C, không ghi credentials):
Dữ liệu/ID fixture:
Bước + assertion từng bước:
Actual:
Lệnh hoặc request / exit code / status-body (đã che bí mật):
Evidence path (ảnh/video/log):
Side effects và cleanup đã xác nhận:
Bug ID / owner / retest liên quan:
```

Không carry `PASS` sang source SHA mới sau merge `main`; chạy lại case bị ảnh hưởng và ghi
`TESTED_SHA` chính xác theo [quy trình Git QA](GIT_WORKFLOW.md). Nếu thiếu contract, tài
khoản, backend hay thiết bị thì ghi lý do cụ thể và để `BLOCKED`/`WAITING`; không hạ
requirement để biến case thành pass.
