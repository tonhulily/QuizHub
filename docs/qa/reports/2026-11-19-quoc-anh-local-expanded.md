# QA local mở rộng — Quốc Anh (19/11/2026)

## Phạm vi và môi trường

- Checkpoint/source đã chạy: `447ecf394894627e498df08464466f16a12e3ef6` (`main` tại `08a5a2e4097923d21bbdaf7d02cb1792f2171aa3` theo chỉ định coordinator).
- Flutter 3.47.9, Dart 3.13.7, Ubuntu 24.04.4 trên WSL2; Flutter CLI trên runner này chỉ nhận Linux desktop. Đây là ghi chú môi trường của lượt local. Native run sau đó được ghi riêng ở [native UI](2026-11-19-quoc-anh-native-ui.md) và [resume handoff](2026-11-19-quoc-anh-resume.md).
- API host: không dùng; các bài data/recovery chạy với fixture, fake adapter hoặc preview. Test STOMP/core và shared demo chạy loopback server cục bộ, không phải backend thật.
- Tất cả lệnh dùng `XDG_CONFIG_HOME=.qa-tools/config XDG_CACHE_HOME=.qa-tools/cache PUB_CACHE=.qa-tools/pub-cache CI=true FLUTTER_SUPPRESS_ANALYTICS=true` và Flutter `.qa-tools/sdk-3.47.9/flutter/bin/flutter`.

## Kết quả

Lệnh đầy đủ dùng chung prefix môi trường `XDG_CONFIG_HOME=.qa-tools/config XDG_CACHE_HOME=.qa-tools/cache PUB_CACHE=.qa-tools/pub-cache CI=true FLUTTER_SUPPRESS_ANALYTICS=true .qa-tools/sdk-3.47.9/flutter/bin/flutter test --no-pub`.

| Nhóm | Đối số test | Exit | Kết quả quan sát |
|---|---|---|---|
| Core realtime + dev shared adapter/demo | `test/core/chat_realtime_test.dart test/dev/shared_chat_adapter_test.dart test/dev/shared_chat_demo_test.dart` | 0 | 15 tests passed; STOMP loopback, reconnect, demo hai phiên, thu hồi/xoá, block và media validation trong preview. |
| Data chat/block/reactions/deleted posts/feed ghost/friends/preview persistence/posts/relationship/media | `test/data/blocking_test.dart test/data/chat_test.dart test/data/comment_reactions_test.dart test/data/deleted_posts_test.dart test/data/feed_ghost_test.dart test/data/friends_test.dart test/data/preview_chat_persistence_test.dart test/data/preview_posts_test.dart test/data/relationship_lists_test.dart test/data/media_validation_test.dart` | 0 | 87 tests passed. Unit/repository/preview với fake/mock; không xác nhận API hoặc server contract. |
| Chat recovery | `test/features/chat_recovery_test.dart` | 0 | 4 tests passed, dùng fixture/mocked repository. |
| UI chat + blocking | `test/features/chat_test.dart test/features/blocking_test.dart` | 1 | Compile/load thất bại tại `lib/core/design_system/app_theme.dart:196-197`, `CupertinoPageTransitionsBuilder` không resolve trên Flutter 3.47.9. Đây là compile-only blocker đã ghi nhận là QH-QA-005; test bodies chưa chạy, không phải business failure được quan sát. |

Ba lệnh test có socket ban đầu bị Flutter harness từ chối trong sandbox (`Failed to create server socket`, errno 1); cùng lệnh được chạy lại với quyền loopback được cấp và hoàn tất thành công. Lần đầu là giới hạn harness/sandbox, không phải test/app failure.

Lệnh test trước đó không redirect stdout/stderr ra file, nên full raw logs không được lưu. [results.txt](../evidence/2026-11-19/quoc-anh-local/results.txt) lưu command, exit/count và trích đoạn kết quả cuối thực tế còn trong transcript; đây không phải full log. Không tạo log giả hoặc chạy lại test chỉ để tái tạo log.

## Mapping case

- **CHAT**: `core/chat_realtime`, `data/chat`, `data/preview_chat_persistence`, `features/chat_recovery`, `dev/shared_chat_adapter`, `dev/shared_chat_demo` — có kiểm tra client/preview về lịch sử, reconnect, xóa/thu hồi, persistence và demo hai phiên. CHAT-DEL-01 và CHAT-LIVE-01 chỉ được mô phỏng cục bộ; CHAT-BLOCK-01 client-preview có coverage ở data/demo. Tất cả acceptance với hai tài khoản/backend thật **BLOCKED**.
- **COMM**: `data/comment_reactions` xác nhận thao tác trên preview/mock và persistence; `COMM-LIKE-01` trên backend thật, trạng thái pending/error của API và enum/metadata server **BLOCKED/WAITING**.
- **POST**: `data/deleted_posts`, `data/feed_ghost`, `data/preview_posts`, `data/media_validation` gồm thao tác fixture/preview về lưu, sửa, xoá, ghost/feed và media. `POST-FLOW-01` backend visibility/đồng bộ hai tài khoản **BLOCKED**; vùng whitespace mở detail và UI layout chưa được nghiệm thu.
- **REL**: `data/blocking`, `data/friends`, `data/relationship_lists` xác nhận client/repository với dữ liệu giả; `REL-LIST-01` API thật, pagination/account data và policy side effects **BLOCKED/WAITING**.
- `QH-QA-010/012`, `QBANK-MATERIAL-01`, và `IOS-CONFIG-01`: **NOT RUN trong lượt local này**. Native startup/Home được ghi ở [native UI](2026-11-19-quoc-anh-native-ui.md); các case acceptance chi tiết vẫn chờ tiếp tục theo [resume handoff](2026-11-19-quoc-anh-resume.md).

## Giới hạn

Chạy test source tại SHA nêu trên không chứng minh luồng acceptance trên app đã build hoặc backend thật. Flutter runner không list thiết bị Android; native startup/Home và các giới hạn còn lại được ghi riêng tại [native UI](2026-11-19-quoc-anh-native-ui.md). Compile gate QH-QA-005 ngăn test UI chat/blocking chạy trong lượt local này. Không tạo screenshot ở lượt local. Không chạy lại `chat_preview_regression_test.dart` (lần trước đã 2 pass, không có thay đổi/lý do tái chạy).
