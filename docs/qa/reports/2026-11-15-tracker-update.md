# Ghi nhận cập nhật tracker QA — 15/11/2026

Coordinator đã cập nhật tab [TESTING LỖI](https://docs.google.com/spreadsheets/d/1URTpbSX2k_04dvurVlJUbkP2iDILs618CKItSpDxjq4/edit#gid=2122578546) và xác minh bằng CSV. Có 5 dòng mới `QH-QA-005`–`QH-QA-009` tại hàng vật lý 14–18; mỗi dòng đủ 22 cột. Tại lần ghi đầu, cả năm ở trạng thái **Open / Not retested**. Sau host-corrected rerun, hàng 18 (`QH-QA-009`) đã được sửa và đọc lại thành **Closed / Retest Pass**; hiện có 8 issue Open (`QH-QA-001..008`) và 1 Closed. Không có ID trùng, tổng cộng 9 issue rows.

Phân công và mức ưu tiên ban đầu trong sheet: `QH-QA-005` — Tố Như, Major/High; `QH-QA-006`–`QH-QA-008` — Nam, Major/Medium; `QH-QA-009` — Nam, Minor/Low (sau đó chuyển owner Sơn khi đóng harness issue). Cả hai ô `U10` và `U13` được cập nhật thành ngày `15/11/2026`; ghi chú QA được nối vào `V13` về cleanup lịch sử, compile blocker và các lỗi Nam chưa được xác nhận là backend defects. Sau đính chính, các cột cũ có thay đổi chủ ý là `U10`, `U13`, `V13`, `P13`; các ô cũ khác không đổi. Không sửa cấu trúc, validations, công thức hoặc tab khác.

Commit QA `4b76cd7047463d4fdc4b1dc6a1bfb789896ccb98` đã được push lên `origin/qa/khanhson2005`. Các evidence URLs ghim commit này (snapshot trước lần ghi tracker) được coordinator kiểm tra, đều trả HTTP 200:

- [Summary](https://github.com/tonhulily/QuizHub/blob/4b76cd7047463d4fdc4b1dc6a1bfb789896ccb98/docs/qa/reports/2026-11-15-summary.md)
- [Nam report](https://github.com/tonhulily/QuizHub/blob/4b76cd7047463d4fdc4b1dc6a1bfb789896ccb98/docs/qa/reports/2026-11-15-nam-review.md)
- [Theme compile evidence](https://github.com/tonhulily/QuizHub/blob/4b76cd7047463d4fdc4b1dc6a1bfb789896ccb98/docs/qa/evidence/2026-11-15/regression/theme-baseline.txt)
- [Nam baseline evidence](https://github.com/tonhulily/QuizHub/blob/4b76cd7047463d4fdc4b1dc6a1bfb789896ccb98/docs/qa/evidence/2026-11-15/nam/baseline-safecompletion.txt)

Đính chính sau đó được push tại QA commit `f3661a2db84c3e4fb544b1307f599b96c360e1e6`; pinned [host-correction evidence](https://github.com/tonhulily/QuizHub/blob/f3661a2db84c3e4fb544b1307f599b96c360e1e6/docs/qa/evidence/2026-11-15/nam/host-correction.txt) trả HTTP 200 và được ghi vào tracker cell P18.

Trong lần CSV readback cuối, `P15`–`P17` trỏ tới Nam report tại commit `f3661a2` (HTTP 200); baseline link cũ được giữ nhãn lịch sử và QH-QA-009 UI finding được rút lại. `P13` giữ toàn bộ URL có sẵn, bổ sung native report tại commit `f3661a2` làm context-only **BLOCKED / NOT RUN** (HTTP 200). `V13` nêu rõ QH-QA-009 đã Closed / Retest Pass. Những chỉnh sửa chỉ đổi các ô cũ `U10`, `U13`, `V13`, `P13`; các ô cũ còn lại được giữ nguyên.

`QH-QA-010`–`QH-QA-012` chưa được ghi; chờ tái hiện trên source sạch. Ba lỗi Nam đã tái hiện bằng mock/widget, không chứng minh lỗi backend. Không đổi trạng thái `PUSH-01`, `SEARCH-01` hay acceptance matrix.

## Correction sau lần ghi sheet

Sau khi rerun QH-QA-009 với đúng app test host (`AppTheme.lightTheme` + `Scaffold`/`SafeArea`), 3/3 case pass và overflow không tái hiện. Reviewer độc lập rerun thấy `All tests passed!`; đối chiếu 244 file runtime/config tracked với pristine Nam SHA cho 0 mismatch. CSV readback xác nhận hàng ổn định 18 đã được sửa thành Module=Other, IssueType=Other/harness, owner Sơn, **Closed / Retest Pass**, Fixed/Retest/UpdatedDate `15/11/2026`. Đây là đóng lỗi QA harness đã sửa và retest, không phải app fix hay lỗi của Nam. Link evidence được ghim vào P18 tại commit `f3661a2db84c3e4fb544b1307f599b96c360e1e6` và HTTP 200-verified: [host-correction evidence](https://github.com/tonhulily/QuizHub/blob/f3661a2db84c3e4fb544b1307f599b96c360e1e6/docs/qa/evidence/2026-11-15/nam/host-correction.txt).

CSV readback cuối: 9 issue rows duy nhất, trong đó 8 Open (`QH-QA-001..008`) và 1 Closed (harness `QH-QA-009`). `QH-QA-010..012` vẫn pending, chưa log.
