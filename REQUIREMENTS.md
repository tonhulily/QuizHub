# Yêu cầu cài đặt

Cần cài các công cụ ở bảng dưới (một lần cho mỗi máy), sau đó chạy script để kiểm tra và cài thư viện.
Chưa cài gì thì làm theo **"Hướng dẫn cài từ đầu"**, khoảng 1 giờ và 10 GB ổ đĩa trống.

| Công cụ | Phiên bản |
|---|---|
| Git | 2.40 trở lên |
| Flutter SDK (kênh stable, đã kèm Dart) | 3.41.x, Dart `^3.9.2` trở lên |
| JDK | 17 trở lên (JDK đi kèm Android Studio là đủ) |
| Android SDK + Platform-Tools (`adb`) | SDK Platform API 34 trở lên |
| Android NDK | **27.0.12077973** (đúng bản này, đã ghim trong `android/app/build.gradle.kts`) |
| Android SDK Command-line Tools | Nên có, để chạy `flutter doctor --android-licenses` |
| Điện thoại Android bật Gỡ lỗi USB, hoặc máy ảo | API 21 trở lên |

Gradle, Kotlin, Android Gradle Plugin tự tải khi build. Không cần API key hay file `.env`.

---

## Hướng dẫn cài từ đầu (Windows)

Làm lần lượt từ Bước 1. Sau mỗi bước có lệnh kiểm tra; ra kết quả đúng rồi mới sang bước sau.
(Tác giả chỉ kiểm thử trên Windows; macOS và Linux xem ghi chú cuối mục.)

### Bước 1. Cài Git
1. Tải bản Windows tại <https://git-scm.com/downloads>, cài với các tuỳ chọn mặc định.
2. Mở **terminal mới** (PowerShell hoặc Git Bash) và kiểm tra:
   ```
   git --version
   ```

### Bước 2. Cài Flutter SDK (Dart đi kèm)
1. Tạo thư mục `C:\src` (đường dẫn **không có khoảng trắng**, không đặt trong `Program Files`).
2. Cách đơn giản nhất, dùng Git:
   ```
   git clone https://github.com/flutter/flutter.git -b stable C:\src\flutter
   ```
   (Hoặc tải file zip bản stable tại <https://docs.flutter.dev/get-started/install>, giải nén ra
   `C:\src\flutter`.)
3. Thêm Flutter vào PATH. Mở **PowerShell** và chạy:
   ```powershell
   [Environment]::SetEnvironmentVariable('Path', [Environment]::GetEnvironmentVariable('Path','User') + ';C:\src\flutter\bin', 'User')
   ```
   (Hoặc làm bằng giao diện: `Win + R`, gõ `sysdm.cpl`, tab *Advanced*, *Environment Variables*, chọn
   `Path` của User, *New*, nhập `C:\src\flutter\bin`.)
4. **Đóng hết terminal, mở terminal mới**, rồi kiểm tra (lần đầu sẽ tải Dart SDK, mất vài phút):
   ```
   flutter --version
   dart --version
   ```
   Cần thấy Flutter 3.41.x và Dart 3.9.2 trở lên. Nếu thấp hơn, chạy `flutter upgrade`.

### Bước 3. Cài Android Studio (kèm JDK và Android SDK)
1. Tải tại <https://developer.android.com/studio> và cài.
2. Mở Android Studio lần đầu, màn hình **Setup Wizard** hiện ra: chọn **Standard**, chấp nhận các license,
   bấm Next đến hết để nó tải Android SDK (vài GB, cần Internet).
3. Android Studio đã kèm sẵn JDK nên **không cần cài JDK riêng**.

### Bước 4. Cài thêm thành phần Android (quan trọng: NDK đúng bản)
1. Ở màn hình chào của Android Studio: **More Actions > SDK Manager** (hoặc trong một dự án:
   *Tools > SDK Manager*).
2. Tab **SDK Platforms**: tích một bản **Android 14 (API 34)** trở lên.
3. Tab **SDK Tools**:
   - Tích **Android SDK Build-Tools**, **Android SDK Platform-Tools**,
     **Android SDK Command-line Tools (latest)**.
   - Tích **Show Package Details** (góc dưới), mở mục **NDK (Side by side)** và tích đúng
     **27.0.12077973** (bỏ tích các bản khác).
4. Bấm **Apply**, **OK**, đợi cài xong rồi **Finish**.

### Bước 5. Chấp nhận license Android
```
flutter doctor --android-licenses
```
Gõ `y` rồi Enter cho từng mục cho đến khi hết. (Lệnh này cần *Command-line Tools* ở Bước 4.)

