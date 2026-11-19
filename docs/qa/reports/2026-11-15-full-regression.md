# DRAFT · HISTORICAL, NOT RUN ON CURRENT SOURCE — Regression Flutter/UI — 15/11/2026

## Phạm vi và trạng thái

- **Run source SHA:** `238d9d9b4931ddf8dd480b073114c6e16eee25c7`, detached QA worktree; không sửa worktree.
- **Loại bằng chứng:** exploratory widget/local-mock run, không phải acceptance build hay backend/device run. Source tại SHA này đã có import Cupertino tạm thời trong `AppTheme` để biên dịch với Flutter 3.47.9; runtime fix đó đã bị loại khỏi lịch sử QA chưa push. Runtime QA hiện khớp `origin/main`; không có sửa đổi nào được áp dụng lên `main`. Không chuyển kết quả này thành PASS cho main hiện tại.
- **Môi trường:** Linux x86_64, Flutter 3.47.9 / Dart 3.13.7, mock local trên loopback; không dùng API/accounts thật, không chạy native/build.
- **Lệnh:** `flutter test --no-pub test/qa --reporter expanded` — **exit 1**, 5 pass / 5 fail. Log giữ tại `qa-artifacts/2026-11-15/regression-final/focused-238d9d9.log` (ignored, evidence nội bộ; chưa có screenshot).
- Probe được chỉnh sau lượt này để cuộn tới control trước thao tác, xác nhận hit-test/keyboard viewport và dùng demo token đúng. Những thay đổi test-only đó chưa chạy lại tại SHA sạch.
- Lượt fresh Nam UI/chat/old-issue probes tiếp theo bị ngắt và chưa có log hoàn tất; các kết quả của SHA exploratory bên dưới không thay thế retest. Không dùng báo cáo này để kết luận bug trên current main/Nam snapshot.

## Kết quả quan sát

| Probe | Kết quả | Quan sát / giới hạn |
|---|---|---|
| Preview summary sau revoke + xóa `ME` + restart | PASS trên PreviewBackend cục bộ | List summary lùi về tin cũ còn thấy sau xóa và persistence/reload giữ kết quả. Không xác nhận server thật. |
| Shared demo REST summary hai user | FAIL harness | `GET /users/me` trả 401 do fixture dùng token `local-demo-*`, trong khi `tool/chat_demo_server.dart` chỉ nhận `chat-demo-*`. Không phải lỗi backend hay ứng dụng. Token test đã được sửa trong test-only fixture; chưa retest. |
| Chat detail, keyboard/composer | PASS trong widget run | Composer/action xuất hiện ở viewport hẹp; assertion ban đầu chỉ kiểm tra màn hình đầy đủ, đã được tăng cường để kiểm tra vùng trên keyboard. |
| Conversation filters, 320×640 dp / text scale 2 | FAIL — overflow quan sát được | `RenderFlex overflowed by 161 px` tại `lib/features/chat/view/conversations_view.dart:256`, hàng filter `Tất cả / Chưa đọc`. Empty result đồng thời làm `EmptyView` tràn dọc 341 px tại `lib/core/widgets/state_views.dart:143`. Đây là lỗi render trong probe, chưa có device retest. |
| PostCard actions, 320×640 dp / text scale 2 | FAIL — overflow quan sát được | `RenderFlex overflowed` ngang 71 px tại `lib/shared/post/post_card.dart:479`; các nút action bị tràn. Probe chưa chạy lại sau khi kết quả được ghi nhận. |
| Comments long reply và exam generator | FAIL harness / NOT RUN thực chất | `ensureVisible` không cuộn tới phần tử lazy/off-screen và ném `No element`; không đủ bằng chứng về lỗi ứng dụng. Probe đã đổi sang `scrollUntilVisible`. |
| Đóng comments sheet khi reaction pending | INCONCLUSIVE | Lần đầu `tap()` nhắm control ở ngoài viewport (log cảnh báo hit-test); không chứng minh request reaction đã bắt đầu. Probe mới kiểm tra control hit-testable và đếm đúng một lần gọi fake repository; chưa retest. |
| Export launcher `PlatformException` | PASS với channel fake | Feedback hiển thị, không có exception thoát khỏi widget. Không dùng platform launcher/native. |

Các overflow là actual Flutter rendering exceptions trên widget harness. `docs/qa/comment_reactions.md` yêu cầu controls không tràn ngang ở màn hẹp; test này chưa chứng minh trải nghiệm trên thiết bị. Không có runtime fix hoặc retest, nên chưa đánh dấu resolved.

## SDK compatibility và regression rộng

Tại SHA `31edeb3541926f5a70e3ebf1ff8b5c6af20b483e`, `flutter analyze --no-pub` với SDK 3.47.9 không biên dịch được `AppTheme`: `CupertinoPageTransitionsBuilder` không còn được export từ import Material hiện có. Import Cupertino tạm thời làm focused tests biên dịch ở SHA sau; thay đổi runtime đó đã được coordinator revert để giữ main sạch. Đây là compile compatibility finding riêng; không xem là test harness issue hay fix đã giữ lại.

Coordinator báo existing suite **270/270** tại SHA `238d9d9b4931ddf8dd480b073114c6e16eee25c7`; đó là lịch sử trên source có import tạm thời, không phải kết quả của main hiện tại. Báo cáo này không chuyển kết quả đó sang SHA khác. QH-QA-001..004 và UI probes còn cần retest trên source pristine/SDK khớp lockfile; không có API, native hoặc build acceptance.

## Handoff (NOT RUN)

Không dùng báo cáo này để chọn source đích hoặc hướng dẫn sửa runtime. Import Cupertino tại SHA `238d9d9` chỉ là thay đổi exploratory đã bỏ; nó không phải acceptance evidence hay hướng dẫn áp dụng lại. Chọn source/probe theo [kế hoạch phiên sau](2026-11-19-quoc-anh-next-session.md), ghi SHA nguồn, hash test files, command/exit và log cho từng lượt. Những observation tại SHA này là historical exploratory evidence, không phải kết quả current main; lỗi harness hoặc mock-only run không chứng minh bug sản phẩm/backend.
