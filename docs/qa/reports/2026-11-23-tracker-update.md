# Cập nhật tracker QA — 2026-11-23

Coordinator cập nhật tab **TESTING LỖI** và đọc lại các ô liên quan. Có **15 issue duy nhất**: 8 Closed, 1 Ready for Retest, 6 Open. Dashboard formula hiển thị 15/6/1/8 khớp với các dòng. Không thêm issue trùng; dùng sáu hàng trống sẵn có 19–24. Chỉ ghi `userEnteredValue` vào các trường đã chọn (`I10:V17`, `A19:V24`); giữ nguyên validations, format, công thức, tab khác và status history `N/O/P/Q/V` dưới mục “Lịch sử trước 23/11”. Bảy issue đóng ngày 23/11 có ngày first-observed/fix ngày 23; QH-QA-009 giữ nguyên ngày cũ. Browser readback thấy status rows 13–23 và cột mới nhất N/O; chiều cao hàng giữ theo pattern hiện có nên chưa xác nhận mọi nội dung dài hiển thị trọn vẹn.

| Trạng thái | Issue | Ghi chú readback |
|---|---|---|
| Closed | QH-QA-001..004, QH-QA-006..009 | Bảy issue retest ngày 23/11; QH-QA-009 giữ ngày đóng cũ. Retest hiện hành dùng local unit/widget mocks/fakes. |
| Ready for Retest | QH-QA-005 | Retest Blocked: kết quả Flutter 3.41.6 không thay thế điều kiện gốc Flutter 3.47.9; chưa đánh dấu fixed. |
| Open / Retest Fail | QH-QA-010..012 | Ba UI overflow candidates từ layout widget local, chưa xác nhận native-device. |
| Open / Not Retested | QH-QA-013 | Lần đầu browser preview boot thất bại; chưa có retest. Evidence là local preview, không API/native. |
| Open / Retest Fail | QH-QA-014..015 | Hai invariant tái hiện bằng in-memory fake adapter; không có server/API hoặc credential thật. |

## Report và evidence đã ghim

Các URL dưới đây trỏ trực tiếp tới commit `ece016a7ab4565892e1b6b8d0e418da4937c403a` trên `qa/khanhson2005`:

- [Tóm tắt QA phiên](https://github.com/tonhulily/QuizHub/blob/ece016a7ab4565892e1b6b8d0e418da4937c403a/docs/qa/reports/2026-11-23-summary.md)
- [Retest issues, layout và network fake](https://github.com/tonhulily/QuizHub/blob/ece016a7ab4565892e1b6b8d0e418da4937c403a/docs/qa/reports/2026-11-23-retest.md)
- [Regression baseline/checkpoint](https://github.com/tonhulily/QuizHub/blob/ece016a7ab4565892e1b6b8d0e418da4937c403a/docs/qa/reports/2026-11-23-regression.md)
- [Web preview smoke](https://github.com/tonhulily/QuizHub/blob/ece016a7ab4565892e1b6b8d0e418da4937c403a/docs/qa/reports/2026-11-23-web.md)
- [Retest evidence excerpt](https://github.com/tonhulily/QuizHub/blob/ece016a7ab4565892e1b6b8d0e418da4937c403a/docs/qa/evidence/2026-11-23/retest/results.txt)
- [Regression evidence excerpt](https://github.com/tonhulily/QuizHub/blob/ece016a7ab4565892e1b6b8d0e418da4937c403a/docs/qa/evidence/2026-11-23/regression/results.txt)
- [Browser console excerpt](https://github.com/tonhulily/QuizHub/blob/ece016a7ab4565892e1b6b8d0e418da4937c403a/docs/qa/evidence/2026-11-23/web/console.txt)
- [Local preview failure screenshot](https://github.com/tonhulily/QuizHub/blob/ece016a7ab4565892e1b6b8d0e418da4937c403a/docs/qa/evidence/2026-11-23/web/preview-blank-body.png)

Screenshots là bằng chứng ngữ cảnh của local preview failure; không phải bằng chứng API hoặc native device. Full logs, bulk output và temporary files vẫn ở ignored `qa-artifacts/2026-11-23/`.
