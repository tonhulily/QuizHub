# Tóm tắt QA Quốc Anh — 19/11/2026

**Handoff sau phiên làm việc bị ngắt:** theo yêu cầu Sơn, dừng QA, gỡ APK khỏi điện thoại, lưu APK và trạng thái để tiếp tục hôm sau. Chưa ghi nhận crash mới của app QA. Xem [resume handoff](2026-11-19-quoc-anh-resume.md).

## Source và kết quả local

Source gốc được kiểm thử là `447ecf394894627e498df08464466f16a12e3ef6`, upstream `main` `08a5a2e4097923d21bbdaf7d02cb1792f2171aa3`. Root không có thay đổi runtime/dependency. Trên Flutter 3.47.9 / Dart 3.13.7, local core+dev đạt 15, data đạt 87 và chat recovery đạt 4 (**106 PASS**, mỗi nhóm exit 0). Đây là fixture/fake/preview và loopback, không phải API acceptance. Tool transcript không giữ full stdout/stderr; evidence là excerpt được ghi sau lượt chạy, không phải raw log. Xem [báo cáo local chi tiết](2026-11-19-quoc-anh-local-expanded.md) và [results excerpt](../evidence/2026-11-19/quoc-anh-local/results.txt).

Compile-only probe UI chat/blocking trên root exit 1 tại `CupertinoPageTransitionsBuilder` ở `app_theme.dart:196-197`; test bodies không chạy. Đây là blocker QH-QA-005 đang mở, không phải business-case failure. Sơn đã cho phép một import Cupertino duy nhất trong QA workspace cô lập để mở compile gate; root source vẫn giữ nguyên.

## Build/native

Lượt manual/layout đầu trên Flutter 3.41.6 được xem **PROVISIONAL**: manual remapped UI 25 PASS, layout 2 PASS/5 FAIL. Chạy offline với `--enforce-lockfile` ở SDK này exit 65 và sẽ hạ 5 dependencies; không dùng làm baseline chuẩn. Không cài SDK.

Build cô lập trên BASE `447ecf3` cộng patch được Sơn cho phép, Flutter 3.47.9, `--no-pub`, explicit preview target, `arm64` và tắt SDK downloads; build exit 0 sau 318.7 giây. Lock giữ nguyên; metadata và plugin registrant được tạo. Hash đầy đủ và lệnh nằm trong [native build report](2026-11-19-quoc-anh-native-build.md).

APK QA đã xác minh khởi động: SHA-256 `755b5deaf26c70f781a0055167fba5e4a29d544a8697a829772c26981654a120`, kích thước 97,980,127 bytes; dex có registrant và SharedPreferences. Install ADB exit 0/Success; cold launch exit 0/Status ok trong 5.786 giây; QA app foreground và Home thực tế được quan sát. Sau khi phiên làm việc bị ngắt, theo yêu cầu, QA package đã gỡ khỏi thiết bị; APK còn trong workspace. Chưa ghi nhận crash mới của app QA. Hash đầy đủ và path ở [native build report](2026-11-19-quoc-anh-native-build.md).

Một APK thử trước đó (SHA bắt đầu `588`) hiện màn đen/logo do thiếu `GeneratedPluginRegistrant` và SharedPreferences; đây là lỗi QA tooling, không phải product bug. Đã gỡ thành công (exit 0; `pm path` xác nhận vắng mặt, exit 1) và giữ PNG evidence.

Flutter 3.47.9 targeted UI log dừng giữa chừng ở partial `+11`, không có final summary/exit code: **INTERRUPTED / INCOMPLETE**, không tính là 25 PASS. Native đã vào Home nhưng normal-flow cases chưa hoàn tất trước khi phiên làm việc bị ngắt. Không có bằng chứng về crash mới của app QA. Thiết bị RMX3370 Android 13/API 33, 1080×2400, density 480, font scale 1.0; package đã gỡ. Xem [native UI report](2026-11-19-quoc-anh-native-ui.md).

## Acceptance còn lại

Sơn xác nhận chưa có API host và tài khoản QA A/B; kiểm thử backend/API **BLOCKED**. Các contract chưa được owner xác nhận vẫn **WAITING**. Local test, build hoặc mở app không tự đổi trạng thái matrix; chỉ cập nhật khi coordinator xác nhận từng case và evidence. QH-QA-005 vẫn mở trên source gốc; patch cô lập không được xem là upstream fix.
