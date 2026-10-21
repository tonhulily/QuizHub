# QuizHub

Mạng xã hội cho sinh viên Bách Khoa (HUST) **đề xuất, đánh giá và thảo luận câu hỏi** của ngân hàng
đề. Giao diện theo bố cục Facebook, giữ màu thương hiệu HUST (đỏ, vàng).

- Backend: <https://snsqb.duckdns.org/api/v1/swagger-ui/index.html>
- Cài đặt môi trường: [REQUIREMENTS.md](REQUIREMENTS.md)
- Góc làm việc của Sơn (QA): [QA.md](QA.md) — test matrix, bug list, regression và cấu hình chạy riêng.

## Chạy dự án

```bash
git clone https://github.com/tonhulily/QuizHub.git && cd QuizHub
powershell -ExecutionPolicy Bypass -File scripts\setup.ps1   # Windows; Git Bash / macOS / Linux: bash scripts/setup.sh
flutter run -d <id>          # id lấy từ: flutter devices
```
Chưa có tài khoản thì chạy bản **xem trước** (dữ liệu mẫu, đã đăng nhập sẵn, mọi thao tác chỉ nằm
trong RAM): `flutter run -d <id> -t lib/main_preview.dart`. Thêm dữ liệu mẫu cho API mới trong hàm
`_route` của `lib/dev/preview_backend.dart`.

| Việc | Lệnh |
|---|---|
| Kiểm tra mã | `flutter analyze` và `flutter test` (phải sạch và xanh) |
| Định dạng | `dart format lib test` |
| Build APK | `flutter build apk --debug` (hoặc `--release`) |
| Đổi server | `--dart-define=API_BASE_URL=https://host/api/v1` (mặc định ở `lib/core/config/app_config.dart`) |

## Phạm vi

Vai trò: Sinh viên, Giảng viên, Admin. Tài khoản do giảng viên / nhà trường cấp, đăng nhập bằng email
trường, nên **không có** đăng ký, quên mật khẩu, OTP. Tài khoản mới phải nhập họ tên và ảnh đại diện
trước khi dùng app.

| Xong | Chưa làm |
|---|---|
| Đăng nhập (có lưu tài khoản), refresh token, đổi mật khẩu | Chat (WebSocket), Thông báo, Push (FCM) |
| Hồ sơ: xem, sửa, ảnh, gỡ ảnh, trang Giới thiệu | Môn học, phiên đề xuất / câu hỏi / đánh giá, đề thi |
| Bài viết: bảng tin, đăng, xoá, ảnh; bình luận; Like | Gamification, huy hiệu, cosmetics (mới chỉ hiển thị) |
| Bạn bè, theo dõi, chặn, báo cáo, tìm kiếm người dùng | Sửa / chia sẻ bài viết, video, tìm bài và câu hỏi |

Nút đã có giao diện nhưng chưa có chức năng gọi `showComingSoon(context, 'Tên')`; làm xong thì thay
bằng điều hướng thật. Endpoint của mọi module đã khai báo sẵn trong `lib/core/network/api_endpoints.dart`.

### Quy tắc nghiệp vụ phải giữ

- Bài viết và bình luận tối đa **500 từ** (`Validators.wordCount`); mỗi bài tối đa **4 ảnh**; ảnh
  ≤ **4MB**, **không nhận GIF**; video ≤ **15MB** (`ComponentTokens`, `MediaRepository`).
- Nội dung dài chỉ có "Xem thêm" (mở rộng, **không thu gọn lại**); ảnh luôn cắt theo **trung tâm**.
- Chỉ có **một** cảm xúc là Like (bấm lại là gỡ).
- Bình luận **không sửa được**; chỉ chủ bình luận được xoá.
- Chỉ kết bạn với người **cùng vai trò**; theo dõi thì không phân biệt.
- **Validate bằng regex ở client trước** khi gọi API (`Validators`); mật khẩu mới 6-32 ký tự, chỉ chữ
  và số.
- Trang chủ **cache** trang đầu để mở app là có nội dung ngay.
- Chỗ slide khác backend thật thì theo backend (mã thành công là `0000`, app chấp nhận cả `1000`).

### Giới hạn của backend (đã kiểm chứng, cần backend bổ sung)

- Hồ sơ **không có** quyền riêng tư theo từng mục, không có học vấn / công việc / nơi sống. Chỉ bài
  viết có `visibility` (`PUBLIC`, `FRIENDS`, `ONLY_ME`). `GET /users/{id}` không trả email, ngày sinh.
- **Không có** endpoint gợi ý kết bạn: app tự gợi ý (`UserSearchRepository.suggestions`). `/search` chỉ
  khớp tên và mã SV/GV, không khớp email đầy đủ: app suy ra mã từ email rồi lọc (`findByEmail`).
- Xoá bài là xoá mềm, bảng tin vẫn có thể trả bài đã xoá: app tự ẩn (`FeedRepository`,
  `LocalStorage.deletedPostIds`).
- Response dạng `{code, message, data}`; `ApiClient` tự bóc vỏ và ném `ApiException` khi lỗi. Phân
  trang bằng con trỏ `after` (`CursorPage`, `PagedCubit`); riêng `/search` dùng offset.

## Phong cách code

