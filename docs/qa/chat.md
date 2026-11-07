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

Bản preview đơn lẻ lưu hội thoại và lịch sử chữ/ảnh trên máy, không tự sinh phản hồi.
Để test hai tài khoản qua REST/STOMP, dùng [bản test dùng chung](chat_two_accounts.md):
An trên Samsung và Lan trên web cùng nối vào mock API trên Mac.

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

## Giao diện chat kiểu Messenger

- Mở Tin nhắn: tìm theo tên hoặc nội dung tin cuối, chuyển Tất cả/Chưa đọc.
  Khi lọc, các trang hội thoại cũ cũng được tải để tìm đủ kết quả; kéo làm mới giữ bộ lọc.
- Danh sách hiển thị ảnh đại diện, tin cuối (có tiền tố Bạn cho tin gửi đi), giờ và số chưa đọc từ API.
  Không suy diễn trạng thái online khi API chưa cung cấp.
- Trong chat: tin mình nằm bên phải, tin nhận bên trái; tin liên tiếp cùng người gửi được gom,
  có mốc thời gian và trạng thái Đã gửi/Đã xem. Nhấn giữ để sao chép, xoá hoặc thu hồi tin của mình.
- Ảnh hiện trực tiếp trong bong bóng; bấm để xem toàn màn hình. Ảnh đang soạn có thumbnail và nút gỡ.
  Nút thích khi ô soạn trống gửi emoji 👍 dưới dạng tin nhắn chữ.
- Cuộn lên xem lịch sử rồi bấm nút mũi tên để về tin mới nhất. Tin đến không kéo người đang đọc tin cũ xuống.
- Ngắt mạng khi tải lịch sử/kiểm tra quyền: hết vòng chờ, có Thử lại; không mở khoá gửi khi chưa xác nhận quyền.
- Thu hồi/xoá một tin nằm ngoài trang đầu ở phiên khác, sau đó đồng bộ/reconnect: phần lịch sử đã tải cũng cập nhật.

Các thao tác trên thuộc FE và dùng API/STOMP hiện có. Bản `main_chat_demo.dart` kiểm tra
hai phiên app với hai danh tính riêng, không có bot; không thay đổi server thật của dự án.

## Giữ tin nhắn preview khi thoát và mở lại

- Gửi chữ và ảnh trong hội thoại có sẵn và hội thoại mới. Chờ xác nhận gửi, quay lại danh sách,
  mở lại: tin còn đúng một bản, tin cuối trên danh sách khớp lịch sử.
- Đóng hẳn app rồi mở lại hoặc hot restart: giữ nội dung, ảnh, hội thoại mới và con trỏ tải thêm;
  gửi tiếp không trùng ID. Không xoá app/xoá dữ liệu trong bài kiểm tra này.
- Xoá hoặc thu hồi tin, mở app lại: trạng thái vẫn giữ, nội dung đã gỡ không xuất hiện lại.
- Nếu ghi bộ nhớ lỗi: không báo Đã gửi, giữ nội dung soạn để thử lại và không tạo tin ma trong
  lịch sử. Chỉ xác nhận sau khi ghi hoàn tất; tải lại trong lúc ghi không đọc trạng thái chưa lưu.
- Chặn/bỏ chặn chỉ ẩn/hiện hội thoại, không xoá lịch sử đã lưu. Các module khác vẫn giữ dữ liệu cũ.

Phần lưu này chỉ dành cho dữ liệu preview của tài khoản mẫu và không thay đổi backend thật.
