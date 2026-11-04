# Chat 1–1

Đối chiếu đặc tả công khai ngày 04/11/2026:
https://snsqb.duckdns.org/api/v1/docs/openapi.json

| Thao tác | Đường dẫn |
|---|---|
| Danh sách hội thoại | `GET /conversations?after=&limit=20` |
| Tạo/lấy lại chat 1–1 | `POST /conversations/direct`, body `target_user_id` |
| Lịch sử (có tác dụng đánh dấu đã đọc) | `GET /conversations/{id}/messages`; danh sách nằm trong `messages` |
| Thành viên | `GET /conversations/{id}/members` |
| Xoá/thu hồi | `DELETE /messages/{id}`, body `scope: ME/EVERYONE` |

WebSocket: `wss://snsqb.duckdns.org/api/v1/ws`, xác thực ở STOMP CONNECT bằng
`Authorization: Bearer <access_token>`.

- Gửi: `/app/chat.send`, `conversation_id`, `content`, `message_type`, `media_urls`, `reply_to_message_id`.
- Đã đọc: `/app/chat.read`, `conversation_id`, `message_id`.
- Đang nhập: `/app/chat.typing`, `conversation_id`, `is_typing`.
- Nhận tin/biên nhận: `/user/queue/messages`.
- Nhận đang nhập: `/topic/conv.{conversation_id}.typing`.

Backend không có REST gửi tin nhắn. Không tự gửi lại sau khi mất kết nối để tránh trùng tin.
OpenAPI mô tả tên các DTO broadcast nhưng không khai báo schema chi tiết; cần kiểm tra
thêm với hai tài khoản thật để xác nhận payload, biên nhận lỗi và quy tắc chặn hai chiều.
