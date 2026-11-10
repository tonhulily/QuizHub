# Kiểm tra iOS

## Cấu hình

- Mac có Xcode, iOS SDK và CocoaPods. Xác nhận bằng `flutter doctor -v`.
- iOS tối thiểu **15.0**, thống nhất giữa Xcode và `ios/Podfile`.
- Plugin hỗ trợ Swift Package Manager được Flutter nối qua package sinh tự động;
  `flutter_secure_storage` 9.2.4 vẫn dùng CocoaPods. Giữ cả hai phần tích hợp.
- Debug, Profile, Release dùng tệp `.xcconfig` tương ứng trong `ios/Flutter`,
  mỗi tệp nạp cấu hình Pods cùng chế độ rồi nạp `Generated.xcconfig`.
- Mở **`ios/Runner.xcworkspace`**, chọn Runner → Signing & Capabilities → Team
  của người chạy. Để giữ Team riêng trên máy, tạo `ios/Flutter/Signing.xcconfig`
  với dòng `DEVELOPMENT_TEAM = <TEAM_ID>`; cả ba cấu hình build đều nạp file này
  nếu có. File được Git bỏ qua; project dùng chung không ghim Team cá nhân.

## Kiểm tra biên dịch

Chạy từ thư mục gốc:

```bash
flutter pub get
cd ios
pod install
cd ..
flutter build ios --debug --no-codesign -t lib/main_preview.dart
flutter build ios --release --no-codesign -t lib/main.dart
flutter build ios --profile --no-codesign -t lib/main_preview.dart
```

Các lệnh `--no-codesign` chỉ xác nhận biên dịch và liên kết plugin; sản phẩm này
chưa có chữ ký để cài lên iPhone. Cảnh báo `flutter_secure_storage` chưa hỗ trợ
Swift Package Manager không làm thất bại build hiện tại vì plugin được nối qua Pods.

Nếu đã cài iOS Simulator runtime, có thể kiểm tra thêm kiến trúc simulator:

```bash
flutter build ios --simulator --debug -t lib/main_preview.dart
```

## Kiểm tra trên iPhone thật

1. Cắm iPhone vào Mac, mở khóa và chọn Tin cậy khi được hỏi. Bật Developer Mode
   trong Cài đặt → Quyền riêng tư & Bảo mật nếu máy yêu cầu, khởi động lại và xác nhận.
2. Trong Xcode, kiểm tra thiết bị đã ghép nối và Team ký app đúng tài khoản.
3. Chạy:

   ```bash
   flutter devices
   flutter run --release -d <iphone-id> -t lib/main_preview.dart
   ```

4. Kiểm tra bảng tin → chi tiết bài → bình luận, sửa bài và gửi chat. Đóng hẳn app
   rồi mở lại để xác nhận nội dung đã lưu. Gỡ cài đặt app sẽ xoá dữ liệu preview cục bộ.
5. Chọn ảnh thư viện/chụp ảnh, kiểm tra hộp thoại cấp quyền và khả năng chọn lại sau
   khi huỷ. Khi bàn phím mở, kiểm tra ô chat và nút gửi vẫn sử dụng được.

Khi cần hot reload hoặc đọc lỗi Dart, bỏ `--release` để chạy debug. Dùng release
cho bài kiểm tra đóng hẳn rồi mở lại app trên iPhone; debug có thể không khởi động
lại từ màn hình chính khi không được Flutter/Xcode chạy cùng.

Bản preview đã đăng nhập tài khoản mẫu, không cần tài khoản backend. Kiểm tra đăng nhập
và Keychain thật bằng `lib/main.dart` cần tài khoản test do nhóm/backend cung cấp.
