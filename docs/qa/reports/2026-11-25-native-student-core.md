# Student native preview — core gaps (2026-11-25)

## Phạm vi và môi trường

- Source app: `d89a8d660d93842475b694100ccef1fdf783ed9e` (snapshot nguồn `82ef14f38e086d6b558b392fc54a328c3d7f26a2`). Runtime/dependency/source không được sửa trong lượt này.
- Docs checkpoint tại đầu lease: `8b22404a0591e3497b6b588a6c443ab63b9c4195` (đây là SHA của docs checkpoint, không phải source app).
- APK Student: `qa-artifacts/2026-11-24/apks/student-preview-fresh.apk`, SHA-256 `7e73007a0f1a0a641a0f60c7ee75375cb671bede178c151f9b57a7292347a718`, application ID `vn.edu.hust.quizhub.qa.retest`.
- Thiết bị: Mobile MCP device RMX3370 (emulator), Android 13/API 33, 1080×2400, mật độ 480 dpi (360 dp), font 1.0. Device ID/serial đã mask.
- Chạy thủ công trên mobile MCP bằng `mobile_list_available_devices`, `mobile_list_elements_on_screen`, `mobile_click_on_screen_at_coordinates`, `mobile_long_press_on_screen_at_coordinates`, `mobile_press_button`, `mobile_swipe_on_screen`, `mobile_type_keys`, `mobile_batch_commands` và transient `mobile_take_screenshot`. Các case UI không có process exit code. Không có API host, QA account, hay backend thật; các thao tác đăng nhập, bài viết, report và chat chỉ kiểm tra phản hồi UI/preview.
- Fixture ảnh synthetic trong `/sdcard/Download/QuizHub-QA-20261125/`; chỉ chọn file trong thư mục này. Sau media scan, DocumentsUI hiển thị đủ fixture gồm năm PNG 70 B, hai PNG xấp xỉ 4 MiB và một GIF 35 B. Không kiểm tra upload hoặc byte sau image-picker transform.

## Kết quả quan sát

Kết quả lease này: **12 PASS, 2 NOT RUN, 1 BLOCKED (15 rows)**. Đây là một phần native preview retest, không phải acceptance suite.

| Case | Kết quả | Quan sát / giới hạn |
|---|---|---|
| SCG-01 — preview login giả | PASS (UI preview) | Email synthetic `qa-student@preview.invalid` và mật khẩu giả được chấp nhận, mở Home. Không chứng minh xác thực server. |
| SCG-02 — remember / quick login / forget | PASS (UI preview) | Sau logout có thẻ tài khoản đã lưu; nút đăng nhập nhanh mở Home. “Bỏ tài khoản đã lưu” yêu cầu xác nhận và đưa về form nhập tay. Login sau khi tắt remember, rồi logout, cũng trở về form nhập tay. Credential giả không được lưu trong báo cáo. |
| SCG-03 — picker cancel | PASS (UI) | Hủy picker quay về màn chỉnh sửa; không chọn file ở lần hủy. |
| SCG-04 — chọn avatar/cover | PASS (edit draft) | Chọn `photo_1.png` làm avatar và `photo_2.png` làm cover; ảnh fixture hiện trong draft. Không lưu profile. |
| SCG-05 — remove avatar/cover | PASS (edit draft) | Remove cover và avatar làm UI trở lại trạng thái không ảnh/default trong draft. Không lưu; không khẳng định trạng thái sau khởi động lại. |
| SCG-06 — camera cancel | PASS (UI) | Chọn chụp ảnh mở camera hệ thống; nhấn Back trước shutter quay về màn chỉnh sửa. Không chụp ảnh. |
| SCG-07 — report confirmation | PASS (preview feedback) | Từ bài mẫu, chọn “Spam / quảng cáo” và gửi một lần. Snackbar: “Đã gửi báo cáo. Cảm ơn bạn đã góp ý!” Chỉ là feedback của preview, không chứng minh backend lưu report. |
| SCG-08 — giới hạn 4 ảnh và remove | PASS (composer UI) | Chọn 5 ảnh synthetic cùng lúc. Composer giữ `4/4 ảnh` và hiện “Chỉ thêm được 4 ảnh mỗi bài.” Remove một ảnh cập nhật thành `3/4 ảnh`. |
| SCG-09 — hủy draft có ảnh | PASS (UI) | Đóng composer hiện “Bỏ bài viết? / Nội dung bạn đã nhập sẽ bị mất.”; chọn bỏ bài viết quay về Home. |
| SCG-10 — biên 500/501 từ | NOT RUN (inconclusive) | Đã thử nhập text transliterated từ fixture 500/501 từ; không xác nhận được số từ thực trong trường do accessibility value bị cắt ngắn và không có bộ đếm hiển thị. Lượt 501 được gửi, UI báo “Đã đăng bài viết”; bài tạm đúng của QA sau đó được xóa qua menu và hộp thoại xác nhận. Không kết luận bug hoặc pass boundary. |
| SCG-11 — chat unread filter | PASS (UI preview) | “Chưa đọc” hiển thị empty state “Bạn đã đọc hết tin nhắn / Các đoạn chat chưa đọc sẽ hiện ở đây.” |
| SCG-12 — tìm người mẫu và mở chat | PASS (điều hướng preview) | Tìm `Anh`, chọn user mẫu từ kết quả, hồ sơ có nhãn “Người dùng mẫu số 4”, rồi mở màn chat. Vì cuộc trò chuyện có tin nhắn mẫu sẵn, không khẳng định đã tạo recipient/conversation mới. |
| SCG-13 — chat ảnh remove/send/revoke | PASS (preview local) | Chọn ảnh QA, nút “Gỡ ảnh” xuất hiện; remove rồi chọn lại và gửi. Tin nhắn hiển thị “Xem ảnh / Đã gửi”; chọn “Thu hồi với mọi người” đổi thành “Tin nhắn đã thu hồi”. Không chứng minh gửi tới server/thiết bị khác. |
| SCG-14 — API/auth thật, push, upload | BLOCKED | Không có QA API host/account; không chạy FCM hoặc dịch vụ ngoài. |
| SCG-15 — tạo cuộc trò chuyện mới | NOT RUN | Đường đi từ kết quả tìm kiếm mở ra hội thoại mẫu đã có sẵn tin nhắn; chưa xác minh việc tạo recipient/conversation mới. |

Các thao tác không ghi hình. Không có PNG/log thiết bị được lưu; bằng chứng là các nhãn UI và kết quả tương tác được ghi ngay trong [trích đoạn quan sát](../evidence/2026-11-25/native-student-core/ui-observations.txt). Không đưa tên người dùng, email cá nhân, serial hay token vào evidence.

## Tình trạng sau thao tác

Thiết bị được trả cho coordinator ngay sau khi đóng report sheet và về Home. Không còn picker hay composer draft mở. Bài post QA được tạo trong lần thử 501 từ đã được xóa trong UI; các post mẫu khác không bị sửa/xóa. Bài chat ảnh QA đã thu hồi với mọi người trong preview. Coordinator đã hoàn tất cleanup sau lease; xem [bằng chứng cleanup](../evidence/2026-11-25/device-cleanup.txt).

Phạm vi này chỉ là một phần native preview run, không phải hoàn tất acceptance suite. Toàn bộ baseline 25 case và các trạng thái API/backend vẫn theo [tiến độ QA](../PROGRESS.md); kết quả core và academic khác nằm trong các báo cáo theo pha.
