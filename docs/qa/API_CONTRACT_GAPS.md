# Các điểm API cần xác minh

## Trạng thái nguồn

README và `ApiEndpoints` trỏ tới [Swagger UI](https://snsqb.duckdns.org/api/v1/swagger-ui/index.html). Lượt đọc đầu trong sandbox gặp lỗi DNS. Lượt GET qua kết nối được phép sau đó thành công: Swagger UI, initializer, config và [OpenAPI](https://snsqb.duckdns.org/api/v1/docs/openapi.json) đều trả HTTP 200, TLS được kiểm tra.

Snapshot OpenAPI 3.1.0 có 128 paths, được tải lúc 2026-10-21 23:32:59 +07; SHA-256 `63dc2323f2a0b07a8ba09f8623c7612c8e2f0af327a4c91888632f5943939cc5`, 317,935 byte. Bản local ở `qa-artifacts/swagger/openapi.json`, metadata ở cùng thư mục; cả hai bị ignore, không được push. Người dùng yêu cầu dừng trước khi hoàn tất đối chiếu spec với collection. Chưa đăng nhập, gọi endpoint nghiệp vụ hoặc thực hiện thao tác ghi.

Vì vậy, collection Postman ghi lại request shape mà app gửi, không được xem là contract backend đã xác minh. Không suy đoán status HTTP, body lỗi hoặc hành vi quyền truy cập.

## Câu hỏi cần chốt khi có spec/host test

- **Tất cả endpoint trong collection:** verb/path có đúng trên backend hiện tại không; field nào bắt buộc, nullable hoặc bị bỏ qua; status HTTP và envelope chính xác là gì?
- **Auth:** login/refresh/logout dùng body và token rotation ra sao; logout thu hồi token nào; field thiết bị và enum platform hợp lệ gồm những giá trị nào? `AuthRepository` gửi email, password, device_id, platform, device_name, os_version, app_version ở login; refresh gửi refresh_token. Client đọc `access_token`, `refresh_token`, `user_id` hoặc `id`, `username`, `role` từ login response; cần xác nhận server thật trả các field này.
- **Profile:** `PUT /users/me` cho phép field nào; omission khác `null`/chuỗi rỗng thế nào; format ngày sinh và enum giới tính; response trả đủ profile hay một phần? App chỉ gửi các field có giá trị từ `UserRepository.updateMe`.
- **Post privacy:** khi A tạo bài `FRIENDS` hoặc `ONLY_ME`, nội dung nào được thấy qua feed, profile và `GET /posts/{id}` của B; mã HTTP/body từ chối cụ thể là gì? README yêu cầu kiểm tra quyền, nhưng không chốt status.
- **Post delete:** backend có soft-delete không; quyền chủ bài/admin; response và hành vi feed sau xóa. App ghi nhận 404 như đã xóa ở client, nhưng chưa chứng minh backend contract.
- **Comments:** `target_type`, sort, cursor và page fields; chỉ chủ comment được DELETE; phản hồi khi B cố xóa comment của A. `CommentRepository` nêu quy tắc chủ sở hữu, nhưng status/body lỗi chưa xác minh.
- **Pagination:** `pagination.after` là cursor string với feed/comments/friends hay offset số với `/search`; quy tắc kết thúc trang và page size server cho phép. App parser đọc `items`, `pagination.after`, `pagination.has_next`; `/search` hiện gửi `type=USER`, `query`, `after`, `limit`.
- **Media:** MIME/extension được nhận, giới hạn server, purpose hợp lệ và response chứa URL/ID nào; app gửi multipart field `file` và query `purpose` uppercase. `MediaUploadResult` đọc `object_key`, `url`, `file_size`, `content_type`, `media_type`, `width`, `height`.
- **Relationships:** role restrictions, accept/decline/request semantics và response state; hiện request tạo bạn gửi `addressee_id`, accept/decline gửi `requester_id`.

## Bằng chứng cần lưu

Khi API host/spec được cấp, ghi SHA app đã kiểm thử, environment host (không ghi token), request name, status/body đã che dữ liệu cá nhân, thời điểm, tài khoản test A/B và expected source. Các thao tác tạo/xóa chỉ dùng fixture disposable; không dùng credentials hoặc dữ liệu của người khác.

Không đánh dấu contract gap là bug cho tới khi requirement/API owner xác nhận expected. Giữ trạng thái `BLOCKED` hoặc `WAITING` nếu host, quyền hoặc expected behavior chưa rõ.
