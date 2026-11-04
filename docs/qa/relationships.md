# Kiểm tra danh sách quan hệ

- Mở trang cá nhân của mình, bấm số người theo dõi / đang theo dõi: đúng danh sách, mở được hồ sơ người trong danh sách.
- Trong Đang theo dõi, chọn Bỏ theo dõi: huỷ xác nhận thì giữ nguyên; xác nhận thành công thì gỡ dòng, trở về hồ sơ cập nhật số đếm.
- Mở menu ba chấm của hồ sơ mình → Người đã chặn: hiển thị danh sách và nút Bỏ chặn, không mở hồ sơ người bị chặn.
- Bỏ chặn thành công thì gỡ dòng. API lỗi thì giữ dòng và báo lỗi, nút được bật lại.
- Kiểm tra kéo làm mới, tải thêm, danh sách rỗng, mất mạng và thử lại.
- Danh sách followers/following hiện áp dụng cho tài khoản đang đăng nhập.

Bản xem trước: `flutter run -d <device-id> -t lib/main_preview.dart`.
Chặn hoặc theo dõi một tài khoản mẫu từ hồ sơ để tạo dữ liệu cho các danh sách.
