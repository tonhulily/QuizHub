# Native UI QA — Quốc Anh, 19/11/2026

> Trạng thái cuối sau khi phiên làm việc bị ngắt: [resume handoff](2026-11-19-quoc-anh-resume.md). Theo yêu cầu, QA package đã gỡ khỏi thiết bị; chưa ghi nhận crash mới của app QA.

## Lượt mở app / startup

- **Trạng thái:** startup/Home đã quan sát trên APK sửa đúng build harness; các case acceptance chưa hoàn tất trước khi phiên làm việc bị ngắt, giữ NOT RUN / INCOMPLETE.
- **SOURCE_SHA:** `447ecf394894627e498df08464466f16a12e3ef6`; `MAIN_SNAPSHOT`: `08a5a2e4097923d21bbdaf7d02cb1792f2171aa3`.
- **Build:** Flutter 3.47.9 / Dart 3.13.7, isolated source BASE `447ecf3` cộng một import Cupertino được Sơn cho phép; root source không đổi. Exact preview build exit 0 sau 318.7 giây. Chi tiết provenance ở [native build report](2026-11-19-quoc-anh-native-build.md).
- **APK:** SHA-256 `755b5deaf26c70f781a0055167fba5e4a29d544a8697a829772c26981654a120`, 97,980,127 bytes; file còn lưu trong isolated workspace theo resume handoff.
- **Cài/mở:** package QA `vn.edu.hust.quizhub.qa.quocanh`; install exit 0 / Success, cold launch exit 0 / Status ok trong 5.786 giây. QA package foreground và Home thực tế được quan sát; device APK SHA khớp local artifact.
- **Thiết bị:** RMX3370, Android 13 / API 33, độ phân giải 1080×2400, density 480, `font_scale=1.0`. Device được MCP báo loại `emulator`; không suy diễn thiết bị vật lý. Preview local/mock, không có API host.
- **Quan sát tester:** APK cũ SHA `588…` bị splash đen do thiếu `GeneratedPluginRegistrant`/SharedPreferences; đây là lỗi QA tooling. Screenshot được giữ. APK mới đúng mở Home với Tạo bài/Tin Nhắn/feed. Home chỉ xác nhận startup, không xác nhận normal flow.
- **Cleanup:** khi phiên làm việc bị ngắt, người dùng yêu cầu dừng và gỡ QA app. Uninstall thành công; `pm path` exit 1 xác nhận package vắng mặt. Không có quan sát hay bằng chứng về crash mới của app QA. Display/font settings được đọc lại, không cần hoàn nguyên. Không nêu serial/ID thiết bị.
- **Evidence:** [startup-black-flutter-splash.png](../evidence/2026-11-19/quoc-anh-native-ui/startup-black-flutter-splash.png) và [home-baseline.png](../evidence/2026-11-19/quoc-anh-native-ui/home-baseline.png). Giữ ảnh lỗi; ảnh Home là startup context, không phải bug proof.
- **Giới hạn/tool:** Mobile MCP foreground metadata và log/crash tools trả unsupported legacy robot mode; không thu được process/log từ tester. Coordinator tiếp tục chẩn đoán startup bằng ADB/logcat. Không khẳng định nguyên nhân và không gán lỗi sản phẩm trước khi xem logs.

## Case acceptance

`POST-FLOW-01`, `COMM-LIKE-01`, `CHAT-DEL-01`, `REL-LIST-01`, `QH-QA-010` và `QH-QA-012`: **NOT RUN / INCOMPLETE**; chỉ startup/Home đã quan sát, luồng acceptance chưa hoàn tất trước khi phiên làm việc bị ngắt. Không ghi PASS/FAIL. Flutter 3.47.9 targeted UI log cũng **INTERRUPTED / INCOMPLETE**: partial `+11`, không có final summary/exit code. Chưa ghi nhận crash mới của app QA. CHAT-DEL peer-side và backend/API vẫn BLOCKED do fixture chỉ có An điều khiển được và không có API host/tài khoản.

## Lệnh/điều kiện

- Final wrapper build (Flutter 3.47.9): `../../sdk-3.47.9/flutter/bin/flutter build apk -t lib/main_preview.dart --debug --no-pub --target-platform android-arm64 --android-project-arg=android.builder.sdkDownload=false` — exit 0 sau 318.7 giây. Direct Gradle `assembleDebug -Ptarget=lib/main_preview.dart -Ptarget-platform=android-arm64 -Pandroid.builder.sdkDownload=false` là lịch sử APK cũ SHA `588…`; APK đó thiếu plugin registrant và splash đen.
- Install/launch/uninstall do coordinator thực hiện; người dùng yêu cầu dừng sau khi phiên làm việc bị ngắt, không có test tiếp theo. QA package `vn.edu.hust.quizhub.qa.quocanh` đã gỡ; `pm path` exit 1 xác nhận vắng mặt. APK đúng còn trong workspace cho phiên sau.