### Bước 6. Chuẩn bị thiết bị chạy app
**Cách A: điện thoại thật (khuyến nghị)**
1. Vào *Cài đặt > Giới thiệu điện thoại* (Samsung: *Thông tin phần mềm*), bấm **7 lần** vào
   **Số hiệu bản dựng** để bật Tuỳ chọn nhà phát triển.
2. Vào *Cài đặt > Tuỳ chọn nhà phát triển*, bật **Gỡ lỗi USB**.
3. Cắm cáp USB vào máy tính. Trên điện thoại hiện hộp thoại *Cho phép gỡ lỗi USB?*: bấm **Cho phép**.
4. Kiểm tra:
   ```
   flutter devices
   ```
   Phải thấy tên điện thoại trong danh sách. Nếu không thấy: thử cáp khác (có loại chỉ sạc), cài driver
   USB của hãng máy (Samsung, Xiaomi...), hoặc rút cắm lại.

**Cách B: máy ảo**
Android Studio > **More Actions > Virtual Device Manager > Create Device**, chọn một máy bất kỳ rồi
chọn ảnh hệ thống **API 34** trở lên, bấm Finish và nút ▶ để bật máy ảo.

### Bước 7. Kiểm tra toàn bộ
```
flutter doctor -v
```
Cần dấu `[√]` ở **Flutter**, **Android toolchain**, **Connected device**. Các mục *Chrome*, *Visual
Studio*, *Android Studio* báo thiếu hay có `[!]` thì **bỏ qua được** (không dùng cho app này).

Nếu Flutter không tự tìm thấy Android Studio hoặc SDK (cài ở chỗ khác mặc định), chỉ đường cho nó:
```
flutter config --android-studio-dir "C:\Program Files\Android\Android Studio"
flutter config --android-sdk "D:\Android\Sdk"
```

### Bước 8. Lấy mã nguồn, cài thư viện và chạy
Xem mục **Cài thư viện và kiểm tra môi trường** bên dưới, sau đó làm theo [README.md](README.md).

### Ghi chú macOS và Linux (chưa kiểm thử)
- macOS: `brew install --cask flutter android-studio`, rồi làm từ Bước 3 trở đi. Build iOS cần thêm Xcode.
- Linux: `sudo snap install flutter --classic`, cài Android Studio từ trang chủ, rồi làm từ Bước 3 trở đi.

---

## Cài thư viện và kiểm tra môi trường

Thư viện Dart khai báo trong `pubspec.yaml` (phiên bản chính xác trong `pubspec.lock`) và cài bằng
`flutter pub get`. Script dưới đây chạy lệnh đó và kiểm tra luôn các công cụ ở bảng đầu trang; thiếu
gì nó báo rõ cách sửa. Chạy ở thư mục gốc của dự án sau khi clone:

```powershell
# Windows PowerShell
powershell -ExecutionPolicy Bypass -File scripts\setup.ps1
```
```bash
# Git Bash / macOS / Linux
bash scripts/setup.sh
```

Thêm `-Full` (PowerShell) hoặc `--full` (bash) để chạy luôn `flutter analyze` và `flutter test`.
Kết quả `SẴN SÀNG` nghĩa là chạy được.

## Phiên bản đã kiểm thử

Windows 11, Flutter 3.41.6 (Dart 3.11.4), JDK Temurin 21, NDK 27.0.12077973, Gradle 8.14, AGP 8.11.1,
Kotlin 2.2.20; thiết bị Samsung Galaxy A13 (Android 12).

## Lỗi thường gặp

| Hiện tượng | Cách xử lý |
|---|---|
| `flutter` hoặc `git` báo "not recognized" / "command not found" | Chưa thêm vào PATH, hoặc chưa mở **terminal mới** sau khi thêm |
| `flutter devices` không thấy điện thoại, `adb` báo `unauthorized` | Bật Gỡ lỗi USB, bấm **Cho phép** trên điện thoại, thử cáp khác |
| `cmdline-tools component is missing` | Cài *Android SDK Command-line Tools* (Bước 4) |
| `Some Android licenses not accepted` | `flutter doctor --android-licenses` (Bước 5) |
| Gradle không tải được NDK | Cài đúng NDK `27.0.12077973` (Bước 4); kiểm tra dung lượng ổ đĩa và Internet |
| Gõ `adb` báo không nhận ra lệnh | Thêm `%LOCALAPPDATA%\Android\Sdk\platform-tools` vào PATH (chạy app bằng `flutter run` thì không cần) |
| `setup.ps1` bị chặn chạy | Chạy bằng lệnh có `-ExecutionPolicy Bypass` như trên |
| `pub get` báo cần symlink (Windows) | Bật *Developer Mode* trong Settings > For developers |
| Build đầu tiên rất lâu | Bình thường: Gradle tải bản phân phối và thư viện, vài phút; các lần sau nhanh hơn |
