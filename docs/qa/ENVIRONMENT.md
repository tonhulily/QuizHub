# Môi trường QA

## Native PREVIEW dừng theo quota — 2026-11-25 (cleanup hoàn tất, còn việc)

- Source archive `d89a8d660d93842475b694100ccef1fdf783ed9e` (upstream `82ef14f38e086d6b558b392fc54a328c3d7f26a2`), checkpoint tài liệu đã push `7edf960`. Runtime source và dependency/lock không đổi. QA application ID `vn.edu.hust.quizhub.qa.retest`; Student APK SHA-256 `7e73007a0f1a0a641a0f60c7ee75375cb671bede178c151f9b57a7292347a718` (`qa-artifacts/2026-11-24/apks/student-preview-fresh.apk`) đã cài đúng hash và hiện đã gỡ sau lượt test. Lecturer academic: 19 kiểm tra unique, 18 PASS/1 WAITING (PW-03); lựa chọn quyền OS còn NOT RUN ngoài 19 kiểm tra. Student academic: **23 PASS/1 FAIL/5 NOT RUN**; rating/statistics đã hoàn tất. Student utilities: **11 PASS/1 WAITING/2 NOT RUN** ([báo cáo utilities](reports/2026-11-25-native-student-utilities.md)). Core UI 24/11: 40 preview checks, 27 PASS, 1 WAITING, 6 NOT RUN, 6 BLOCKED ([báo cáo core](reports/2026-11-24-native-core.md)). Student core 25/11 dừng theo quota: **12 PASS, 2 NOT RUN, 1 BLOCKED / 15** ([báo cáo core](reports/2026-11-25-native-student-core.md)). Đây đều là preview UI, không phải acceptance. Xem [báo cáo Student academic](reports/2026-11-25-native-student-academic.md), [báo cáo Lecturer](reports/2026-11-25-native-lecturer.md), và [resume](reports/2026-11-25-resume.md).
- Môi trường quan sát: RMX3370, Android 13/API 33, MCP báo emulator; device ID/serial đã che. Màn hình 1080×2400, density 480/360 dp, font scale 1.0. QH-QA-016 ghi nhận overflow khoảng 15 px ở hàng thẻ Game 2 trên hub; [ảnh lỗi](evidence/2026-11-25/native-student-academic/S-GAME-00-hub.png). Nguyên nhân còn là giả thuyết.
- Fixture QA đã được đẩy và `ls` xác nhận 8 file; lượt core xác nhận DocumentsUI hiển thị đủ 8 file sau media scan ([evidence setup](evidence/2026-11-25/device-fixtures.txt)). Core preview dừng theo quota: **12 PASS, 2 NOT RUN, 1 BLOCKED / 15** ([báo cáo core](reports/2026-11-25-native-student-core.md)). Các case còn chạy được là `S-G1-02`, `S-G2-04`, `S-G2-05`, `S-G4-03`, `S-NOT-04`, `SCG-10`, `SCG-15`; `S-EXAM-01` và quyền OS còn NOT RUN theo giới hạn prompt UI. QA package đã force-stop/gỡ; fixture folder đã xóa, media scan refresh đã gửi; `sync` hoàn tất và ADB process vắng mặt. Không có xác nhận rút cáp vật lý ([cleanup evidence](evidence/2026-11-25/device-cleanup.txt)). Không chạy lại APK cũ Student 24/11 do kernel stale.
- User cho phép tạm thời giữ màn hình awake khi đang sạc. Các lần thử ghi setting thất bại (`WRITE_SECURE_SETTINGS`, `svc power stayon usb` exit 137); cleanup sau cùng đọc `stay_on_while_plugged_in=0` và không có thay đổi cài đặt. Không tìm cách root hoặc đổi quyền. Cleanup gỡ QA app, xóa đúng thư mục fixture, chạy `sync`, dừng ADB; không xác nhận thao tác tháo cáp vật lý. Chi tiết exit codes tại [cleanup evidence](evidence/2026-11-25/device-cleanup.txt).

Baseline 25-case acceptance vẫn **24 NOT RUN, 1 WAITING, 0 PASS, 0 FAIL**; API host/tài khoản chưa có nên API/backend/FCM còn BLOCKED. Tracker có **16 issue: 7 Open, 1 Ready for Retest, 8 Closed**; QH-QA-016 vẫn Open. Không coi preview là acceptance. [Report tracker](reports/2026-11-25-tracker-update.md).

## Kiểm thử PREVIEW native — 2026-11-24

