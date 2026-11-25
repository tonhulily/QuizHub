# Native PREVIEW retest — 2026-11-24

## Trạng thái

Phiên PREVIEW bị dừng theo yêu cầu quota. Core UI trên Lecturer hoàn tất với 40 kiểm tra: 27 PASS, 1 WAITING, 6 NOT RUN, 6 BLOCKED. Pha học thuật Lecturer bị ngắt sau 12 PASS, 0 FAIL, 1 WAITING, 0 BLOCKED, 6 NOT RUN; xem [báo cáo Lecturer](2026-11-24-native-lecturer.md). Student APK mới chưa cài/chạy. Student APK đầu tiên treo splash do Dart kernel cache cũ, không dùng tiếp. Đây không phải acceptance và không đổi trạng thái issue.

Thiết bị: Mobile MCP báo RMX3370, Android 13/API 33, loại `emulator`; ADB serial được redact. Không suy diễn loại thiết bị khác với nhãn tool. Người dùng cho phép PREVIEW only; không có API host hoặc tài khoản QA.

## Source và artifact

- Source archive: `d89a8d660d93842475b694100ccef1fdf783ed9e`.
- Các APK được build từ `.qa-tools/native-20261124/`, package `vn.edu.hust.quizhub.qa.retest`, version 1/1.0.
- STUDENT APK đầu tiên (artifact cũ, không dùng cho case tiếp): SHA-256 `ab9b32a37f143901d6c8f6a4d06b10474495995cd1f8f7838e70f18bedaa007b`, 93,761,716 bytes. Build thành công, APK/DEX/signature checks exit 0. Cài lại qua ADB exit 0; Mobile MCP launch thành công nhưng chỉ hiện splash.
- STUDENT APK mới, build với `PREVIEW_ROLE=STUDENT`: SHA-256 `7e73007a0f1a0a641a0f60c7ee75375cb671bede178c151f9b57a7292347a718`, 120,520,585 bytes. Build exit 0 (`BUILD SUCCESSFUL`, 1m28s); kiểm tra kernel có SharedPreferencesAndroid, ImagePickerAndroid, UrlLauncherAndroid, AndroidVideoPlayer, SqfliteAndroid; APK signature v2 verify exit 0. Chưa cài hoặc quan sát startup, nên chưa xác nhận lỗi splash đã khắc phục. Log: `qa-artifacts/2026-11-24/build-readiness/gradle-preview-student-fresh.log`.
- LECTURER APK: SHA-256 `6e77ccf5ff4a81dd55f7cbe9b0637325fbf547bde48bd1cc03cce7d77a11cf4d`, 120,520,446 bytes. Build và APK/DEX/signature checks exit 0. ADB `install -r` exit 0; Mobile MCP launch thành công, Home hiển thị trong hierarchy. Ảnh [Home context](../evidence/2026-11-24/native-startup/lecturer-home-context.png) chỉ ghi nhận ngữ cảnh khởi động, không phải bằng chứng PASS của acceptance case.
- Hai APK ban đầu được kiểm tra package/version/launcher/ABI. Student mới được tạo từ cùng isolated QA build config; chưa cài hoặc quan sát startup. Chi tiết lệnh, gate và checksums ở [native build evidence](../evidence/2026-11-24/native-build-gate.txt).

## Core preview phase

Chi tiết từng luồng và ảnh nằm trong [báo cáo native core](2026-11-24-native-core.md). Trong 40 kiểm tra UI preview riêng: **27 PASS, 1 WAITING, 6 NOT RUN, 6 BLOCKED**; đây không phải 25-case acceptance matrix. Bài viết, bình luận, hồ sơ và chat được thao tác bằng fixture; marker chat và trạng thái thu hồi còn sau relaunch trong lưu trữ preview cục bộ. Quan hệ/report chỉ một phần; media chưa chạy, đăng nhập hợp lệ chưa thử. Không xác minh API/backend, giao nhận chat với peer, biên nhận đã đọc hoặc FCM. Những kết quả này không đổi acceptance hay trạng thái issue.

## Kết quả startup

Log Student ghi nhận Firebase khởi tạo thành công rồi phát sinh `MissingPluginException` cho SharedPreferences `getAll`; app ở splash. [Trích đoạn log đã redact](../evidence/2026-11-24/native-startup/startup-log-redacted.txt); [ảnh splash lỗi](../evidence/2026-11-24/native-startup/student-first-splash-failure.png) được giữ lại.

Audit chỉ đọc so sánh Student APK kernel với cache: Student APK đầu tiên chứa `app.dill` cũ (76,210,896 bytes) không có SharedPreferences Dart adapter; Lecturer chứa kernel mới hơn (85,205,248 bytes) có adapter. Registrant đã cập nhật sau khi Student APK đầu tiên được tạo. Đây là lỗi cache/artifact QA phù hợp với log khởi động, chưa phải lỗi runtime source đã xác nhận. Student APK đầu tiên không hợp lệ để chạy tiếp case. Student APK mới với `PREVIEW_ROLE=STUDENT` explicit đã build và qua kernel/signature checks, nhưng chưa cài hoặc retest; startup result của nó còn chờ quan sát.

Các gate build đã được xử lý trong archive cô lập: metadata Android được tạo lại và self-check qua với 15 plugin; Google Services task dùng client Firebase nguồn sau khi Android variant cấu hình, trong khi application ID cài vẫn là QA riêng. `:app:processDebugGoogleServices` chạy offline exit 0; generated app/project/sender IDs khớp client nguồn. JSON và `lib/firebase_options.dart` giữ nguyên so với source. Patch cấu hình ở [qa-packaging.patch](../evidence/2026-11-24/qa-packaging.patch). Chi tiết metadata: `qa-artifacts/2026-11-24/build-readiness/plugin-tooling/result.md`; cache audit: `qa-artifacts/2026-11-24/native-startup/cache-audit.md`.

## Dừng phiên và tiếp tục

Theo yêu cầu dừng do quota, QA app đã force-stop/uninstall; `pm path` xác nhận package vắng mặt. Đúng tám fixture trên thiết bị đã bị xóa và ADB/browser đã được dừng. Chi tiết redact: [bằng chứng cleanup](../evidence/2026-11-24/device-cleanup.txt). Không ghi tracker hoặc đổi issue status trong phiên này. Host cũng xóa build intermediates, giữ lại APK và SDK/dependency cache để tiếp tục mà không cần build lại. [Resume checkpoint](2026-11-24-resume.md) ghi các bước tiếp.

Acceptance matrix giữ baseline ngày 23/11: 24 `NOT RUN`, 1 `WAITING`, 0 `PASS`, 0 `FAIL`. Các số core/Lecturer phía trên chỉ là preview UI; không đánh PASS cho acceptance. API/backend/FCM còn `BLOCKED` vì chưa có API host/tài khoản QA; cấu hình Firebase nguồn chỉ phục vụ PREVIEW resources. Hướng dẫn tiếp tục, trạng thái draft đã mất sau uninstall và artifact được giữ tại [resume checkpoint](2026-11-24-resume.md).
