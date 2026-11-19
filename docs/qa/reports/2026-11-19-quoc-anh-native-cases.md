# Kịch bản native — Quốc Anh, 19/11/2026

> Cập nhật trạng thái hiện tại: APK đúng đã build, install/launch tới Home rồi được gỡ theo yêu cầu sau khi phiên làm việc bị ngắt. Chưa ghi nhận crash mới của app QA. Các acceptance case bên dưới vẫn NOT RUN; xem [resume handoff](2026-11-19-quoc-anh-resume.md).

## Điều kiện và trạng thái

- Mục đích: kịch bản thao tác thủ công trên Android cho preview UI; không kiểm tra backend thật. Các case hiện **NOT RUN**; APK đúng đã được chạy tới Home, nhưng các bước acceptance trong kịch bản chưa thực hiện. QA package đã gỡ.
- Checkout ghi nhận: `qa/khanhson2005`, source hiện tại `447ecf394894627e498df08464466f16a12e3ef6`. Đây chưa phải `TESTED_SHA` cho native run. Ghi lại SHA source thực tế của APK sau khi coordinator cung cấp.
- Fixture mặc định của `lib/main_preview.dart`: tài khoản hiện tại duy nhất là Nguyễn Văn An, `user_id=1`; vai trò mặc định `STUDENT`, `PREVIEW_ROLE=LECTURER` chỉ đổi role. Lan là `user_id=2`, Minh là `user_id=3`. Không có chuyển tài khoản phía UI. PreviewChat lưu khóa theo `user_id` hiện tại; không giả định chạy APK lần hai sẽ thành Lan.
- Dữ liệu bài/reaction/quan hệ/chat chỉ bền qua restart khi preview được khởi tạo với SharedPreferences; ảnh bài preview là URL giả. Các seed comments mặc định: bình luận gốc do Minh (`id 3`), reply do An (`id 1`), comment thứ hai do Lan (`id 2`); tạo reply với cùng target/post mới cần dùng bài do An tạo. Không kết luận backend.
- Ghi nhận lượt hiện tại: source BASE `447ecf394894627e498df08464466f16a12e3ef6` cộng import Cupertino được duyệt trong isolated workspace; Flutter 3.47.9 / Dart 3.13.7; device RMX3370 Android 13/API 33; package `vn.edu.hust.quizhub.qa.quocanh`; APK SHA-256 `755b5deaf26c70f781a0055167fba5e4a29d544a8697a829772c26981654a120`. Install exit 0, cold launch exit 0, Home observed, rồi uninstall thành công (`pm path` exit 1, package absent). Đây không phải `TESTED_SHA` pristine main. Không dùng APK cũ SHA `588…` hoặc gán các test case là đã chạy.
- Readiness lịch sử: Windows ADB shim `timeout 20s adb devices -l` ban đầu báo unauthorized, sau đó nhận RMX3370 khi user accept USB; Mobile MCP cũng liệt kê thiết bị Android 13. Linux ADB sandbox gặp lỗi bind 5037 và không thấy thiết bị. Không ghi serial/device ID. Lượt native hiện tại đã hoàn tất startup/Home và cleanup; các case chi tiết vẫn NOT RUN.
- Evidence nếu chạy: `docs/qa/evidence/2026-11-19/quoc-anh-native-ui/`; log/record tạm: `qa-artifacts/2026-11-19/quoc-anh-native-cases/`. Không xóa ảnh lỗi; redact thông tin cá nhân. Không clear app data/uninstall trước khi kiểm tra persistence. Coordinator quản lý install/uninstall.

## POST-FLOW-01 — tạo/sửa, nhất quán màn, whitespace

**Trạng thái:** NOT RUN; native hiện BLOCKED. Preview UI không chứng minh lưu/visibility phía server.

1. Đăng nhập preview mặc định (An, id 1). Từ composer tạo bài có sentinel duy nhất, ví dụ `QA-POST-1911-A`, visibility Công khai; lưu ID/nội dung hiển thị và chụp feed.
2. Mở chi tiết bằng cách chạm vùng trống của PostCard (không bấm avatar, nút tác vụ hay vùng bình luận). Ghi nhận trang Bài viết.
3. Mở menu ba chấm → Chỉnh sửa. Đổi sentinel thành `QA-POST-1911-B`, đổi visibility sang Bạn bè, lưu. Kiểm tra detail và kéo làm mới; nội dung mới và nhãn visibility hiện đúng.
4. Về feed, vào Trang cá nhân của tôi và tìm đúng bài; mở lại detail. Tắt hẳn app qua app switcher rồi mở lại (không force-stop/clear data ở bước đầu); kiểm tra cùng bài và sentinel B ở feed, profile và detail.
5. Tạo bài thứ hai `QA-POST-1911-ONLYME`, visibility Chỉ mình tôi. Kiểm tra trong tài khoản hiện tại/profile; restart và xác nhận còn. Không có user-switch trong fixture nên không kiểm tra quyền từ góc nhìn người khác.
6. Nếu media picker khả dụng và có fixture ảnh hợp thức, kèm ảnh ở bài đầu, sau đó khi edit gỡ hoặc thay ảnh; xác nhận preview hiển thị media giả sau restart. Nếu picker không có media fixture, ghi bước media NOT RUN riêng, không chặn nội dung/visibility.