- Source archive: `d89a8d660d93842475b694100ccef1fdf783ed9e`. APK được build trong `.qa-tools/native-20261124/` với package `vn.edu.hust.quizhub.qa.retest`; không sửa mã runtime, manifest dependency hoặc lockfile. Dùng Java 17, Gradle và Android SDK có sẵn.
- Google Services task dùng client Firebase nguồn sau khi Android variant đăng ký; `applicationId` cài vẫn là ID QA. Lệnh riêng `:app:processDebugGoogleServices` chạy `--offline`, exit 0; resource ID khớp client nguồn. Đây chỉ là cấu hình resource cho PREVIEW, không xác minh FCM. Xem [patch](evidence/2026-11-24/qa-packaging.patch) và [build gate](evidence/2026-11-24/native-build-gate.txt).
- Metadata plugin Android đã được tạo lại; self-check có 15 plugin entries, exit 0. Hai APK Student/Lecturer ban đầu build thành công; Student ban đầu dùng Dart kernel cũ và treo ở splash. APK Student mới build với `PREVIEW_ROLE=STUDENT`, kiểm tra kernel/chữ ký thành công nhưng chưa cài hoặc quan sát lúc khởi động. APK Lecturer cài và mở đến Home.
- Mobile MCP báo RMX3370, Android 13/API 33, loại `emulator`; ADB serial đã che. Không suy ra thiết bị vật lý. Pha core PREVIEW đã xong; trong 40 kiểm tra UI riêng có **27 PASS, 1 WAITING, 6 NOT RUN, 6 BLOCKED**. Đây không phải acceptance. Pha Lecturer học thuật bị dừng theo yêu cầu quota (19 kiểm tra: 12 PASS, 0 FAIL, 1 WAITING, 0 BLOCKED, 6 NOT RUN); [báo cáo Lecturer](reports/2026-11-24-native-lecturer.md). QA app đã gỡ và 8 fixture thiết bị đã dọn. Xem [báo cáo native](reports/2026-11-24-native-retest.md), [báo cáo core](reports/2026-11-24-native-core.md), [resume](reports/2026-11-24-resume.md), và [cleanup evidence](evidence/2026-11-24/device-cleanup.txt).
- Chưa có API host/tài khoản QA. API/backend và FCM acceptance vẫn BLOCKED; preview UI không đổi ma trận 25 case hoặc trạng thái issue.

## Regression runner cập nhật 2026-11-23

- Checkout QA: `qa/khanhson2005`; tested sources gồm merge `622640325b7c1b4bf0f3a5018ffd2635dce27061`, regression checkpoint `2f040844ee939317ac06da6a9d7473670f4213cd`, và focused retest checkpoint `04d858c5348626198b1879a7900e2d75c9390e58`. Upstream main snapshot: `82ef14f38e086d6b558b392fc54a328c3d7f26a2`.
- Linux x86_64, Flutter 3.41.6 stable / Dart 3.11.4 từ `.qa-tools/flutter`; `PUB_CACHE=.qa-tools/pub-cache`, XDG config/cache ở `.qa-tools/`. Không cài SDK/package và không chạy `pub get`.
- Đã audit toàn bộ `pubspec.lock`: 141 hosted package versions đều có cache đúng phiên bản. `.dart_tool/package_config.json` được dựng lại từ package map exact-lock cũ, bổ sung Firebase và giữ SDK package paths của Flutter 3.41.6. Flutter 3.47.9 có sẵn tại `.qa-tools/sdk-3.47.9/flutter`, nhưng test SDK packages của nó không khớp lockfile; không ghép runner đó với dependency config này.
- Flutter test loader cần loopback `127.0.0.1`; sandbox thường chặn bind. Các lượt test cuối được chạy bằng loopback access đã được cấp. Lượt sandbox đầu có lỗi tạo server socket và không được dùng làm kết quả cuối.
- Không có API host/tài khoản hoặc thiết bị trong các lần chạy. Regression là unit/widget với fakes/mocks; browser preview dùng local static server, không gọi backend.
- Full logs đang ở ignored `qa-artifacts/2026-11-23/regression/`, `qa-artifacts/2026-11-23/regression/checkpoint-2f040844/`, `qa-artifacts/2026-11-23/retest/`, và `qa-artifacts/2026-11-23/web/`. Chọn evidence/report: [regression](reports/2026-11-23-regression.md), [retest evidence](evidence/2026-11-23/retest/results.txt), [web](reports/2026-11-23-web.md).

## Cập nhật QA ngày 2026-11-15 — lịch sử audit và trạng thái mới nhất

