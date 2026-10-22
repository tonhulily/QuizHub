# Bộ Postman API cho QA

Collection v2.1 chứa 41 request thủ công, dựng từ các endpoint hiện được gọi trong repository Auth, Profile, Posts, Comments, Relations, Feed, Search, Media, Reaction và Report. Đây là bộ thao tác có chọn lọc, không phải runner hay khẳng định contract server.

## Import và cấu hình

1. Trong Postman, import `quizhub-qa.postman_collection.json` và `quizhub-qa.environment.template.json`.
2. Chọn environment, đặt `base_url` thành host API test được cấp. Mặc định `https://example.invalid/api/v1` không trỏ backend.
3. Chỉ điền tài khoản test được cấp vào local values. Token, mật khẩu, user IDs và fixture IDs để trống trong template; không chia sẻ hoặc commit environment đã điền.
4. `[PHIÊN] Đăng nhập A — thủ công, không tự lưu token`; `[PHIÊN] Đăng nhập B — thủ công, không tự lưu token` và refresh chạy thủ công. Chép token/refresh token vào local values bằng tay; collection không tự bắt token.
5. Gửi từng request được chọn. Nhãn `[GHI]`, `[XÓA]`, `[PHIÊN]`, `[TOGGLE]`, `[NGUY CƠ GHI]` báo thao tác có thể đổi dữ liệu hoặc trạng thái tài khoản. Không chạy Collection Runner.

Chỉ dùng credentials/tài khoản test của chính bạn. Hai token A/B phục vụ đối chiếu quyền. Các thao tác gửi/accept/decline lời mời, follow/unfollow, block/unblock, đổi mật khẩu, sửa/xóa bài, reaction và report đều là thao tác server-side; kiểm tra fixture, host, vai trò và tác động trước khi gửi. B thử xóa bài/comment của A là ca âm tính có nguy cơ ghi nếu backend sai quyền; dùng dữ liệu disposable và kiểm tra lại bằng A sau request.

## JSON body và dữ liệu có ký tự đặc biệt

