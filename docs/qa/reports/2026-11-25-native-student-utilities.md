# Native preview utilities — Student — 2026-11-25

## Phạm vi và môi trường

- Source app: `d89a8d660d93842475b694100ccef1fdf783ed9e`.
- Docs HEAD tại thời điểm bắt đầu lease: `f5381457571c4f3d1aec116def79f6132750f9de` (riêng source app vẫn là SHA bên trên).
- Artifact Student: `student-preview-fresh.apk`, SHA-256 `7e73007a0f1a0a641a0f60c7ee75375cb671bede178c151f9b57a7292347a718`.
- Môi trường Mobile MCP báo thiết bị loại `emulator`, tên RMX3370, Android 13; không suy ra phần cứng vật lý và không ghi serial. App preview `vn.edu.hust.quizhub.qa.retest`.
- Thao tác: `mobile_list_elements_on_screen`, `mobile_click_on_screen_at_coordinates`, `mobile_type_keys`, `mobile_swipe_on_screen`, `mobile_save_screenshot`; MCP không trả process exit code cho thao tác UI nên không gán exit code.
- Không cài lại app, đăng xuất, đổi cài đặt Android hay gửi dữ liệu ra dịch vụ ngoài. Các API preview dùng fixture trong RAM.

## Kết quả quan sát

| Case | Kết quả | Ghi nhận |
|---|---|---|
| S-SR-01 — tìm kiếm theo 6 loại | PASS | `Cấu trúc dữ liệu` trả bài viết ở `Bài viết`, phiên ở `Buổi đóng góp`, môn IT3011 ở `Môn học`; `AVL` trả câu IT3011-Q101/Q102 ở `Câu hỏi`; `Lan` trả người dùng Trần Thị Lan ở `Người dùng`; `Cấu trúc dữ liệu` ở `Tất cả` hiển thị nhiều loại kết quả. |
| S-SR-02 — không có kết quả | PASS | Query `QA-no-hit-987` hiển thị `Chưa có dữ liệu`. Ảnh: [search-no-hit.png](../evidence/2026-11-25/native-student-utilities/search-no-hit.png). |
| S-SH-01 — xu hướng và lịch sử | PASS | Chọn chip xu hướng `Cấu trúc dữ liệu` tạo lịch sử; chọn lại lịch sử `Lan`, sau đó xóa mục QA `Lan`; danh sách cập nhật và mục không còn xuất hiện. `Cấu trúc dữ liệu` và `AVL` vẫn còn trong lịch sử. |
| S-SR-03 — cuộn kết quả người dùng | PASS | Query `nguoi dung mau`, chọn `Người dùng`; sau khi cuộn, danh sách tiếp tục hiển thị các fixture kế tiếp (ví dụ người dùng số 4–9). Ảnh: [search-user-results.png](../evidence/2026-11-25/native-student-utilities/search-user-results.png). Không xác nhận tổng số kết quả/API page size. |
| S-NOT-01 — đọc một thông báo và mở target | PASS | Chạm lời mời kết bạn của Trần Thị Lan mở profile; unread count giảm từ 19 xuống 18. Chạm thông báo câu hỏi được duyệt mở chi tiết phiên mẫu ID không tồn tại trong fixture: `0 câu hỏi`, `Chưa rõ trạng thái phiên`. Đây là điều hướng UI tới target giả, không kiểm tra dữ liệu thật. |
| S-NOT-02 — đọc tất cả | PASS | Menu `⋮` → `Đánh dấu tất cả đã đọc`; header đổi thành `Bạn đã đọc tất cả thông báo`. |
| S-NOT-03 — cuộn danh sách | PASS | Cuộn qua nhiều nhóm thông báo kế tiếp; thứ tự nội dung lặp lại theo fixture và timestamp tới `Hôm qua`. Đây chỉ xác nhận list tiếp tục hiển thị khi cuộn. |
| S-NOT-04 — phân trang đủ 33 mục | NOT RUN | Chưa đếm được 20 mục đầu hoặc xác nhận điểm chuyển sang trang kế; scroll list chưa đủ bằng chứng cho pagination. Không kết luận lỗi. |
| S-PUSH-01 — master/category, lưu và mở lại | PASS | Tắt rồi bật master; đổi ACADEMIC từ tắt sang bật; lưu hiện `Đã lưu cài đặt thông báo.`. Mở lại, ảnh màn hình xác nhận master và các category đều đang bật. Đây là lưu trong preview, không phải đăng ký FCM. |
| S-PUSH-02 — giờ yên tĩnh | PASS | Đổi Bắt đầu từ `22:00` sang `21:30`, Kết thúc từ `07:00` sang `08:15`; lưu hiện `Đã lưu cài đặt thông báo.`. Mở lại thấy hai giờ vẫn giữ nguyên và quiet vẫn bật. Ảnh: [push-quiet-saved.png](../evidence/2026-11-25/native-student-utilities/push-quiet-saved.png), [push-settings-reopened.png](../evidence/2026-11-25/native-student-utilities/push-settings-reopened.png), [push-sound-vibration-reopened.png](../evidence/2026-11-25/native-student-utilities/push-sound-vibration-reopened.png) (ảnh này hiển thị đầy đủ giờ sau reopen). |
| S-PUSH-03 — âm thanh/rung | PASS | Sau khi mở lại settings, ảnh xác nhận Âm thanh tắt và Rung bật vẫn được giữ. Ảnh: [push-sound-vibration-reopened.png](../evidence/2026-11-25/native-student-utilities/push-sound-vibration-reopened.png). |
| S-PUSH-04 — Back khi có thay đổi chưa lưu | PASS | Sau khi đổi draft, Android Back hiện `Bỏ thay đổi?`; chọn `Ở lại` vẫn giữ màn hình và dialog xuất hiện lại khi Back; chọn `Bỏ thay đổi` trở về Menu. |
| S-OS-01 — quyền thông báo Android | NOT RUN | Lựa chọn/kết quả prompt tự nhiên trước đó không xác định; prompt không hiện trong lượt này. Không ép prompt và không vào Android Settings. |
| S-MENU-01 — Huy hiệu/Cửa hàng | WAITING | Chạm cả hai shortcut không mở flow; source hiện tại không gắn `onTap`, nên đây là placeholder chưa triển khai. |

## Tổng hợp

- PASS: 11
- FAIL: 0
- WAITING: 1
- BLOCKED: 0
- NOT RUN: 2

Kết quả chỉ phản ánh UI preview trên artifact và fixture đang chạy. Chưa kiểm tra API thật, quyền server, lưu trữ server, FCM, badge/shop chưa triển khai hoặc kết quả dữ liệu thật. App được để nguyên cài đặt sau khi trả lease coordinator; không dọn dữ liệu preview.

Ảnh Search, cài đặt push đã lưu/mở lại và sound/vibration được lưu tại các đường dẫn nêu trong bảng. Kết quả notification ghi theo hierarchy sau thao tác; không có ảnh riêng. Không có screenshot lỗi.
