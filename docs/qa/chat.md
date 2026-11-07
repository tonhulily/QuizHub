# Các mốc kiểm tra chat

## Mốc 1: danh sách và lịch sử REST

1. Bấm icon Tin nhắn trên header: xem danh sách, tin cuối, số chưa đọc; kéo làm mới và tải thêm.
2. Bấm một hội thoại: lịch sử mới nhất nằm dưới, kéo lên để tải tin cũ; không lặp tin khi làm mới.
3. Mở hồ sơ người khác → Nhắn tin: tạo/lấy lại đúng hội thoại 1–1. Mở lại không tạo bản trùng.
4. Nhấn giữ tin: xoá ở phía tôi; tin của mình có thêm thu hồi với mọi người.
5. Thử mất mạng/lỗi API và nút Thử lại; quay lại màn danh sách phải cập nhật dữ liệu.

Chạy bản mẫu: `flutter run -d <id> -t lib/main_preview.dart`.
Mốc 1 chỉ kiểm tra danh sách/lịch sử; gửi tin nằm ở mốc 2.

## Mốc 2: gửi nhận realtime

1. Dùng hai tài khoản thật, mở cùng hội thoại: gửi chữ và ảnh, tin xuất hiện hai bên không cần kéo làm mới.
2. Bên nhận đang mở cuộc trò chuyện: người gửi thấy Đã xem khi nhận biên nhận có id tin tương ứng.
3. Nhập chữ: bên kia thấy Đang nhập, tự hết khi dừng gõ hoặc rời màn hình.
4. Tắt mạng: nút gửi bị khoá; nội dung nháp được giữ. Bật mạng lại, app tải bù lịch sử và không nhân đôi tin.
5. Mất mạng ngay sau gửi: nội dung được giữ nếu chưa xác nhận. Bấm gửi lại sẽ kiểm tra lịch sử trước và hỏi xác nhận nếu chưa thấy tin.
6. Thu nhỏ rồi mở lại app: kết nối và danh sách tự cập nhật. Đăng xuất: kết nối phải dừng.

Bản preview dùng realtime trong RAM và có phản hồi mẫu, phục vụ kiểm tra UI; không thay thế kiểm tra STOMP với hai tài khoản thật.

## Mốc 3: quyền gửi và khôi phục kết nối

- Chặn đối phương từ hồ sơ trong khi chat đang mở: ẩn tên/ảnh, lịch sử và ô gửi,
  không gửi typing/read tiếp; giữ nội dung nháp của mình trong phiên. Hội thoại bị ẩn khỏi danh sách.
- Bỏ chặn từ danh sách Người đã chặn rồi quay lại: app kiểm tra lại quyền, tải lại lịch sử,
  hiện lại nội dung nháp và cho gửi khi backend xác nhận không bị chặn.
- Đối phương chặn mình: kiểm tra bằng tài khoản thứ hai; backend phải từ chối gửi và client hiển thị lỗi/khóa gửi.
- Đổi mạng/đưa app vào nền/mở lại nhiều lần: không lặp tin hoặc đăng ký trùng kênh.
- Đăng xuất rồi đăng nhập tài khoản khác: không nhận sự kiện từ kết nối cũ.
- Thu hồi một tin cũ đã tải qua phân trang: vẫn giữ chỗ Tin nhắn đã thu hồi.
- Server đã lưu tin nhưng echo bị mất: kiểm tra lại lịch sử, xác nhận đúng tin và không gửi lại tự động.
