# Ghi nhận cập nhật tracker QA — 15/11/2026

Coordinator đã cập nhật tab [TESTING LỖI](https://docs.google.com/spreadsheets/d/1URTpbSX2k_04dvurVlJUbkP2iDILs618CKItSpDxjq4/edit#gid=2122578546) và xác minh lại bằng CSV. Có 5 dòng mới `QH-QA-005`–`QH-QA-009` tại hàng vật lý 14–18; mỗi dòng đủ 22 cột. Cả năm ở trạng thái **Open / Not retested**. Không có ID trùng, tracker hiện có tổng cộng 9 issue rows. Các issue cũ `QH-QA-001`–`QH-QA-004` vẫn **Open / Not retested**.

Phân công và mức ưu tiên ban đầu trong sheet: `QH-QA-005` — Tố Như, Major/High; `QH-QA-006`–`QH-QA-008` — Nam, Major/Medium; `QH-QA-009` — Nam, Minor/Low. Cả hai ô `U10` và `U13` được cập nhật thành ngày `15/11/2026`; ghi chú QA được nối vào `V13` về cleanup lịch sử, compile blocker và các lỗi Nam chưa được xác nhận là backend defects. CSV diff với baseline xác nhận các cột cũ khác ở `U10`, `U13`, `V13` không đổi. Không sửa cấu trúc, validations, công thức, tab khác hoặc dịch vụ khác.

Commit QA `4b76cd7047463d4fdc4b1dc6a1bfb789896ccb98` đã được push lên `origin/qa/khanhson2005`. Các evidence URLs ghim commit này (snapshot trước lần ghi tracker) được coordinator kiểm tra, đều trả HTTP 200:

- [Summary](https://github.com/tonhulily/QuizHub/blob/4b76cd7047463d4fdc4b1dc6a1bfb789896ccb98/docs/qa/reports/2026-11-15-summary.md)
- [Nam report](https://github.com/tonhulily/QuizHub/blob/4b76cd7047463d4fdc4b1dc6a1bfb789896ccb98/docs/qa/reports/2026-11-15-nam-review.md)
- [Theme compile evidence](https://github.com/tonhulily/QuizHub/blob/4b76cd7047463d4fdc4b1dc6a1bfb789896ccb98/docs/qa/evidence/2026-11-15/regression/theme-baseline.txt)
- [Nam baseline evidence](https://github.com/tonhulily/QuizHub/blob/4b76cd7047463d4fdc4b1dc6a1bfb789896ccb98/docs/qa/evidence/2026-11-15/nam/baseline-safecompletion.txt)

`QH-QA-010`–`QH-QA-012` chưa được ghi; chờ tái hiện trên source sạch. Ba lỗi Nam đã tái hiện bằng mock/widget, không chứng minh lỗi backend. Không đổi trạng thái `PUSH-01`, `SEARCH-01` hay acceptance matrix.

## Correction sau lần ghi sheet

Rerun QH-QA-009 sau khi bổ sung đúng app test host (`AppTheme.lightTheme` + `Scaffold`/`SafeArea`) đạt 3/3, không tái hiện overflow; reviewer độc lập rerun và thấy `All tests passed!`. Đối chiếu 244 file runtime/config tracked với pristine Nam SHA cho 0 mismatch. Kết quả 917 px ban đầu là false positive do harness thiếu host context. Đề xuất reclassify dòng QH-QA-009 thành **Other / harness**, owner Sơn; không phải bug sản phẩm hoặc bug của Nam. Tại thời điểm báo cáo tracker vẫn là **Open / Not retested**; chưa có sheet write đính chính. [Chi tiết repro đã chỉnh](../evidence/2026-11-15/nam/host-correction.txt).