`post_content_json` và `comment_content_json` là **JSON string literal đã encode**, ví dụ văn bản `A "quote"`, xuống dòng, rồi dấu `\` phải được lưu dưới dạng JSON token có escape. Hai request dùng biến không có dấu nháy bao quanh: `"content": {{post_content_json}}`. Không dán văn bản thô vào biến đó. Có thể encode một file fixture UTF-8 tùy chọn bằng Python chuẩn, rồi chép output vào local value tương ứng:

```bash
python3 -c 'import json,sys; print(json.dumps(sys.stdin.read(), ensure_ascii=False))' < /path/to/post-content.txt
```

Lệnh đọc nguyên file, giữ nguyên newline và ký tự; output có thể gồm dấu nháy JSON bao ngoài, đó là chủ ý. Không lưu token/mật khẩu trong fixture này. `profile_update_body` và `post_update_body` là toàn bộ JSON object hợp lệ, không phải giá trị chuỗi; encode các field text theo quy tắc JSON. Login body đang dùng raw variable bên trong dấu nháy. Email/device values thông thường là chuỗi đơn giản; nếu password hoặc giá trị local có dấu nháy, dấu gạch chéo ngược hay ký tự điều khiển thì phải JSON-escape trước khi thay vào body, hoặc dùng credential hợp lệ chỉ gồm ký tự được client cho phép. Không gửi body lỗi định dạng.

## Postman và media

Với request upload, chọn file bằng nút chọn file trong UI Postman cho form-data `file`; không dựa vào interpolation của biến đường dẫn `src`. `purpose` lấy từ enum trong repository. Không thêm header `Content-Type` thủ công: Postman dựng multipart boundary. Collection chỉ ghi fixture path rỗng để người chạy chọn file tại thời điểm gửi.

Có thể chạy self-check cấu trúc offline bằng Python chuẩn: `python3 qa/api/test_collection.py`. Test kiểm tra environment/biến và parse body sau khi thay biến mẫu; đây không phải kiểm thử Postman, app hay backend. Chưa xác minh import/chạy trong Postman: Postman không được cài ở môi trường chuẩn bị. JSON được kiểm tra bằng Python stdlib, không có collection scripts, token automation hoặc request backend trong quá trình tạo tài liệu.

## Traceability với `QA.md`

| QA ID | Request hỗ trợ thủ công | Giới hạn của collection |
|---|---|---|
| AUTH-01 | `[PHIÊN] Đăng nhập A — thủ công, không tự lưu token`; `[PHIÊN] Đăng nhập B — thủ công, không tự lưu token` | Không kiểm tra validate trước API hoặc UI; login chỉ thử body/API. |
| AUTH-02 | — | Onboarding/tạo tài khoản chưa có request trong repository hiện hành. |
| AUTH-03 | `[PHIÊN] Làm mới token — thủ công` | Không mô phỏng expiry, retry đồng thời hay xóa phiên/cache phía app. |
| AUTH-04 | `[GHI / PHIÊN] Đăng xuất token A` | Không xác minh local token/cache/profile bị xóa khi server lỗi. |
| AUTH-05 | `[PHIÊN] Đăng nhập A — thủ công, không tự lưu token`; `[PHIÊN] Đăng nhập B — thủ công, không tự lưu token`; các request đọc hồ sơ/bài bằng phiên chéo | Không kiểm tra chuyển tài khoản, saved-account hay cô lập cache trên thiết bị. |
| AUTH-06 | `[GHI / AUTH-06] Đổi mật khẩu A` | API shape có; giới hạn 5/6/32/33, confirm lệch và trạng thái saved-account cần UI/client test. |
| PROF-01 | `[ĐỌC] Hồ sơ hiện tại — GET /users/me`; `[GHI] Cập nhật hồ sơ — PUT /users/me` | Không chọn ảnh, gỡ ảnh, cancel picker hoặc kiểm tra UI khi API lỗi. |
| PAGE-01 | `[ĐỌC] Bảng tin — trang đầu`; `[ĐỌC] Bảng tin — trang tiếp`; `[ĐỌC] Danh sách bình luận — trang đầu`; `[ĐỌC] Danh sách bình luận — trang tiếp`; `[ĐỌC] Tìm người dùng — offset tiếp` | Không kiểm tra cuộn, request trùng đồng thời, dừng cuối hoặc giao diện. |
| PAGE-02 | `[ĐỌC] Bảng tin — trang tiếp`; `[ĐỌC] Danh sách bình luận — trang tiếp` | Có thể gửi trang tiếp thủ công; retry giữ dữ liệu/cache cần app test. |
| PAGE-03 | `[ĐỌC] Bảng tin — trang đầu` | Refresh/cache/empty state là hành vi app, không được xác minh bằng collection. |
| POST-01 | `[GHI] Tạo bài — JSON content đã encode`; `[GHI] Tải media — chọn file thủ công` | Không kiểm tra word/ảnh client limits, feed/profile render hoặc picker. |
| POST-02 | `[GHI] Tạo bài — JSON content đã encode`; `[ĐỌC / QUYỀN] A đọc bài của mình`; `[ĐỌC / QUYỀN] B đọc cùng bài`; `[ĐỌC] Bài của user — GET /users/{id}/posts`; `[ĐỌC] Bảng tin — trang đầu` | Kiểm tra quyền qua UI/direct API và expected visibility cần đối chiếu requirement/backend. OpenAPI profile schema còn có email/ngày sinh, khác README dự án; cần chốt privacy filtering. |
| POST-03 | `[GHI / XÓA] A xóa bài test của mình`; `[ÂM TÍNH / NGUY CƠ GHI] B thử xóa bài của A` | Không kiểm tra dialog/hủy xóa, refresh UI hoặc bài ma. |
| REACT-01 | `[GHI / TOGGLE] React LIKE vào bài test` | Request có thể toggle; đồng bộ màn và rollback khi lỗi cần UI/API integration test. |
| COMM-01 | `[GHI] Tạo bình luận — JSON content đã encode`; `[GHI / XÓA] Xóa bình luận của A — token A`; `[ÂM TÍNH / NGUY CƠ GHI] B thử xóa bình luận của A` | Không kiểm tra 500 từ, UI, và không có request sửa comment vì repository không gọi endpoint đó. |
| MEDIA-01 | `[GHI] Tải media — chọn file thủ công` | Request không chạy validator app; 4 MiB/GIF phải kiểm tra qua client test. |
| MEDIA-02 | — | Permission camera/gallery, cancel picker, timeout và thiết bị thật cần kiểm tra runtime. |
| REL-01 | `[GHI] Gửi lời mời — A tới B`; `[ĐỌC] Lời mời đã nhận`; `[ĐỌC] Lời mời đã gửi`; `[GHI] Chấp nhận lời mời từ B`; `[GHI] Từ chối lời mời từ B`; `[GHI / XÓA] Hủy kết bạn với B`; `[GHI] Follow B`; `[GHI / XÓA] Unfollow B`; `[ĐỌC] Tìm người dùng` | Không kiểm tra search email/mã theo UI hay role validation phía client. |
| REL-02 | `[ĐỌC] Danh sách đã chặn`; `[GHI / NGUY CƠ GHI] Block B`; `[GHI / XÓA] Unblock B`; `[ĐỌC / QUYỀN] A đọc bài của mình`; `[ĐỌC / QUYỀN] B đọc cùng bài` | Contract tác động lên feed/profile/tương tác vẫn cần xác nhận. |
| SEARCH-01 | `[ĐỌC] Tìm người dùng`; `[ĐỌC] Tìm người dùng — offset tiếp` | Không có history/saved search trong request hiện hành; chưa bao phủ module đó. |

Các ca `QUESTION`, `EXAM`, `CHAT`, `PUSH`, `ADV` và notification/device runtime không nằm trong toolkit này vì không thuộc các repository endpoint được rà soát. PUT sửa bài chỉ được giữ như request shape của repository; chưa xác nhận UI/feature đã được bàn giao. Hủy kết bạn gửi user_b_id như caller; spec mô tả path ID là ID người bạn, còn runtime vẫn chưa được gọi. Không có request cho followers/following riêng vì repository hiện được đọc không gọi các path đó. API collection cũng không thể thay thế kiểm thử device/session: tự phát hiện device fields, secure/local storage, refresh/retry interceptor, cache khi logout/đổi user, quyền camera/gallery, offline/timeout và UI state cần chạy app trên emulator/thiết bị.

## Đối chiếu OpenAPI (snapshot 21/10/2026)

Lượt GET đọc tài liệu công khai thành công qua TLS: [Swagger UI](https://snsqb.duckdns.org/api/v1/swagger-ui/index.html) trỏ tới [OpenAPI JSON](https://snsqb.duckdns.org/api/v1/docs/openapi.json). Snapshot OpenAPI 3.1.0 có 128 paths; hash và thời điểm retrieval nằm trong metadata local `qa-artifacts/swagger/metadata.json` (artifact bị ignore). Lỗi DNS ở lượt đầu xảy ra trong sandbox, không chứng minh host Swagger bị down.

Đã đối chiếu 41 request trong collection với 33 operation duy nhất: cả 41 verb/path đều có trong spec; mọi query parameter và JSON/multipart field được gửi đều được schema khai báo, không có field/query ngoài schema. Body values và enum đã so với schemas, gồm `visibility`, `post_type`, `target_type`, `reaction_type`, `violation_type`, `platform`, media `purpose`. Đây là đối chiếu tĩnh giữa snapshot và client source; chưa xác minh backend runtime.

Các điểm cần giữ rõ như contract gap:

- OpenAPI khai báo `after` và response `pagination.after` là integer; với post/comment/friend/feed, repository khai báo `String?` và `CursorPage` lưu `String?` (sau đó `J.asString` chuyển giá trị số sang text). Search dùng integer. Request HTTP truyền chuỗi query nên giá trị dạng số có thể tương thích, nhưng opaque/non-numeric cursor không khớp spec. Dùng giá trị số từ spec; xác minh cursor response/runtime trước khi kết luận lỗi. Xem `/components/schemas/CursorPaginationDto/properties/after` và các query `after` của `/posts/me`, `/users/{userId}/posts`, `/comments`, `/friendships`, `/activity-feeds`, `/search`.
- OpenAPI schema `UpdatePostRequest` đánh dấu `visibility` required; `PostRepository.update` chỉ gửi key này khi caller cung cấp giá trị. Collection request `[REPOSITORY ONLY / GHI] Sửa bài test — PUT /posts/{id}` giữ body JSON do người chạy điền. Khi thử theo snapshot, thêm `visibility`; đây vẫn là khác biệt giữa client method và spec, không được xem như tính năng đã bàn giao. Xem `/paths/~1posts~1{id}/put/requestBody/content/application~1json/schema/required` và `post_repository.dart:43-55`.
- Spec `ProfileResponse` dùng cho GET me và GET user ID đều khai báo `email`/`date_of_birth`; README dự án nói GET `/users/{id}` không trả hai trường. Schema không diễn tả field filtering theo viewer; cần owner chốt privacy behavior trước khi kết luận.

Các điểm được spec và app shape thống nhất: login gửi các field bắt buộc `email`, `password`, `device_id`, `platform` cùng device fields tùy chọn; spec có thêm `fid` tùy chọn mà app hiện không gửi. Profile update date là `date`, gender `MALE|FEMALE`; create post visibility `PUBLIC|FRIENDS|ONLY_ME`; media upload dùng multipart `file` và enum purpose; friendship request/accept/decline body, relation path IDs, reaction và report body khớp schema. DELETE `/friendships/{friendId}` mô tả ID người bạn cần hủy kết bạn, khớp caller gửi `userId`. Search `after` là integer offset.

OpenAPI áp dụng BearerAuth toàn cục trừ login/refresh; collection cấu hình token thủ công theo request. Spec định nghĩa response envelope `{code,message,data}` và các response schema cho data; app cũng unpacks envelope. Spec liệt kê HTTP statuses theo operation (ví dụ login `200/400/403`, refresh `200/401/403`, upload `200/400/413/500`, report `201/400/404`), nhưng không cố định giá trị `code` hay chứng minh runtime trả các status đó. Collection không có assertions về HTTP status, schema thực, quyền riêng tư hoặc error body. Không giả định 403/404 cụ thể khi chạy ca âm tính.

Một số mô tả prose trong spec lệch schema enum: `ReactRequest.target_type` description nhắc COMMENT nhưng enum không có COMMENT; `CreateReportRequestDto.violation_type` description liệt kê HATE_SPEECH/INAPPROPRIATE_CONTENT nhưng enum thực chỉ có `HARASSMENT`, `HATE_STATEMENT`, `SPAM`, `OTHER`. App enums khớp danh sách schema, không khớp prose dư. Gender enum lặp giá trị hai lần nhưng set giá trị vẫn là MALE/FEMALE. Dùng enum schema làm nguồn cho các request template và đề nghị API owner sửa prose.

Spec còn khai báo API không được repository hiện tại gọi, ví dụ `PUT /comments/{commentId}`, `GET /follows/followers`, `GET /follows/following` và `DELETE /users/me`; không thêm chúng vào toolkit theo phạm vi collection. Spec/API contract không chứng minh API đang triển khai ở runtime. Chưa gửi request API nghiệp vụ, login hoặc mutation; Postman import cũng chưa được chạy xác minh.

- Auth/profile: [auth_repository.dart](../../lib/data/repositories/auth_repository.dart), [user_repository.dart](../../lib/data/repositories/user_repository.dart).
- Posts/comments/relations: [post_repository.dart](../../lib/data/repositories/post_repository.dart), [comment_repository.dart](../../lib/data/repositories/comment_repository.dart), [friend_repository.dart](../../lib/data/repositories/friend_repository.dart).
- Feed/search/media/reaction/report: [feed_repository.dart](../../lib/data/repositories/feed_repository.dart), [user_search_repository.dart](../../lib/data/repositories/user_search_repository.dart), [media_repository.dart](../../lib/data/repositories/media_repository.dart), [reaction_repository.dart](../../lib/data/repositories/reaction_repository.dart), [report_repository.dart](../../lib/data/repositories/report_repository.dart).

Không có request backend nào được gửi để chuẩn bị toolkit này. Việc import vào Postman chưa được chạy xác minh.
