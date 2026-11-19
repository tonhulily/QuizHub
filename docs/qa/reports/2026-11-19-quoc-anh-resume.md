# Handoff tiếp tục QA Quốc Anh — 19/11/2026

Sơn báo phiên làm việc/VS Code bị ngắt và yêu cầu dừng, gỡ APK khỏi điện thoại, lưu tiến trình. Chưa ghi nhận crash mới của app QA. Đã dừng lượt test và gỡ QA package; không chạy lại test/build trong handoff này.

## Trạng thái cuối

- Source gốc: `447ecf394894627e498df08464466f16a12e3ef6`; upstream `main`: `08a5a2e4097923d21bbdaf7d02cb1792f2171aa3`.
- Bản APK đúng dùng Flutter 3.47.9, BASE `447ecf3` cộng một import Cupertino được Sơn cho phép trong isolated QA workspace. Root source và lockfile không đổi. QH-QA-005 vẫn OPEN trên source gốc; patch này không phải upstream fix.
- Build exact preview: exit 0 sau 318.7 giây. APK giữ tại `.qa-tools/quoc-anh-native-20261119/workspace/build/app/outputs/flutter-apk/app-debug.apk`, SHA-256 `755b5deaf26c70f781a0055167fba5e4a29d544a8697a829772c26981654a120`, 97,980,127 bytes. Không dùng APK cũ SHA bắt đầu `588` (thiếu plugin registrant, splash đen) hoặc APK wrapper khác.
- APK đúng đã install và cold-launch thành công (ADB install exit 0/Success; launch exit 0/Status ok, 5.786 s). Home thực tế hiện Tạo bài, Tin Nhắn và feed. Screenshot Home: [home-baseline.png](../evidence/2026-11-19/quoc-anh-native-ui/home-baseline.png). Screenshot APK lỗi cũ vẫn lưu: [startup-black-flutter-splash.png](../evidence/2026-11-19/quoc-anh-native-ui/startup-black-flutter-splash.png); đó là QA tooling error, không phải product bug.
- Sau khi phiên làm việc bị ngắt, thiết bị `RMX3370`, Android 13/API 33: uninstall QA package `vn.edu.hust.quizhub.qa.quocanh` thành công; kiểm tra `pm path` exit 1, không còn package. Font scale 1.0, physical display 1080×2400, density 480; không có thay đổi display settings cần hoàn nguyên. Không đưa serial/device ID vào hồ sơ.
- Flutter 3.47.9 targeted UI log `qa-artifacts/2026-11-19/quoc-anh-native/targeted-ui-tests-3.47.9.log` dừng ở partial `+11`; không có final completion/exit code. Ghi **INTERRUPTED / INCOMPLETE**, tuyệt đối không gọi là 25 PASS. Startup/Home đã quan sát; normal flow POST/COMM/CHAT/REL chưa hoàn tất. Các acceptance case giữ **NOT RUN / INCOMPLETE**, không suy ra PASS từ source hoặc màn Home.
- Local core/data/recovery: 106 PASS ở Flutter 3.47.9 trên fake/preview/loopback; chi tiết [local expanded](2026-11-19-quoc-anh-local-expanded.md). Không phải API acceptance; raw full log không được lưu.
- Flutter 3.41.6 remapped UI 25 PASS và layout 2 PASS/5 FAIL chỉ là kết quả **PROVISIONAL**; offline enforce-lockfile exit 65 vì muốn hạ 5 dependency. Không dùng chúng làm baseline cuối.
- API host và tài khoản A/B chưa có: API/backend cases **BLOCKED**. Contract chưa được owner xác nhận: **WAITING**. QH-QA-010..012 chưa có repro mới đầy đủ, không tạo bug mới.

## Tiếp tục lần sau

1. Xác nhận người dùng muốn tiếp tục rồi mở đúng isolated workspace và APK SHA `755b5d…`; giữ package ID `vn.edu.hust.quizhub.qa.quocanh` riêng với app chính.
2. Bắt đầu bằng kiểm tra startup/Home và ghi evidence mới nếu app khởi động ổn; sau đó làm từng POST-FLOW-01, COMM-LIKE-01, CHAT-DEL-01, REL-LIST-01 theo [kịch bản native](2026-11-19-quoc-anh-native-cases.md). Ghi đúng trạng thái nếu app crash; không suy rộng một crash thành product defect nếu chưa có log/repro đủ.
3. Nếu tiếp tục widget suite, log hiện tại không hoàn chỉnh: thực hiện một run mới có tee/log capture và exit code rõ ràng, chỉ sau khi người dùng yêu cầu tiếp tục QA. Không gán partial `+11` thành kết quả hoàn tất.
4. Khi kết thúc test, giữ screenshot lỗi, gỡ app QA trừ khi Sơn yêu cầu giữ lại, rồi ghi đúng APK/source/patch provenance, lệnh, exit code, device và evidence. Không thay đổi root runtime/dependency.

API/backend vẫn chờ host, tài khoản và contract; trạng thái tracker do coordinator đối chiếu khi chốt. Các case candidate 010–012 vẫn pending, không log duplicate.
