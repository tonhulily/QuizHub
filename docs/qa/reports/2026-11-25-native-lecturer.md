# Native preview retest — Lecturer — 2026-11-25

## Môi trường

- Source app SHA: `d89a8d660d93842475b694100ccef1fdf783ed9e`. Workspace HEAD tại ngày chạy có thêm thay đổi tài liệu `fa553ab88243f32bdcaba36bb2935155456bad5c`; binary kiểm thử vẫn là build source SHA nêu trên.
- Package: `vn.edu.hust.quizhub.qa.retest`; APK SHA-256 `6e77ccf5ff4a81dd55f7cbe9b0637325fbf547bde48bd1cc03cce7d77a11cf4d`. Coordinator ghi nhận cài đặt thành công (install `exit 0`), `pm path` `exit 0`, hash APK cài khớp.
- Thiết bị: RMX3370, Android 13 emulator; không ghi serial/device ID. Thao tác qua Mobile MCP UI. API là preview backend nội bộ app; không phải API thật.

## Kết quả

**PASS 6 · FAIL 0 · WAITING 0 · BLOCKED 0 · NOT RUN 1** (7 assertions; quyền thông báo tách riêng).

| Case | Trạng thái | Kết quả quan sát / giới hạn | Evidence |
|---|---|---|---|
| L-QB-01C — gửi phiên QA hợp lệ | PASS | Tạo và gửi `QA2411 AVL review`, lớp 171146, 3 câu; app trở về `Phiên của tôi`, hiện trạng thái `Chờ duyệt` và thông báo `Đã gửi phiên đề xuất, chờ giảng viên duyệt.` | [submission-created.png](../evidence/2026-11-25/native-lecturer/submission-created.png) |
| L-QB-02 — phương án trùng | PASS | Khi câu 3 có phương án C trùng A, gửi form hiện `Câu 3: có hai phương án trùng nhau.` Sau khi bỏ phương án trùng, gửi thành công phiên QA. | [duplicate-option-validation.png](../evidence/2026-11-25/native-lecturer/duplicate-option-validation.png), [submission-created.png](../evidence/2026-11-25/native-lecturer/submission-created.png) |
| L-QB-03 — sửa, huỷ xoá, xác nhận xoá | PASS | Đổi tiêu đề thành `QA2411 AVL review edited`, bấm `Lưu` và thấy `Đã lưu thay đổi.`; mở xoá, chọn `Huỷ` và phiên còn trong chi tiết; mở lại, xác nhận `Xoá`, thấy `Đã xoá phiên.` và phiên QA biến khỏi danh sách. Chỉ phiên QA mới bị xoá. | [submission-edit-form.png](../evidence/2026-11-25/native-lecturer/submission-edit-form.png), [submission-edit-saved.png](../evidence/2026-11-25/native-lecturer/submission-edit-saved.png), [submission-delete-confirm-dialog.png](../evidence/2026-11-25/native-lecturer/submission-delete-confirm-dialog.png), [submission-delete-cancelled.png](../evidence/2026-11-25/native-lecturer/submission-delete-cancelled.png), [submission-deleted.png](../evidence/2026-11-25/native-lecturer/submission-deleted.png) |
| L-AI-02 — apply trên câu QA | PASS | Mở AI refine từ câu 1 của phiên QA mới, dùng preset `Viết lại đề cho rõ ràng, ngắn gọn`; xác nhận dialog `Áp dụng bản AI?`. Sau khi xác nhận, app hiện `Đã cập nhật câu hỏi theo bản gợi ý.` và nội dung câu QA có lời giải được tạo. Không dùng Q101 hay câu seed làm target. | [ai-suggestion-qa.png](../evidence/2026-11-25/native-lecturer/ai-suggestion-qa.png), [ai-apply-confirmation.png](../evidence/2026-11-25/native-lecturer/ai-apply-confirmation.png), [ai-apply-qa-result.png](../evidence/2026-11-25/native-lecturer/ai-apply-qa-result.png) |
| L-EX-01D — export preview handoff | PASS | Từ đề mẫu ID 1 chọn `Xuất file`; Chrome mở `example.com/preview/exam-1.pdf` và trang hiển thị nội dung cho biết example.com dành cho ví dụ tài liệu, không phải dịch vụ. Đây chỉ xác nhận UI handoff/feedback của URL giả; không tải hoặc xác minh file thật. | [export-sheet.png](../evidence/2026-11-25/native-lecturer/export-sheet.png), [export-preview-url-handoff.png](../evidence/2026-11-25/native-lecturer/export-preview-url-handoff.png) |
| PW-02 — invalid character và mismatch | PASS | Với giá trị QA giả, mật khẩu mới chứa `!` hiện `Mật khẩu không được chứa ký tự đặc biệt hoặc khoảng trắng.`; ở form mới, hai giá trị chữ-số hợp lệ nhưng khác nhau hiện `Mật khẩu nhập lại không khớp.` Không nhấn cập nhật với cặp hợp lệ; mọi giá trị đều che trong ảnh. | [password-invalid-chars.png](../evidence/2026-11-25/native-lecturer/password-invalid-chars.png), [password-mismatch.png](../evidence/2026-11-25/native-lecturer/password-mismatch.png) |
| L-OS-01 — prompt quyền thông báo tự nhiên | NOT RUN | Coordinator quan sát Android 13 hiện prompt xin quyền khi khởi chạy trước khi giao lease; không ai chọn Allow/Deny trong phần quan sát được. Khi tôi nhận lease, app đã ở Home và prompt không còn. Không ép hiện lại, không vào Settings hệ thống; chưa có ảnh prompt phù hợp nên không kết luận lựa chọn hoặc kết quả quyền. | — |

## Tình trạng tại bàn giao

- App vẫn cài, đang ở Home lecturer. Phiên `QA2411 AVL review edited` được tạo rồi xoá qua UI; danh sách `Chờ duyệt` sau xoá chỉ còn fixture seed. Không kiểm tra API thật.
- AI apply được xác nhận từ chi tiết câu QA trước khi xoá phiên. Preview backend có thể giữ thay đổi trong RAM; không suy ra dữ liệu server hoặc thay đổi fixture seed.
- Export mở Chrome tới URL ví dụ; đã quay lại app, không tải file. Password form đóng sau khi chỉ kiểm tra validation; không đổi mật khẩu.
- Không dùng install/build/ADB, không đổi source/dependencies/global settings, không commit/push.
