# Native core preview retest — 2026-11-24

**Kết quả:** retest UI native trên bản Lecturer preview. Đây không phải API/backend acceptance. Không có QA API host hoặc tài khoản test.

- Source: `d89a8d660d93842475b694100ccef1fdf783ed9e`.
- APK: Lecturer preview, `vn.edu.hust.quizhub.qa.retest`, version `1/1.0`, SHA-256 `6e77ccf5ff4a81dd55f7cbe9b0637325fbf547bde48bd1cc03cce7d77a11cf4d`.
- Thiết bị do Mobile MCP báo: RMX3370, Android 13/API 33, loại `emulator`; độ phân giải 1080×2400, density 480, font scale 1.0. Serial đã che. Không suy ra loại thiết bị vật lý.
- Runtime: Flutter 3.41.6. App đã cài sẵn trước pha kiểm thử này; không cài/build trong pha.
- Dữ liệu backend: PreviewBackend. Các dấu `QA2411...` chỉ là fixture cục bộ/UI. Không dùng kết quả để khẳng định API, phân quyền, upload, delivery/read receipt hay FCM.
- Lệnh native: thao tác qua Mobile MCP (`mobile_list_elements_on_screen`, click/type/back/swipe, `mobile_terminate_app`, `mobile_launch_app`, `mobile_save_screenshot`); MCP không cung cấp mã thoát tiến trình cho các thao tác này. Không chạy lệnh ADB trong pha này.