- **Audit ban đầu tại SHA `adde556e2ef6e481fd7145588db878012673b059`:** package config có 135 package so với 136 trong lockfile; Flutter test/analyze khi đó **BLOCKED / NOT RUN**. Chi tiết: [báo cáo regression](reports/2026-11-15-regression.md). Đây là trạng thái trước khi coordinator khôi phục cache.
- **Trạng thái mới nhất theo coordinator:** `flutter pub get --enforce-lockfile` thành công cho main với Flutter 3.47.9 và cho preview Nam với Flutter 3.41.6; preview source SHA `639da129d89e8290c13b63af3d36045309b38fd6`. JDK17 có tại `.qa-tools/java17`; Android SDK tại `.qa-tools/android-build-sdk`.
- Mobile MCP hiện thấy thiết bị `RMX3370`, Android 13, online. Không ghi serial/ID hoặc khẳng định loại thiết bị.
- Preview `assembleDebug` và cài QA app đã thành công theo coordinator; APK SHA-256 `c09122a2c64d4e76650176c330b4494d090f822bd0357dc2b76b512fe7718603`, source snapshot SHA `639da129d89e8290c13b63af3d36045309b38fd6`. Native UI cases `BLOCKED`/`NOT RUN` do overlay ứng dụng khác giữ focus; không có UI case PASS. QA package đã được gỡ và `pm path` xác nhận package không còn. Xem [báo cáo môi trường Android](reports/2026-11-15-android-environment.md), [báo cáo native UI](reports/2026-11-15-native-ui.md), và [evidence](evidence/2026-11-15/android-environment.txt).
- Package roots hiện hữu không chứng minh cache khớp lockfile. Các kết quả setup và kiểm tra Flutter ở các mục lịch sử bên dưới chỉ áp dụng cho SHA được ghi tại từng kết quả; không dùng chúng để kết luận runner hiện tại sẵn sàng offline.

Ghi nhận cập nhật **2026-10-22** trên nhánh `qa/khanhson2005`. Flutter persistent đã được setup và xác minh; thư mục `.qa-tools/` được ignore bởi Git. Phiên bản, archive checksum, pub get và lockfile evidence: [sdk-setup.log](../../qa-artifacts/2026-10-22/sdk-setup.log).

## Cập nhật QA ngày 2026-10-26

- Source app được kiểm tra: `b949513b254bee55a3887e619786ea91f85b477f`.
- `flutter test --no-pub --reporter expanded`: 144 passed, 1 failed, exit 1; lỗi fixture role trong test UI, chưa xác nhận runtime defect. `flutter analyze --no-pub`: 0 issues, exit 0. Chi tiết: [báo cáo review](reports/2026-10-26-dung-review.md).
- Web preview dùng `PreviewBackend` in-memory: 12 case PASS; không xác nhận API/backend thật. Xem [báo cáo web UI](reports/2026-10-26-web-ui.md).
- Native preview APK `vn.edu.hust.quizhub.qa.preview`, cùng source SHA, trên GT Neo2 / RMX3370 / Android 13 / API 33: 5 case PASS, 2 BLOCKED/INCONCLUSIVE; không gọi API host. Case và ảnh: [báo cáo mobile UI](reports/2026-10-26-mobile-ui-setup.md). Coordinator đã gỡ riêng QA app; MCP uninstall thành công, và `adb shell pm path vn.edu.hust.quizhub.qa.preview` trả exit 1 với output rỗng.
- Preview UI smoke cases độc lập với acceptance matrix; chúng không làm thay đổi trạng thái 19 NOT RUN / 6 WAITING.

## Flutter local runner

Flutter 3.41.6 stable / Dart 3.11.4 nằm trong `.qa-tools/flutter`; archive SHA-256 `503b3e6b7d352fca5d21b6474eca95ad544d8fc3b053782eab63a360c7fc7569` đã khớp manifest chính thức. Package cache ở `.qa-tools/pub-cache`; `flutter pub get --enforce-lockfile` exit 0 và `pubspec.lock` giữ SHA-256 `4069b6a766720cba6b6ec17891ecc9c6b5d448bed16f5af8d7d0f1552eedc7d0`. Kết quả Flutter checks theo source SHA được ghi ở phần dưới.

Từ root repo, dùng các biến terminal tạm sau:

```bash
export XDG_CONFIG_HOME="$PWD/.qa-tools/config"
export XDG_CACHE_HOME="$PWD/.qa-tools/cache"
export PUB_CACHE="$PWD/.qa-tools/pub-cache"
export FLUTTER_SUPPRESS_ANALYTICS=true CI=true
FLUTTER="$PWD/.qa-tools/flutter/bin/flutter"
```

Không pin SDK toàn cục hoặc vào cấu hình editor.

**Lịch sử Flutter đã test, không áp dụng cho merge SHA `74c8ea16b05733a2e5620dc48f3c52cc6867c3b6`:** `d58cdf01a4b2e04a41901e8804fe1d49847faccf`.