**Expected/nguồn:** cập nhật nội dung/visibility/media tồn tại qua reload/relaunch và đồng nhất feed/profile/detail; whitespace mở detail. [post_preview.md](../post_preview.md), POST-02 [TEST_CASES.md](../TEST_CASES.md), `lib/features/post/create_post_view.dart`, `lib/features/post/post_detail_view.dart`, `lib/shared/post/post_card.dart`. Chỉ UI/client preview. Evidence: ảnh trước/sau, thao tác whitespace, feed/profile/detail sau relaunch, package+SHA.

## COMM-LIKE-01 — reaction gốc/reply độc lập, persistence

**Trạng thái:** NOT RUN; native hiện BLOCKED. API acceptance BLOCKED; enum/metadata COMMENT còn WAITING xác nhận owner.

1. Dùng bài preview của An ở POST-FLOW-01 hoặc tạo bài riêng để mở sheet Bình luận. Chụp số bình luận trước.
2. Ở comment gốc do Minh tạo, bấm Thích một lần: nút bật/count tăng. Bấm lại: tắt/count hoàn nguyên. Xác nhận số comment bài không đổi.
3. Mở reply của comment gốc; reply seed do An tạo (chính user hiện tại). Toggle reaction ở reply; đóng/mở lại sheet, xác nhận trạng thái riêng. Toggle lại reaction ở comment gốc, xác nhận reply không đổi.
4. Đóng sheet rồi mở lại; restart app và mở lại cùng bài. Kiểm tra reaction của sample comments còn trạng thái cuối đã đặt. Chụp trước/sau.

Không ép lỗi mạng, pending request hoặc khẳng định rollback/payload trên native preview trừ khi coordinator cung cấp môi trường probe phù hợp. Preview lưu reaction local; không suy diễn API. Nguồn: [comment_reactions.md](../comment_reactions.md), `lib/dev/preview_backend.dart` (`_sampleCommentId`, `_commentReactionFields`), `lib/shared/comment/comments_sheet.dart`. Evidence: trạng thái/count gốc và reply, comment count, sau relaunch.

## CHAT-DEL-01 — thu hồi/xoá phía tôi/back/relaunch/menu

**Trạng thái:** BLOCKED cho hai phía/backend; NOT RUN cho UI preview đơn lẻ.

Preview hiện chỉ đăng nhập An (id 1); chat fixture seed direct peer Lan (id 2) và Minh (id 4), mỗi cuộc có 25 tin cũ, nhưng không có phiên Lan điều khiển được từ cùng app. Không tạo/không tuyên bố kết quả hai phía bằng cách cài cùng fixture lần hai.

1. Sau khi coordinator xác nhận build/package, mở Tin nhắn → hội thoại Lan. Dùng composer gửi `QA-CHAT-OLDER-1911`; xác nhận đã gửi và ghi nhận đây là older-visible sentinel.
2. Gửi message mới hơn `QA-CHAT-REVOKE-1911` từ An (sender id 1). Nhấn giữ tin này → Thu hồi với mọi người; xác nhận nếu có. Kiểm tra placeholder “Tin nhắn đã thu hồi”. Nhấn giữ placeholder: menu chỉ còn Xoá ở phía tôi; chụp menu.
3. Chọn Xoá ở phía tôi. Rời hội thoại bằng Back về danh sách; summary của An phải lùi về `QA-CHAT-OLDER-1911`, không còn trỏ revoked/stale. Đóng hẳn app, mở lại, vào Tin nhắn → Lan; xác nhận placeholder đã gỡ phía An và summary vẫn trỏ sentinel cũ.
4. Peer side vẫn **BLOCKED** vì fixture chỉ có một tài khoản điều khiển được: không khẳng định Lan giữ placeholder hoặc summary phía Lan. Ghi nhận nếu gửi mock không thành công; không thay fixture/runtime.

Nguồn: [chat.md](../chat.md) mốc 1 bước 4 và phần preview persistence; `lib/dev/preview_chat.dart` seed sender theo parity và peer; `lib/features/chat/view/conversations_view.dart`, `lib/features/chat/view/chat_detail_view.dart`. Evidence: ảnh menu trước/sau revoke, placeholder, list summary, hội thoại sau relaunch; ghi rõ giới hạn một tài khoản.

