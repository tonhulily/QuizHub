# Test chat FE giữa hai tài khoản

Bản `lib/main_chat_demo.dart` dùng mock API chung chạy trên Mac và WebSocket/STOMP thật.
Samsung dùng Nguyễn Văn An (user 1), trình duyệt trên Mac dùng Trần Thị Lan (user 2).
Hai người phải tự gửi; bản này không tự sinh câu trả lời bot.
Server thật của dự án không bị thay đổi. Các phần ngoài chat vẫn dùng dữ liệu mẫu của preview.

## Chạy mock API trên Mac

Trong thư mục QuizHub, giữ Terminal này mở:

```bash
dart tool/chat_demo_server.dart --port 8787 --data-dir .local/chat-demo
```

Lịch sử được lưu tại `.local/chat-demo`. Dừng rồi chạy lại server cùng thư mục vẫn giữ dữ liệu.
Không xóa thư mục này khi kiểm tra mở lại app/server.

## Samsung: tài khoản An

Cắm USB, bật gỡ lỗi và kiểm tra `adb devices`. Chuyển cổng từ Samsung về Mac:

```bash
adb reverse tcp:8787 tcp:8787
flutter run -d R58N74G3G8V -t lib/main_chat_demo.dart --dart-define=CHAT_DEMO_USER_ID=1
```

Nếu Terminal chưa nhận `adb`, thay bằng `~/Library/Android/sdk/platform-tools/adb`.
Kết nối đảo cổng có thể cần chạy lại khi rút/cắm USB hoặc khởi động điện thoại.

## Trình duyệt trên Mac: tài khoản Lan

Terminal thứ ba:

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8082 -t lib/main_chat_demo.dart --dart-define=CHAT_DEMO_USER_ID=2
```

Mở địa chỉ Flutter in ra bằng trình duyệt. Giữ hai phiên chạy cùng lúc.
Nếu máy đã có Chrome, có thể thay `-d web-server ...` bằng `-d chrome`.

`CHAT_DEMO_URL` mặc định là `http://127.0.0.1:8787/api/v1`; WebSocket được suy ra từ URL này.
Có thể đổi bằng `--dart-define=CHAT_DEMO_URL=http://host:port/api/v1` ở cả hai phiên.
Mỗi bản dùng tài khoản cố định theo `CHAT_DEMO_USER_ID`; mở lại app vẫn là tài khoản đó,
không cần email hoặc mật khẩu server thật. Cache của bản test tách theo máy chủ và tài khoản,
không xóa dữ liệu đang lưu của bản preview đơn lẻ.

## Các bước phải qua

1. Mở Tin nhắn trên hai máy. Tạo/mở hội thoại An ↔ Lan; không tạo hội thoại trùng khi mở lại.
2. An gửi một câu có nội dung riêng, Lan nhận đúng câu đó ngay. Lan trả lời, An nhận lại.
   Để yên ít nhất vài giây: không có câu trả lời tự động nào xuất hiện.
3. Một bên đang nhập/đã đọc: bên kia thấy đúng trạng thái khi hai app kết nối.
4. Gửi ảnh trên Samsung, xem được ảnh trong chat và toàn màn hình ở hai phía.
5. Gửi xong, chờ xác nhận; quay về danh sách rồi mở lại, nội dung còn đúng một bản.
6. Đóng hẳn app rồi mở lại: đúng tài khoản, đúng hội thoại, tin cũ vẫn còn.
7. Dừng rồi chạy lại mock API cùng `--data-dir`: kết nối tự phục hồi, lịch sử không mất hoặc nhân đôi.
8. Mất kết nối: app báo lỗi/khóa gửi, giữ nội dung nháp. Chạy lại server và bấm thử lại.
9. Xoá ở phía tôi chỉ ảnh hưởng tài khoản đó; thu hồi tin của mình cập nhật hai bên và vẫn giữ sau restart.
10. Chặn đối phương thì không xem/gửi; bỏ chặn cho phép mở lại lịch sử, không tự tạo tin mới.

Nếu server chưa chạy hoặc USB chưa đảo cổng, màn khởi động có nút Thử lại và giữ đúng
thông tin tài khoản test, không vào nhầm một tài khoản từ cache.
