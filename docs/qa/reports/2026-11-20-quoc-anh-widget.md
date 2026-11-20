# Widget QA rerun — Quốc Anh — 20/11/2026

## Phạm vi và môi trường

- Rerun chỉ dùng isolated workspace `.qa-tools/quoc-anh-native-20261119/workspace`; root QA checkout vẫn ở `qa/khanhson2005`, HEAD `12dd97257052122db1305c828d3c0c9f6d5d62e4`.
- Nguồn trong workspace khớp checkpoint `447ecf394894627e498df08464466f16a12e3ef6` cho các file `lib/`, `assets/`, `test/`, `pubspec.yaml` và `pubspec.lock`, ngoại trừ đúng import `CupertinoPageTransitionsBuilder` trong `lib/core/design_system/app_theme.dart` đã được duyệt và ghi ở report native build ngày 19/11. SHA-256 của file patched: `e90ca86344996f7ebb52d86d9e6fdf8b3755fc3213925e043c499efabef94809`.
- `pubspec.lock` SHA-256: `59611bad141bbf6af7aba78f1f03dbb05c4e62d03d69c0c5d9c379480d9ebc4f`.
- Linux x86_64, Flutter 3.47.9, Dart 3.13.7. Dùng PUB_CACHE sẵn có `.qa-tools/pub-cache`, task-local XDG, `CI=true`, `FLUTTER_SUPPRESS_ANALYTICS=true`, `FLUTTER_SKIP_UPDATE_CHECK=true`. Không chạy pub get/build/install/device/API.
- Test là widget/unit với fixture và mock. Đây không phải API hoặc thiết bị thật.

## Kết quả

1. Lệnh `flutter test --no-pub --reporter expanded test/features/messenger_ui_test.dart test/features/chat_navigation_test.dart test/shared/comment_reactions_test.dart test/features/blocking_test.dart` — **exit 0**, `00:10 +25: All tests passed!`. Đây là kết quả hoàn tất của lượt 20/11; kết quả provisional Flutter 3.41.6 và partial lượt trước không được cộng vào.
2. Lệnh `flutter test --no-pub --reporter expanded test/qa/ui_layout_regression_test.dart` — **exit 1**, `00:05 +2 -5: Some tests failed.`

Flutter test runner cần bind loopback. Lượt đầu targeted trong sandbox không load được test (socket `127.0.0.1` bị từ chối, exit 1); targeted và layout được chạy lại với local loopback access được cấp hẹp. Không có thay đổi source giữa các lượt.

## Các quan sát layout

- `conversation list: search/filter remain usable with long rows`: test mong không có layout exception; thực tế `RenderFlex` overflow 161 px bên phải ở `conversations_view.dart:256`, và `EmptyView` overflow 341 px bên dưới ở `state_views.dart:143`, với viewport nhỏ và text scale 2 như test thiết lập. Đây là layout candidate QH-QA-010/011 trong harness, chưa xác nhận trên thiết bị.
- `feed: long author/post text does not cover available actions`: test mong không có layout exception; thực tế có bốn horizontal `RenderFlex` overflow 71, 67, 179 và 123 px tại `post_card.dart:479`. Đây là layout candidate QH-QA-012 trong harness, chưa xác nhận trên thiết bị.
- `comments: long root/reply text and input fit narrow sheet`: lỗi test `Bad state: No element` tại `ui_layout_regression_test.dart:316` trong thao tác scroll/tìm element.
- `closing comments sheet while reaction is pending is safe`: finder mong đúng một nút “Thích”, thực tế tìm thấy 0 tại test line 353.
- `exam generator: required-field feedback remains reachable`: lỗi `Bad state: No element` trong `dragUntilVisible` tại test line 395.

Ba lỗi finder/scroll được ghi nhận như candidate của test harness. Không có đủ bằng chứng để lập bug sản phẩm hoặc suy ra behavior mong muốn trên thiết bị. Suite có hai case pass: chat composer với tên/tin dài và question form submit error.

Native baseline riêng do coordinator cung cấp: chat keyboard ở 360×800, font scale 1 cho thấy matching/long empty/cancel states và không thấy overflow. ColorOS từ chối thay đổi wm size/font scale 2 do quyền `WRITE_SECURE_SETTINGS`/`WRITE_SETTINGS`; physical size 1080×2400 và font scale 1 giữ nguyên, nên native narrow-layout check **BLOCKED**. Điều này không đổi trạng thái các layout candidates từ widget run.

## Evidence và lệnh

- Transcript excerpt (không phải full raw log): [results.txt](../evidence/2026-11-20/quoc-anh-widget/results.txt). Bao gồm lệnh, môi trường, source/patch/lock hashes, setup viewport/text scale, diagnostics đã chọn và native-check boundary từ coordinator.
- Log đầy đủ targeted: `qa-artifacts/2026-11-20/quoc-anh-widget/targeted-widget-tests.log`; exit code: `targeted-widget-tests.exit`.
- Log đầy đủ layout: `qa-artifacts/2026-11-20/quoc-anh-widget/ui-layout-regression.log`; exit code: `ui-layout-regression.exit`.
- Lượt socket bị sandbox từ chối không được giữ thành log riêng; kết quả cuối chỉ tính lượt rerun có loopback.
- Lệnh thực thi có timeout 180 giây, từ workspace cô lập:

```bash
timeout 180s ../../sdk-3.47.9/flutter/bin/flutter test --no-pub --reporter expanded test/features/messenger_ui_test.dart test/features/chat_navigation_test.dart test/shared/comment_reactions_test.dart test/features/blocking_test.dart
timeout 180s ../../sdk-3.47.9/flutter/bin/flutter test --no-pub --reporter expanded test/qa/ui_layout_regression_test.dart
```

- Không có screenshot được tạo/capture trong các lượt widget này. Transcript excerpt được giữ trong evidence; full raw logs nằm trong ignored `qa-artifacts/`. Evidence chỉ phản ánh local widget harness, không phải repro API hoặc native-device.
