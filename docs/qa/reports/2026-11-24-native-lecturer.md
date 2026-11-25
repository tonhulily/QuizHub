# Native preview retest — Lecturer — 2026-11-24

## Môi trường

- Source SHA: `d89a8d660d93842475b694100ccef1fdf783ed9e`.
- App: `vn.edu.hust.quizhub.qa.retest`, lecturer artifact SHA-256 `6e77ccf5ff4a81dd55f7cbe9b0637325fbf547bde48bd1cc03cce7d77a11cf4d`.
- Thiết bị: RMX3370 Android 13 emulator; serial/device ID không ghi trong report. Hệ thống điều khiển: Mobile MCP UI; không chạy build/install/ADB command trong pha này.
- API host: preview backend trong app (`lib/main_preview.dart`), không phải API thật. Không có exit code cho thao tác UI.
- Phạm vi: các case lecturer được giao từ checklist học thuật, menu và password validation. Mọi kết quả PASS bên dưới chỉ xác nhận UI/preview trên artifact này.

## Kết quả

**PASS 12 · FAIL 0 · WAITING 1 · BLOCKED 0 · NOT RUN 6** (19 assertion-level cases; các assertion được tách để không gộp trạng thái chạy dở).

| Case | Trạng thái | Kết quả quan sát / giới hạn | Evidence |
|---|---|---|---|
| L-QB-01A — gửi form trống | PASS | `Gửi` chặn form và báo `Hãy chọn lớp học phần.` | [lecturer-qb-validation-empty.png](../evidence/2026-11-24/native-lecturer/lecturer-qb-validation-empty.png) |
| L-QB-01B — dưới 3 câu | PASS | Sau khi chọn lớp 171146 và nhập dữ liệu cho một câu, submit hiện `Phiên phải có ít nhất 3 câu hỏi.` | [lecturer-qb-min-questions-validation.png](../evidence/2026-11-24/native-lecturer/lecturer-qb-min-questions-validation.png) |
| L-QB-01C — gửi phiên QA hợp lệ ≥3 câu | NOT RUN | Đã mở form QA2411, chọn lớp 171146, nhập tiêu đề và bắt đầu câu 1 (nội dung `QA2411 AVL search complexity?`, phương án A `O(log n)`, B `O(n)rO(n log n)`); chưa hoàn thiện đủ ba câu hoặc gửi. Draft chưa lưu. User yêu cầu dừng do quota. | — |
| L-QB-02 — duplicate answer options | NOT RUN | Chưa tạo ba câu hoặc submit duplicate. User yêu cầu dừng do quota trước khi kiểm tra. | — |
| L-QB-03 — sửa/xoá phiên QA | NOT RUN | Không có session QA đã lưu để sửa/xoá. Draft chưa lưu; fixture `Bảng băm và xử lý đụng độ` hoặc `Bộ nhớ ảo` không bị thay đổi. User yêu cầu dừng do quota. | — |
| L-QB-04 — answer/rating/statistics | PASS | Trong `Ôn tập cây cân bằng AVL`, chọn B cho Q101 rồi `Nộp đáp án`: hiện `Chính xác!` và lời giải AVL. Gửi đánh giá 4 sao; tab `Thống kê câu hỏi` hiện dữ liệu preview, gồm 51 lượt, 59% đúng, 3 đánh giá. | [lecturer-qb-answer-correct.png](../evidence/2026-11-24/native-lecturer/lecturer-qb-answer-correct.png), [lecturer-qb-statistics.png](../evidence/2026-11-24/native-lecturer/lecturer-qb-statistics.png) |
| L-QB-05 — lọc môn/câu/empty state | PASS | Qbank lọc IT3070 hiển thị phiên/câu phù hợp; truy vấn `IT3011_NOHIT_2411` hiện `Không tìm thấy phiên phù hợp`. Kết quả thuộc preview. | [lecturer-qb-no-results.png](../evidence/2026-11-24/native-lecturer/lecturer-qb-no-results.png) |
| L-EX-01A — thiếu môn | PASS | Bấm `Sinh đề` khi chưa chọn môn hiện `Hãy chọn môn học.` | — |
| L-EX-01B — sinh đề/xem đáp án | PASS | Chọn IT3011/lớp 171146, để count 20 và sinh đề; preview báo thành công, sinh 3 câu và hiện `Ngân hàng chỉ có 3/20 câu phù hợp`. Nút `Hiện đáp án` đổi thành `Ẩn đáp án`. Đề được tạo là record preview số 5000. | [lecturer-exam-preview-generated.png](../evidence/2026-11-24/native-lecturer/lecturer-exam-preview-generated.png) |
| L-EX-01C — chọn export | PASS | Mở `Xuất PDF / Excel`; quan sát PDF và A4 mặc định. | — |
| L-EX-01D — xuất preview | NOT RUN | Chưa bấm `Xuất file`; pha tiếp tục bị dừng theo yêu cầu quota. | — |
| L-AI-01A — refine suggestion | PASS | Gửi prompt gợi ý lời giải; preview trả `Bản gợi ý của AI`, `Không phát hiện ảo giác`, confidence 92%, model `preview-model`. Đây là response tĩnh/giả lập. | [lecturer-ai-suggestion.png](../evidence/2026-11-24/native-lecturer/lecturer-ai-suggestion.png) |
| L-AI-01B — compare | PASS | `So sánh` mở hai cột `Bản gốc`/`Bản AI` và tô phần khác nhau. | [lecturer-ai-compare.png](../evidence/2026-11-24/native-lecturer/lecturer-ai-compare.png) |
| L-AI-01C — discard | PASS | Đóng comparison và chọn `Bỏ qua`; app trở về exam preview, suggestion không được áp dụng. | [lecturer-ai-suggestion.png](../evidence/2026-11-24/native-lecturer/lecturer-ai-suggestion.png) |
| L-AI-02 — apply | NOT RUN | Không áp dụng lên Q101 vì đó là fixture gốc; chưa có câu QA/session hợp lệ. User yêu cầu dừng trước khi tạo và áp dụng dữ liệu QA. | — |
| M-01 — app info / exit cancel | PASS | About dialog hiện `1.0 (1)` và đúng Package ID QA. `Thoát QuizHub?` → `Hủy` giữ app foreground. | [lecturer-app-info.png](../evidence/2026-11-24/native-lecturer/lecturer-app-info.png) |
| PW-01 — empty required validation | PASS | `Cập nhật mật khẩu` với form trống hiện required errors cho hiện tại, mới và xác nhận. Không gửi cặp mật khẩu hợp lệ. | [lecturer-password-validation-empty.png](../evidence/2026-11-24/native-lecturer/lecturer-password-validation-empty.png) |
| PW-02 — invalid/mismatch validation | NOT RUN | Chưa nhập biến thể invalid/mismatch; pha tiếp tục bị dừng theo yêu cầu quota. | — |
| PW-03 — successful password change | WAITING | Preview backend không route change-password. Không gửi form hợp lệ; không thể xác nhận thay đổi credential. | — |

