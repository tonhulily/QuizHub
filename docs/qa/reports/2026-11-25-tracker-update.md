# Cập nhật tracker QH-QA-013 — 2026-11-25

Coordinator chỉ cập nhật tab [TESTING LỖI](https://docs.google.com/spreadsheets/d/1URTpbSX2k_04dvurVlJUbkP2iDILs618CKItSpDxjq4/edit#gid=2122578546), hàng 22 với khóa ổn định `QH-QA-013`. Không tạo issue mới, không đổi trạng thái, không sửa tab khác.

## Thay đổi và xác minh

- Giữ nguyên bằng chứng lỗi browser preview và ghi chú có sẵn. Bổ sung hai URL GitHub ghim vào QA commit `fa553ab88243f32bdcaba36bb2935155456bad5c`: [báo cáo native PREVIEW](https://github.com/tonhulily/QuizHub/blob/fa553ab88243f32bdcaba36bb2935155456bad5c/docs/qa/reports/2026-11-24-native-retest.md) và [build/startup evidence](https://github.com/tonhulily/QuizHub/blob/fa553ab88243f32bdcaba36bb2935155456bad5c/docs/qa/evidence/2026-11-24/native-build-gate.txt). Đây là bằng chứng ngữ cảnh native trên nền tảng khác; không phải retest lỗi browser.
- `V22` ghi source rút gọn `d89a8d6`, core Lecturer preview UI có 27 PASS và pha Lecturer academic có 12 PASS UI. Student APK mới chưa chạy tại checkpoint 24/11. API/FCM chưa kiểm tra. Đây là ngữ cảnh preview, không phải xác nhận API/backend hay retest browser.
- `U22` ghi ngày `25/11/2026` bằng ngày số `46351`.
- Ngay sau khi ghi, coordinator đọc lại các ô và xác nhận nội dung/chính tả, URL và ngày khớp. `I22` vẫn `Open`, `S22` vẫn `Not retested`, `T22` vẫn trống.
- Chỉ cập nhật `userEnteredValue` ở các ô được chọn; không đổi định dạng, validation, cấu trúc, chiều cao hàng hoặc nội dung tab khác.
- Ảnh browser readback viewport ở mức zoom 100% được lưu trong ignored `qa-artifacts/2026-11-25/tracker-postwrite.png` và đã được coordinator xem. Hàng 22/cột P:V hiện đúng; phần ghi chú dài bị wrap/clipped theo chiều cao cố định sẵn có. Không thay đổi kích thước hàng hay style toàn trang.

QA commit `fa553ab88243f32bdcaba36bb2935155456bad5c` đã được push riêng lên `origin/qa/khanhson2005`; GitHub xác minh hai file ghim ở trên. Ngay sau lần push đó, coordinator xác nhận working tree sạch. Native Student mới và các luồng Lecturer còn lại vẫn chưa được kiểm tra; lần cập nhật tracker này không kết luận bug đã retest hoặc được sửa.