Luồng: `View → Cubit → Repository → ApiClient → Backend`. View không biết Dio, token, JSON; Cubit không
biết JSON; Repository trả model hoặc ném `ApiException`. Model là lớp Dart thuần: `Equatable`, `fromJson`
bằng `J.*`, **không** dùng codegen.

1. **Màu, icon, kích thước** chỉ lấy từ `AppColors`, `AppIcons`, `DesignTokens`, `ComponentTokens`.
   Không viết `Color(0x...)`, `Colors.red`, `Icons.xxx` trong feature; thiếu thì thêm vào file đó.
2. **State**: `flutter_bloc` (Cubit + `Equatable`). Danh sách phân trang dùng `PagedCubit<T>` +
   `PagedListView<T>`.
3. **Gọi API chỉ qua repository**; đường dẫn đặt trong `ApiEndpoints`; không đụng token hay Dio ở feature.
4. **Hàm hành động trong Cubit trả `Future<ApiException?>`** (`null` là thành công) để màn hình tự hiển
   thị lỗi bằng `AppFeedback.error`. Mẫu: `FriendsCubit`, `UserRelationCubit`.
5. **Cập nhật chéo màn hình** bằng sự kiện phát sóng đăng ký trong `locator.dart` (`PostEvents`,
   `SocialEvents`). Like và hành động nhẹ thì cập nhật lạc quan, lỗi thì hoàn tác.
6. **DI** bằng `get_it` (`lib/di/locator.dart`, repository dùng `registerLazySingleton`). **Route**: tên
   trong `AppRoutes` + một `case` trong `AppRouter`.
7. Chuỗi hiển thị và chú thích code viết tiếng Việt; chú thích giải thích **vì sao**, không nhắc lại code.

Giao diện kiểu Facebook: khối trắng, tràn cạnh, không bo góc, không đổ bóng, cách nhau dải xám 8px
(`SectionGap`, `ComponentTokens.postGap`). Dùng widget có sẵn trong `core/widgets/fb_widgets.dart`
(`FlatSection`, `HeaderIconButton`, `StatusBarSafe`...), `AppButton`, `AppTextField`, `UserAvatar`. Trang
cuộn cả trang không có AppBar phải bọc `StatusBarSafe`. Icon header và tab là icon trần; tab đang chọn
dùng bản đặc (`xxxActive`). Màn đăng nhập có giao diện riêng (`classic: true`), đừng dùng ở màn khác.

## Thêm một tính năng mới

Ví dụ làm tab Thông báo (`GET /notifications`):

1. **Model** `lib/data/models/notification_model.dart`: `Equatable` + `fromJson` bằng `J.*`.
2. **Repository** `lib/data/repositories/notification_repository.dart`, rồi đăng ký trong `locator.dart`:
   ```dart
   class NotificationRepository {
     final ApiClient _api;
     NotificationRepository(this._api);

     Future<CursorPage<NotificationModel>> list({String? after}) =>
         _api.get<CursorPage<NotificationModel>>(
           ApiEndpoints.notifications,
           query: {'after': after, 'limit': AppConfig.defaultPageSize},
           parser: (d) => CursorPage.fromJson(d, NotificationModel.fromJson),
         );
   }
   ```
3. **Màn hình** `lib/features/notifications/` gồm `view/`, `widgets/`, và `cubit/` nếu có logic riêng.
   Danh sách phân trang không cần Cubit riêng:
   ```dart
   BlocProvider(
     create: (_) => PagedCubit<NotificationModel>(
       (after) => getIt<NotificationRepository>().list(after: after),
     )..load(),
     child: PagedListView<NotificationModel>(
       itemBuilder: (context, n) => NotificationTile(item: n),
     ),
   )
   ```
4. **Gắn vào app**: thay `PlaceholderTab` trong `MainShell.tabs` (`features/shell/main_shell.dart`), hoặc
   thêm route; lối tắt Menu sửa trong `MenuTab.shortcuts`.
5. **Dữ liệu mẫu** cho bản xem trước: thêm route vào `_route` của `lib/dev/preview_backend.dart`.
6. **Test** trong `test/` (xem dưới), rồi `dart format lib test`, `flutter analyze`, `flutter test`.

Trước khi viết, gọi thử API và xem **JSON thật** (spec đôi khi lệch thực tế).

### Viết test

Không gọi mạng thật. Dựng `ApiClient(..., adapter: backendGiả)` với `HttpClientAdapter` trả JSON theo
`'METHOD /path'`: mẫu ở `test/data/friends_test.dart`. Widget test bọc `MaterialApp(theme:
AppTheme.lightTheme)`, dùng repository giả (`implements UserRepository`) đăng ký vào `getIt`: mẫu ở
`test/features/friend_actions_test.dart`. Nút chỉ có icon nên đặt `Tooltip` để dễ test.

## Đóng góp

- Mỗi việc một nhánh (`feature/...`, `fix/...`), commit nhỏ, rõ nghĩa (`feat:`, `fix:`, `docs:`...).
- Trước khi đẩy: `dart format lib test`, `flutter analyze` sạch, `flutter test` xanh.
- Thêm thư viện bằng `flutter pub add <gói>` và commit cả `pubspec.yaml` lẫn `pubspec.lock`.
- Không commit `build/`, `*.apk`, `android/local.properties`, keystore, mật khẩu hay token.
- Không dùng tài khoản người khác để thử hành động ghi (kết bạn, xoá...); dùng bản xem trước.