| Case | Kết quả | Quan sát / giới hạn |
|---|---|---|
| NC-01A Tạo bài viết + quyền Bạn bè | PASS — UI preview | Đăng `QA2411POST`; composer/feed hiện nhãn Bạn bè. Không chứng minh quyền xem giữa hai tài khoản. |
| NC-01B Hủy draft | PASS — UI preview | Đóng draft hiện xác nhận; chọn tiếp tục giữ nội dung, sau đó chọn bỏ draft. |
| NC-01C Sửa và xóa bài | PASS — UI preview | Sửa thành `_EDIT`, Home hiện nội dung mới; xác nhận xóa có thể hủy (post còn) và xác nhận lần sau (post biến mất). |
| NC-01D Quyền xem giữa tài khoản | BLOCKED — thiếu host/account | Không có QA API/account thứ hai để kiểm tra privacy thực. |
| NC-02A Tạo bình luận và reply | PASS — UI preview | Comment `QA2411CMT` và reply `QA2411REPLY` hiện ở cây comment. |
| NC-02B Like root/reply độc lập | PASS — UI preview | Mỗi item hiện 1 lượt thích sau khi like riêng. |
| NC-02C Xóa reply và root | PASS — UI preview | Hủy xóa reply giữ nguyên; xác nhận xóa reply giữ root; xác nhận xóa root bỏ item khỏi sheet. |
| NC-02D Bình luận sau tải lại từ server | BLOCKED — thiếu host/account | Preview POST echo item nhưng GET tiếp theo vẫn trả fixture cố định; chưa kiểm tra server, không kết luận bug. |
| NC-03A Hủy sửa hồ sơ | PASS — UI preview | Thoát edit không lưu, trang hồ sơ vẫn hiện tên ban đầu. |
| NC-03B Lưu hồ sơ | PASS — UI preview | Lưu `_QA`; hồ sơ hiện tên mới và snackbar cập nhật. Số liệu đổi 3/0/2 thành 54/31/128 sau lưu; ghi nhận khác biệt fixture `/users/me`, chưa đủ căn cứ lỗi nghiệp vụ. |
| NC-03C Chọn/gỡ ảnh avatar hoặc cover | NOT RUN — chủ động chưa mở picker | Chưa có luồng UI đảm bảo chỉ hiển thị fixture; tránh mở gallery cá nhân. |
| NC-03D Upload thật / ngưỡng byte | BLOCKED — thiếu backend | Preview trả URL giả picsum và `file_size=120000`; không thể xác nhận upload hoặc giới hạn byte thật. |
| NC-04A Follow user 20235008 | PASS — UI preview | Nút chuyển sang “Đang theo dõi”. |
| NC-04B Unfollow user 20235008 | PASS — UI preview | Nút trở về “Theo dõi”. |
| NC-04C Gửi lời mời tới lecturer 20235003 | PASS — UI preview | UI hiện “Đã gửi lời mời” và snackbar gửi thành công. |
| NC-04D Hủy lời mời đã gửi | WAITING — chưa có action trong UI | Dòng lời mời đã gửi chỉ hiện trạng thái; không thấy action hủy. |
| NC-04E Chấp nhận lời mời Long | PASS — UI preview | Mục incoming biến mất và bộ đếm giảm. |
| NC-04F Từ chối lời mời Tung | PASS — UI preview | Mục incoming biến mất sau từ chối. |
| NC-04G Chặn user 20235008 | PASS — UI preview | Có xác nhận chặn; sau xác nhận xuất hiện toast và user không còn trong kết quả tìm kiếm. |
| NC-04H Bỏ chặn user 20235008 | PASS — UI preview | Danh sách “Người đã chặn” hiển thị user; sau bỏ chặn danh sách trống. |
| NC-05A Gửi chat | PASS — UI preview | `QA2411CHAT` hiện trạng thái “Đã gửi”. Đây không phải xác nhận peer/server. |
| NC-05B Thu hồi chat | PASS — UI preview | Menu có “Thu hồi với mọi người”; item đổi thành “Tin nhắn đã thu hồi”. |
| NC-05C Xóa chat ở phía tôi | PASS — UI preview | Chọn “Xoá ở phía tôi” làm `QA2411CHAT` biến mất khỏi view hiện tại. |
| NC-05D Tìm trong đoạn chat | PASS — UI preview | Tìm `QA2411` lọc danh sách còn hội thoại Lan với marker tương ứng. |
| NC-05E Lưu chat qua relaunch | PASS — UI preview local | Sau force-stop/relaunch, `QA2411PERSIST` và trạng thái thu hồi vẫn hiện. Chỉ xác nhận lưu preview cục bộ. |
| NC-05F Giao nhận chat/realtime với peer | BLOCKED — thiếu host/peer account | Chưa có QA backend hoặc phiên peer để xác nhận delivery/read receipt. |
| NC-06A Mở report sheet post/comment/profile | PASS — UI preview | Ba sheet mở được; mỗi sheet hiển thị lý do vi phạm, mô tả tùy chọn và nút gửi. |
| NC-06B Hủy report profile | PASS — UI preview | Back đóng sheet và trở về hồ sơ. |
| NC-06C Xác nhận submit report trên UI | NOT RUN — kết quả inconclusive | Đã bấm gửi ở comment/post nhưng không quan sát xác nhận rõ; không ghi PASS. Source cho biết mô tả tùy chọn, sheet không có validation mô tả bắt buộc. |
| NC-06D Lưu report phía server | BLOCKED — thiếu host/account | Preview route có thể fallback success generic; chưa có QA API để xác nhận report được lưu. |
| NC-07A Hộp thoại đăng xuất | PASS — UI preview | Menu Đăng xuất mở hộp xác nhận; sau đó xác nhận đăng xuất tới form login. |
| NC-07B Validation login rỗng | PASS — UI preview | Submit rỗng hiện “Vui lòng nhập email.” và “Vui lòng nhập mật khẩu.” |
| NC-07C Gợi ý email trường | PASS — UI preview | Nhập `s12345` hiện chip `s12345@sis.hust.edu.vn`. |
| NC-07D Checkbox lưu thông tin | PASS — UI preview | Checkbox “Lưu thông tin đăng nhập cho lần sau” đổi từ bật sang tắt rồi được khôi phục bật. |
| NC-07E Đăng nhập preview bằng thông tin hợp lệ | NOT RUN — dành cho pha sau | Chưa nhập/gửi mật khẩu; preview nhận tùy ý nên không xác nhận auth thực. Sau force-stop/relaunch app mở Home preview. |
| NC-07F Keyboard Back trong chat | PASS — UI preview | Android Back đóng bàn phím khi focus ở composer chat. |
| NC-07G Đăng nhập thật | BLOCKED — thiếu host/account | QA auth server/account chưa được cung cấp. |
| NC-08A Chọn/hủy/gỡ media fixture | NOT RUN — chủ động chưa mở picker | Picker hệ thống có thể hiện ảnh ngoài fixture; chưa có đường an toàn để chỉ chọn thư mục fixture. |
| NC-08B Quyền camera | NOT RUN — chủ động chưa mở camera | Không mở camera/môi trường cá nhân trong pha này. |
| NC-08C Layout nhỏ/orientation | NOT RUN | Không đổi orientation, font hoặc cài đặt thiết bị; không có thiết bị/layout nhỏ khác để so sánh. |