## Tình trạng tại bàn giao, trước cleanup

- App vẫn cài. Sau khi owner mở khoá, quay lại Home lecturer; bắt đầu draft QA2411 trong form đề xuất. Lần gọi chạm `Thêm câu hỏi` bị ngắt bởi yêu cầu dừng quota, không có kết quả sau thao tác đó; không gọi lại để kiểm tra. Không lưu session QA, không sửa/xoá fixture. Preview RAM vẫn có câu trả lời/đánh giá Q101 và exam preview 5000. Không uninstall, reset, cài lại hay đổi role.
- Không lưu thêm screenshot trong pha tiếp tục; các ảnh evidence liệt kê ở trên giữ nguyên.
- Draft tạo câu hỏi đã bỏ, không có Qbank session QA mới được lưu hoặc xoá. Không sửa session seed.
- Preview RAM hiện đã nhận một câu trả lời/đánh giá cho Q101 và một exam preview số 5000; không có dữ liệu server được ghi. Đây là state chưa dọn, coordinator cần tính đến trước lần retest tiếp theo.
- Không kiểm tra API thật, export file thật, AI model thật, đổi mật khẩu thành công hoặc quyền role server.

Sau bàn giao, coordinator dừng và gỡ QA app; `pm path` xác nhận package đã vắng mặt, ADB và fixture thiết bị được dọn. Xem [cleanup evidence](../evidence/2026-11-24/device-cleanup.txt).
