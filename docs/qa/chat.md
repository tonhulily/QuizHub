# Các mốc kiểm tra chat

## Mốc 1: danh sách và lịch sử REST

1. Bấm icon Tin nhắn trên header: xem danh sách, tin cuối, số chưa đọc; kéo làm mới và tải thêm.
2. Bấm một hội thoại: lịch sử mới nhất nằm dưới, kéo lên để tải tin cũ; không lặp tin khi làm mới.
3. Mở hồ sơ người khác → Nhắn tin: tạo/lấy lại đúng hội thoại 1–1. Mở lại không tạo bản trùng.
4. Nhấn giữ tin: xoá ở phía tôi; tin của mình có thêm thu hồi với mọi người.
5. Thử mất mạng/lỗi API và nút Thử lại; quay lại màn danh sách phải cập nhật dữ liệu.

Chạy bản mẫu: `flutter run -d <id> -t lib/main_preview.dart`.
Mốc này chưa có ô gửi tin; ô soạn tin và STOMP nằm ở commit kế tiếp.