- `flutter test --no-pub`: 95 test passed, exit 0. Log: [flutter-regression-d58cdf0-local-runner.log](../../qa-artifacts/flutter-regression-d58cdf0-local-runner.log).
- `dart format --output=none --set-exit-if-changed lib test`: 112 files, 0 changed, exit 0. Log: [dart-format-d58cdf0.log](../../qa-artifacts/dart-format-d58cdf0.log).
- Lượt `flutter test` trong sandbox mặc định không chạy được do runner không bind được loopback `127.0.0.1` cho 13 test loader; lần chạy local runner được duyệt ở trên đã thành công. Chi tiết: [flutter-regression-d58cdf0.log](../../qa-artifacts/flutter-regression-d58cdf0.log).
- `flutter analyze` trước đó báo `No issues found` tại SHA `f5e225a5d4aa5d8e8e366770eb2bb4b0212621a6`; đầu ra của lượt đó không được lưu thành log. Đây không phải kết quả analyzer sau commit `d58cdf0`.

### Kiểm tra source cập nhật 2026-10-22

Các lần chạy được phân biệt theo source SHA. Môi trường: Linux x86_64 / WSL2, Flutter 3.41.6 stable, Dart 3.11.4, `.qa-tools/` isolated XDG/PUB_CACHE, không có API host hoặc thiết bị.

- Tại `f1951b0c03c5b21929414485101108c804c3ebd0`, `flutter test --no-pub --reporter expanded`: **98 PASS**, exit 0 ([log](../../qa-artifacts/2026-10-22/flutter-default-tests-f1951b0.log)).
- Cùng SHA, `flutter analyze --no-pub`: exit 1 do hai `invalid_use_of_visible_for_testing_member` warnings trong `qa/repro/network_risks_test.dart` ([log](../../qa-artifacts/2026-10-22/flutter-analyze-f1951b0.log)).
- Cùng SHA, `dart format --output=none --set-exit-if-changed lib test qa/repro`: exit 1; 114 files checked, hai file `lib/core/utils/validators.dart` và `test/core/school_email_test.dart` sẽ đổi. Đây là check-only; không format/modify file ([log](../../qa-artifacts/2026-10-22/dart-format-check-f1951b0.log)). Coordinator xác nhận hai file này đến từ upstream `main` snapshot `6ee7f6d9a9a9d2342803c41a32f8dd03ac7a0d48`; không tự ý format chúng.
- Tại `520c7381f0159ce40f9534ace1c657b87aa523d1`, `flutter analyze --no-pub`: exit 0, “No issues found” ([log](../../qa-artifacts/2026-10-22/analyze-520c738.log)); QA-only `dart format --output=none --set-exit-if-changed qa/repro`: 1 file/0 changes, exit 0 ([log](../../qa-artifacts/2026-10-22/format-check-520c738.log)); opt-in network repro: 2 invariant FAIL, exit 1 ([log](../../qa-artifacts/2026-10-22/repro-520c738.log)). Default tests không rerun tại SHA này vì thay đổi sau `f1951b0` chỉ suppress hai warning trong QA harness; runtime và default test code không đổi.

Lần chạy mặc định 98 PASS không xác nhận API, thiết bị, hay acceptance UI/E2E. Chưa có API host/account; API acceptance vẫn NOT RUN. Các lượt preview UI riêng ngày 2026-10-26 không thay thế acceptance matrix.

98 test là unit/widget automation chạy trên local runner; không xác nhận tích hợp API từ xa, hành vi trên thiết bị/emulator, hoặc hoàn tất ma trận 25 kịch bản acceptance thủ công.

**API_ACCEPTANCE_TESTED_SHA: NONE.** Chưa có API host/account để chạy API business acceptance. Android SDK/ADB và thiết bị đã được kiểm tra riêng cho QA preview như ghi ở trên; đây không phải API acceptance. Yêu cầu môi trường dự án xem [REQUIREMENTS.md](../../REQUIREMENTS.md#yêu-cầu-cài-đặt).

## OpenAPI static review

OpenAPI công khai được rà soát tĩnh: 128 paths, 33 operation duy nhất (method/path) đối chiếu với 41 request trong collection; tài liệu có hash rút gọn `63dc2323…939cc5`. `python3 qa/api/test_collection.py`: 3 offline Python tests PASS, exit 0 tại source `74c8ea16b05733a2e5620dc48f3c52cc6867c3b6`; log [api-contract-74c8ea1.log](../../qa-artifacts/2026-10-22/api-contract-74c8ea1.log). Sơn chưa có API host/account; đây không phải kiểm tra Postman import, API business hay backend.

## Fixture generator

**FIXTURE_TOOL_TESTED_SHA:** `f5e225a5d4aa5d8e8e366770eb2bb4b0212621a6`. Parent đã chạy `python3 -m unittest discover -s qa/fixtures -p 'test_*.py' -v` — 6 test, exit 0; và `python3 qa/fixtures/generate_fixtures.py` — 20 file verified, exit 0. Đây chỉ là kiểm tra generator/fixture.
