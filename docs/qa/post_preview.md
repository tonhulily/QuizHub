# Kiểm tra lưu bài viết trong preview

Chạy `flutter run -d <id> -t lib/main_preview.dart`. Bài viết được lưu riêng trong dữ liệu preview
trên thiết bị, không gửi lên server thật. Nội dung, quyền xem, danh sách media và ID bài được giữ
qua hot restart hoặc đóng/mở app. Dữ liệu của các module preview khác vẫn ở trong RAM.

1. Mở bài của Nguyễn Văn An → ba chấm → Chỉnh sửa. Đổi nội dung, quyền xem, bỏ ảnh hoặc thay ảnh,
   rồi bấm Lưu. Mở chi tiết và kéo làm mới để kiểm tra.
2. Tắt hẳn rồi mở lại app (hoặc dùng hot restart `R` trong Flutter terminal). Kiểm tra bài ở cả
   bảng tin, chi tiết và trang cá nhân: các thay đổi phải còn.
3. Tạo một bài mới, khởi động lại, kiểm tra bài vẫn còn và sửa được.
4. Xoá bài, khởi động lại, kiểm tra bài không xuất hiện lại. Tạo bài khác, kiểm tra không dùng lại
   ID đã xoá và không bị bộ lọc bài đã xoá ẩn đi.

Đây là lưu dữ liệu trên một thiết bị, chưa đồng bộ giữa các máy. Gỡ app hoặc xoá dữ liệu app có
thể xoá dữ liệu thử nghiệm. Các thay đổi đã mất từ những phiên preview cũ không thể khôi phục
qua bản sửa này. Ảnh upload trong preview vẫn là ảnh giả lập của bộ mẫu.