## REL-LIST-01 — danh sách preview, confirm/cancel/block

**Trạng thái:** UI preview **NOT RUN**; APK/thiết bị đã sẵn sàng ở lượt hiện tại nhưng case này chưa được thực hiện. Không có API/error injection native.

1. Profile của tôi (An id 1) → chạm số Người theo dõi. Preview mặc định seed followers id 2,4,5; kiểm tra tên theo thứ tự/nhãn và kéo làm mới. Quay lại profile.
2. Chạm số Đang theo dõi. Mặc định danh sách trống (`_following={}`); tạo item bằng cách vào tìm kiếm/hồ sơ một người mẫu (ví dụ Lan id 2), bấm Theo dõi, quay lại danh sách. Refresh; xác nhận có item.
3. Trên item, chọn Bỏ theo dõi; tại dialog chọn Hủy và xác nhận item còn. Lặp lại, xác nhận Bỏ theo dõi; xác nhận item biến mất. Trở về profile, refresh count.
4. Từ hồ sơ người mẫu chặn Lan hoặc user mẫu id 2; về profile của An → menu ba chấm → Người đã chặn. Xác nhận Lan xuất hiện; item blocked không mở profile. Chọn Bỏ chặn → Hủy, item còn; lặp và xác nhận, item mất.
5. Preview trả danh sách một trang (`has_next=false`) và không cung cấp lỗi có thể chủ động kích hoạt. Pagination, API error/giữ dòng khi lỗi, server count, side effect unblock vẫn NOT RUN/BLOCKED; không thay bằng giả lập lỗi ngoài app.

Nguồn: [relationships.md](../relationships.md), `lib/features/profile/view/my_profile_view.dart`, `lib/features/friends/view/relationship_users_view.dart`, `lib/dev/preview_backend.dart` (`_followers={2,4,5}`, `_following={}`, `/blocks`). Evidence: list trước/sau cancel/success, profile count; alias/ID fixture only.

## QH-QA-010 / QH-QA-012 — narrow, text scale 2.0, keyboard

**Trạng thái:** NOT RUN, ứng viên UI chưa phải bug. APK/device đã có ở lượt hiện tại; case chưa thực hiện. Candidate compile/layout observations chưa phải bug đã xác nhận.

Thiết lập host chuẩn trong lần chụp: app thật, `AppTheme.lightTheme`, Scaffold/SafeArea theo màn host. Đặt viewport Android 320×640 nếu device/test harness hỗ trợ; bật font size/text scale 2.0 bằng accessibility settings. Coordinator sẽ ghi lại giá trị gốc, áp dụng và khôi phục device settings. Ghi loại bàn phím thực tế quan sát được, không mặc định Gboard. Ghi kích thước thật, display/font setting, keyboard và OS. Không chụp widget test thiếu host.

- **QH-QA-010 chat filter:** Tin nhắn → focus ô tìm kiếm → nhập chuỗi dài nhưng có kết quả và chuỗi không có kết quả; chuyển Tất cả/Chưa đọc nếu còn thấy; quan sát app bar, field, filter chip/empty state và list khi keyboard mở. Cuộn danh sách rồi đóng/mở keyboard; ghi overflow, che nút, cắt chữ hoặc layout bình thường theo quan sát.
- **QH-QA-012 PostCard actions:** mở feed có PostCard → mở bình luận và đóng; mở menu ba chấm; xem hàng action khi màn hẹp/scale 2.0 và keyboard mở (focus ô soạn bình luận nếu có). Ghi clipping/overflow, khả năng bấm, và nội dung bị keyboard che. Không đánh giá keyboard ở PostCard nếu không có text field đang mở.
- Sau narrow run, lặp trên cấu hình màn thông thường cùng host để phân biệt lỗi bố cục khỏi host setup. QH-QA-011 chỉ thêm nếu shared empty state xuất hiện tự nhiên; không phải phần bắt buộc.

Nguồn: [next-session](2026-11-19-quoc-anh-next-session.md), `lib/features/chat/view/conversations_view.dart`, `lib/shared/post/post_card.dart`, `docs/qa/evidence` host correction QH-QA-009. Evidence mỗi case: screenshot/video với setting, foreground package, SOURCE_SHA; mọi kết luận chỉ trên run quan sát.

## Phiếu ghi kết quả khi thực thi

Mỗi case ghi riêng: `CASE_ID`, `STATUS`, `SOURCE_SHA`, `MAIN_SNAPSHOT` nếu có, Flutter/Dart, build/install command + exit code và APK SHA-256, QA package, device model/OS/API, mock/backend (preview local; API host none), bước thực hiện, expected/source, actual, evidence relative path, cleanup do coordinator thực hiện. Chưa có các dữ liệu này thì giữ **NOT RUN/BLOCKED**; không ghi PASS.
