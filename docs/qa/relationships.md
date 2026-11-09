# Kiểm tra danh sách quan hệ

- Mở trang cá nhân của mình, bấm số người theo dõi / đang theo dõi: đúng danh sách, mở được hồ sơ người trong danh sách.
- Trong Đang theo dõi, chọn Bỏ theo dõi: huỷ xác nhận thì giữ nguyên; xác nhận thành công thì gỡ dòng, trở về hồ sơ cập nhật số đếm.
- Mở menu ba chấm của hồ sơ mình → Người đã chặn: hiển thị danh sách và nút Bỏ chặn, không mở hồ sơ người bị chặn.
- Bỏ chặn thành công thì gỡ dòng. API lỗi thì giữ dòng và báo lỗi, nút được bật lại.
- Kiểm tra kéo làm mới, tải thêm, danh sách rỗng, mất mạng và thử lại.
- Danh sách followers/following hiện áp dụng cho tài khoản đang đăng nhập.

Bản xem trước: `flutter run -d <device-id> -t lib/main_preview.dart`.
Chặn hoặc theo dõi một tài khoản mẫu từ hồ sơ để tạo dữ liệu cho các danh sách.

## Chặn xuyên các màn FE

1. Mở bài/hồ sơ/chat của một người, gõ một đoạn tin nháp rồi quay về. Từ hồ sơ, chọn Chặn.
2. Quay lại bảng tin: bài viết và hoạt động của người đó biến mất, kể cả bản đã tải/cache.
   Tìm tên/mã của họ không có kết quả; họ cũng không còn trong bạn bè, lời mời hoặc theo dõi.
3. Mở lại hồ sơ, Giới thiệu hoặc bài viết từ đường dẫn/các màn đã mở trước đó: chỉ hiện
   nội dung không khả dụng, không có tên/ảnh/nội dung hay nút tương tác.
   Ảnh/video toàn màn hình của họ đang mở cũng phải ẩn và dừng phát.
4. Trên bài của người khác, bình luận của tài khoản bị chặn không lộ tác giả, chữ, ảnh,
   phản hồi hoặc nút Thích/Trả lời. Có thể giữ chỗ Bình luận không khả dụng để không đổi cấu trúc luồng.
5. Hội thoại của họ biến mất khỏi danh sách. Chat đang mở ẩn lịch sử, tên/ảnh và ô gửi;
   không gửi tin, typing hoặc read tiếp. Xem thêm [chat.md](chat.md).
6. Đóng rồi mở lại app preview: trạng thái chặn vẫn giữ. Chạy lại không cài lại/xóa dữ liệu ứng dụng.
7. Hồ sơ mình → menu ba chấm → Người đã chặn vẫn có tên/ảnh và nút Bỏ chặn để quản lý.
   Bỏ chặn xong xem lại/tìm lại được; bạn bè và theo dõi đã hủy không tự khôi phục.
8. API chặn lỗi: thông báo lỗi, giữ trạng thái cũ. Danh sách `/blocks` tải nhiều trang phải
   đồng bộ đủ; response cũ không được ghi đè lần chặn vừa thực hiện.

Preview đã mô phỏng quy tắc trên và lưu quan hệ trên thiết bị, không cần server riêng.
Đây là phần FE: bản thật đọc `/blocks`, gọi API hiện có và lọc giao diện/cache theo danh sách đó.
Quyền truy cập từ thiết bị/tài khoản đối phương vẫn do backend thật thực thi; chưa xác nhận bằng hai tài khoản thật.
Xóa ứng dụng/dữ liệu sẽ xóa phần lưu preview. Danh sách FE tách theo tài khoản và môi trường preview/server.