**Tổng 40 assertion:** 27 PASS, 1 WAITING, 6 NOT RUN, 6 BLOCKED. `BLOCKED` chỉ áp dụng assertion cần QA host/account/backend; các nhánh chưa chạy có chủ đích được ghi `NOT RUN`.

## Source contract đã đối chiếu

- `lib/shared/post/post_card.dart`: menu bài của chủ có sửa/xóa; bài của người khác có báo cáo.
- `lib/shared/report/report_sheet.dart`: chọn loại vi phạm, mô tả tùy chọn, gửi; sheet hiển thị phản hồi thành công sau repository call.
- `lib/features/profile/widgets/friend_actions.dart`: menu hồ sơ người khác có báo cáo/chặn.
- `lib/features/chat/view/chat_detail_view.dart`: menu tin nhắn gồm sao chép, xóa phía tôi và thu hồi tin của mình; composer yêu cầu kết nối/chat access.
- `lib/features/chat/view/conversations_view.dart`: có ô tìm trong hội thoại.
- `lib/shared/comment/comments_sheet.dart`: comment gửi bỏ qua input rỗng và áp giới hạn từ; không suy ra hợp đồng server từ preview.
- `lib/features/profile/view/edit_profile_view.dart`: hủy/sửa hồ sơ, chọn/gỡ ảnh và lưu là thao tác riêng; ảnh chỉ áp dụng sau lưu.
- `lib/dev/preview_backend.dart`: GET `/comments` dựng fixture; POST echo comment mới; `/medias/upload` tạo URL picsum và `file_size` cố định 120000. Đây là giới hạn test double, không phải lỗi app.

## Bằng chứng

Các ảnh dưới đây là screenshot native của preview; hậu tố `context` chỉ ghi ngữ cảnh, không dùng làm bằng chứng API:

- `docs/qa/evidence/2026-11-24/native-core/NC-01-home-context.png`
- `docs/qa/evidence/2026-11-24/native-core/NC-01-post-created-context.png`
- `docs/qa/evidence/2026-11-24/native-core/NC-02-post-composer.png`
- `docs/qa/evidence/2026-11-24/native-core/NC-02-comments-context.png`
- `docs/qa/evidence/2026-11-24/native-core/NC-02-comment-reply-like-context.png`
- `docs/qa/evidence/2026-11-24/native-core/NC-03-privacy-friends-context.png`
- `docs/qa/evidence/2026-11-24/native-core/NC-03-profile-context.png`
- `docs/qa/evidence/2026-11-24/native-core/NC-03-profile-save-context.png`
- `docs/qa/evidence/2026-11-24/native-core/NC-04-friend-request-sent-context.png`
- `docs/qa/evidence/2026-11-24/native-core/NC-05-chat-history-context.png`
- `docs/qa/evidence/2026-11-24/native-core/NC-05-chat-sent-context.png`
- `docs/qa/evidence/2026-11-24/native-core/NC-05-chat-persist-after-relaunch-context.png`
- `docs/qa/evidence/2026-11-24/native-core/NC-06-comment-report-sheet-context.png`
- `docs/qa/evidence/2026-11-24/native-core/NC-06-profile-context.png`
- `docs/qa/evidence/2026-11-24/native-core/NC-06-profile-report-sheet-context.png`
- `docs/qa/evidence/2026-11-24/native-core/NC-07-login-empty-validation-context.png`

## Kết thúc phiên

Sau thao tác cuối, Mobile MCP hiển thị Home của `vn.edu.hust.quizhub.qa.retest`. App được giữ nguyên cài đặt để pha native tiếp theo dùng lại. Không xóa fixture trên thiết bị, không thay đổi source/config/dependency, không commit/push, không cập nhật tracker. Follow ngoài ý muốn trên profile lecturer 20235003 đã được tắt lại bằng UI trước khi kết thúc phiên; nút trở về “Theo dõi”.
