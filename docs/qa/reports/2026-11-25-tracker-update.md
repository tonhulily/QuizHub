# Cập nhật tracker QH-QA-013 và QH-QA-016 — 2026-11-25

Coordinator cập nhật hàng 22 (`QH-QA-013`) và ghi issue mới vào hàng trống 25 (`QH-QA-016`) trong tab [TESTING LỖI](https://docs.google.com/spreadsheets/d/1URTpbSX2k_04dvurVlJUbkP2iDILs618CKItSpDxjq4/edit#gid=2122578546). Không sửa tab khác.

## Thay đổi và xác minh

- Giữ nguyên bằng chứng lỗi browser preview và ghi chú có sẵn. Bổ sung hai URL GitHub ghim vào QA commit `fa553ab88243f32bdcaba36bb2935155456bad5c`: [báo cáo native PREVIEW](https://github.com/tonhulily/QuizHub/blob/fa553ab88243f32bdcaba36bb2935155456bad5c/docs/qa/reports/2026-11-24-native-retest.md) và [build/startup evidence](https://github.com/tonhulily/QuizHub/blob/fa553ab88243f32bdcaba36bb2935155456bad5c/docs/qa/evidence/2026-11-24/native-build-gate.txt). Đây là bằng chứng ngữ cảnh native trên nền tảng khác; không phải retest lỗi browser.
- `V22` ghi source rút gọn `d89a8d6`, core Lecturer preview UI có 27 PASS và pha Lecturer academic có 12 PASS UI. Student APK mới chưa chạy tại checkpoint 24/11. API/FCM chưa kiểm tra. Đây là ngữ cảnh preview, không phải xác nhận API/backend hay retest browser.
- `U22` ghi ngày `25/11/2026` bằng ngày số `46351`.
- Ngay sau khi ghi, coordinator đọc lại các ô và xác nhận nội dung/chính tả, URL và ngày khớp. `I22` vẫn `Open`, `S22` vẫn `Not retested`, `T22` vẫn trống.
- Chỉ cập nhật `userEnteredValue` ở các ô được chọn; không đổi định dạng, validation, cấu trúc, chiều cao hàng hoặc nội dung tab khác.
- Ảnh browser readback viewport ở mức zoom 100% được lưu trong ignored `qa-artifacts/2026-11-25/tracker-postwrite.png` và đã được coordinator xem. Hàng 22/cột P:V hiện đúng; phần ghi chú dài bị wrap/clipped theo chiều cao cố định sẵn có. Không thay đổi kích thước hàng hay style toàn trang.

QA commit `fa553ab88243f32bdcaba36bb2935155456bad5c` đã được push riêng lên `origin/qa/khanhson2005`; GitHub xác minh hai file ghim ở trên. Ngay sau lần push đó, coordinator xác nhận working tree sạch. Tại lần cập nhật QH-QA-013 đầu ngày, Student APK mới và các luồng Lecturer còn lại chưa được kiểm tra; lần cập nhật tracker đó không kết luận bug đã retest hoặc được sửa.

## Issue native mới QH-QA-016 — hàng 25

- Checkpoint Student được push riêng lên QA branch trong commit `d914e90ee4d9a8d080d238ab57552bdf3dfd9452`, gồm report và 26 PNG an toàn. GitHub xác minh [báo cáo Student academic](https://github.com/tonhulily/QuizHub/blob/d914e90ee4d9a8d080d238ab57552bdf3dfd9452/docs/qa/reports/2026-11-25-native-student-academic.md) và [ảnh Game 2](https://github.com/tonhulily/QuizHub/blob/d914e90ee4d9a8d080d238ab57552bdf3dfd9452/docs/qa/evidence/2026-11-25/native-student-academic/S-GAME-00-hub.png) tại commit đó. Report Student ghi 22 PASS, 1 FAIL, 6 NOT RUN (29 kiểm tra). Khung hình cá nhân ngoài phạm vi đã bị xóa trước khi stage và không nằm trong commit.
- Hàng 25 dùng khóa `QH-QA-016`; tiêu đề cuối là tràn giao diện Game 2. Bước tái hiện ghi nhận: Menu Ngân hàng đề → Minigame → quan sát thẻ Game 2 trên trang hub. Trên thiết bị 1080×2400, density 480 (360 dp), cỡ chữ mặc định 1.0, chip phần thưởng/dòng hành động bị tràn khoảng 15 px. Đây là lỗi hiển thị native đã quan sát; giả thuyết nguyên nhân về chip Ngân hàng đề mở rộng hàng vẫn chưa xác nhận.
- Bản ghi nêu source `d89a8d660d93842475b694100ccef1fdf783ed9e`, Student APK `7e73007a0f1a0a641a0f60c7ee75375cb671bede178c151f9b57a7292347a718`, môi trường và bước tái hiện, kết quả mong đợi không tràn, kết quả thực tế, cùng link report/PNG. Trạng thái mới `Open`; mức độ Minor/Low; ngày đầu và cập nhật 25/11; owner Dũng theo QA.md; chưa có ngày sửa hoặc retest.
- Trước khi ghi, coordinator xác nhận khóa issue trong các hàng 001–015 và hàng trống 25; đọc metadata A:V của hàng mới và hàng 24 để giữ định dạng/validation hiện hữu. Ghi nguyên tử chỉ dùng `updateCells` với `userEnteredValue` cho A25:V25. Readback xác nhận giá trị và toàn bộ format/validation khớp dự kiến; tổng tracker là 16 issue, 7 Open, 1 Ready for Retest, 8 Closed.
- Ảnh browser readback viewport ở 100% được lưu trong ignored `qa-artifacts/2026-11-25/tracker-QH-QA-016.png` và `tracker-QH-QA-016-evidence.png`; coordinator xác nhận hàng 25 hiện đúng. Ghi chú dài wrap/clipped theo chiều cao cố định có sẵn; không đổi style hay cấu trúc. Browser đã đóng.
- Các kết quả tracker và ảnh native chỉ ghi nhận lỗi UI đã thấy, không khẳng định nguyên nhân đã xác nhận hay đã có retest.
