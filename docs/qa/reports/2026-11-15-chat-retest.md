# DRAFT — Chat preview regression và UI retest — 15/11/2026

## Trạng thái

- Checkout/SHA rà static: `qa/khanhson2005` / `adde556e2ef6e481fd7145588db878012673b059`.
- Test hẹp đã chuẩn bị tại [chat_preview_regression_test.dart](../../../test/qa/chat_preview_regression_test.dart); **NOT RUN**. Ghi chú ban đầu rằng SDK binary chưa sẵn phản ánh thời điểm rà đầu tiên: SDK đã được restore sau đó, còn main hiện bị compile blocker; lượt probe trước bị ngắt nên test vẫn chưa chạy.
- Không chạy app/device/API thật, không cài dependency. Không sửa runtime. Kết quả dưới đây là source observation/static candidates, không phải PASS hay bug xác nhận.
- Báo cáo draft chưa được xác nhận lại sau lần test gần đây bị ngắt; chỉ các lệnh/evidence mới có log tại SHA chuẩn mới được ghi nhận khi resume.

## Regression chính: xóa riêng tin đã thu hồi và preview danh sách

**Dev-reported, QA chưa tái hiện; chỉ local/mock, không kết luận backend.** Repro dự kiến tạo một tin cũ hiển thị được, sau đó gửi tin mới, thu hồi `EVERYONE`, xác nhận placeholder ở An và Lan, rồi An xóa `ME`. Đọc history và `GET /conversations` cho cả hai user trước/sau, reload và restart dùng cùng state. Expected từ `docs/qa/chat.md:4-5,61-68`: An không còn thấy tin đã xóa và preview trỏ đến tin mới nhất còn nhìn thấy; Lan vẫn giữ placeholder thu hồi; sau reload/restart mỗi bên giữ đúng trạng thái.

Test mới bao phủ cả `PreviewBackend` persistence lẫn shared demo REST: summary phải trỏ đến `older-visible-sentinel` cho An và revoked sentinel cho Lan; history và summary của Lan không bị ảnh hưởng bởi thao tác `ME` của An. Test tạo old visible item để tránh phải suy diễn expected khi history rỗng. UI hiện render `Bắt đầu cuộc trò chuyện` khi `last_message == null` (`lib/features/chat/view/conversations_view.dart:457-459`), nhưng empty-history fallback không thuộc assertion trong test này.

Static evidence: PreviewChat list dùng `messages[id]?.lastOrNull` (`lib/dev/preview_chat.dart:286-301`); scope `ME` xóa hàng của mock (`:343-358`), còn revoke giữ placeholder. Shared demo lọc `deleted_for` theo owner (`tool/chat_demo_server.dart:268-272`), tạo `last_message` từ hàng cuối còn nhìn thấy (`:301-323`), và scope `ME` thêm owner vào `deleted_for` (`:647-676`). UI gọi `_reload()` sau khi detail route pop (`lib/features/chat/view/conversations_view.dart:146-153`), và `_reload()` gọi `PagedCubit.refresh()` (`:108-110`). Test trước đó chỉ kiểm tra history/restart, không kiểm tra conversation summary (`test/dev/shared_chat_demo_test.dart:263-318`; preview history test `test/data/preview_chat_persistence_test.dart:282-318`).

Resume command proposal (NOT RUN): `flutter test --no-pub test/qa/chat_preview_regression_test.dart`. Record source SHA, SDK, exact exit and redacted log before drawing conclusions. Keep runtime fixes outside this tester-only QA handoff; file a separate owner issue only after a reproducible runtime observation.

## Retest UI / reconnect có expected rõ

| ID / priority | Acceptance và thao tác | Static evidence; trạng thái |
|---|---|---|
| **CHAT-RET-01 · P1 / Medium · NOT RUN** | Hai phiên shared mock: gửi sentinel, An thu hồi rồi xóa `ME`; back phải refresh danh sách ngay, không cần kéo làm mới. Summary/API và UI phải trùng history theo từng user; lặp sau restart. | Acceptance `docs/qa/chat.md:4-5,61-68`; route return + refresh `lib/features/chat/view/conversations_view.dart:108-110,146-153`. Code path có vẻ chủ động refresh; chưa có widget-level assertion, chưa kết luận lỗi UI. Covered at repository/REST level by new test only, which remains NOT RUN. |
| **CHAT-RET-02 · P1 / Medium · NOT RUN** | Hai phiên shared mock: nhập draft, đưa app nền rồi resume; ngắt STOMP ngay sau gửi, reconnect, chờ history sync. Expected theo docs: draft giữ nếu chưa xác nhận; reconcile history trước resend; không tự retry/duplicate; typing/read dừng khi inactive. | Acceptance `docs/qa/chat.md:19-24,30-40`; lifecycle hooks `lib/features/chat/view/chat_detail_view.dart:69-89`; reconnect listener và `load()` `lib/features/chat/cubit/chat_detail_cubit.dart:155-180`; active/read/typing gates `:372-420`; pending confirmation/sync `:457-548`. Source có lifecycle/reconcile paths, nhưng race behavior chỉ xác minh được khi chạy. |
| **CHAT-RET-03 · P2 / Low · NOT RUN** | Màn hẹp + keyboard mở; nhập draft nhiều dòng tới 2000 ký tự, cuộn lịch sử, đóng bàn phím, Back, quay lại nếu draft chưa được gửi. Gửi 2000 ký tự thành công; 2001 bị chặn không phát request. Kiểm tra scale chữ lớn và message text dài không gây overflow, cắt mất chữ hay làm composer khuất. | UI code giới hạn composer 1–5 dòng, 2000 ký tự `lib/features/chat/view/chat_detail_view.dart:202-290`; lịch sử `ListView(reverse: true)` và keyboard drag-dismiss `:517-575`; nội dung bubble là `Text(message.content)` `lib/features/chat/widgets/chat_message_tile.dart:223-245`; Cubit chặn >2000 `lib/features/chat/cubit/chat_detail_cubit.dart:485-496`. Docs xác định giới hạn gửi và keyboard/reconnect ở `docs/qa/chat.md:19-24`; exact text scaling/Back retention chưa là acceptance riêng, ghi usability observation và hỏi owner trước khi mở bug. |

## Blockers / phân loại

- CHAT-RET-01/02/03 đều `NOT RUN`; không có device/API evidence. SDK đã được restore sau ghi chú ban đầu, nhưng lượt probe bị ngắt và main hiện có compile blocker; chưa có lần chạy nào cho các case này.
- Dev report preview vẫn là **chưa xác minh**. Shared mock source cho thấy owner filtering và UI reload đã hiện diện; đây không chứng minh preview runtime đúng hoặc backend thật sai.
- Không có static candidate nào đủ chứng cứ để gọi confirmed defect. Nếu test mới pass, đó chỉ là regression test trên local/mock tại exact SHA, không phải xác nhận API/backend.
