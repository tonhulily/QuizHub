# Báo cáo QA: Mobile MCP cho kiểm tra UI native

**Kết quả:** 5 case native PASS, 2 case BLOCKED/INCONCLUSIVE trên APK QA riêng qua Mobile MCP. QBank/practice/rating/stats, exam list/detail và kết quả AI mock đã hiển thị. Sau khi đóng màn AI, ảnh chụp tiếp theo đen toàn bộ; chưa xác định được nguyên nhân nên dừng trước khi tạo đề mới. Không xác nhận lỗi ứng dụng từ ảnh này. Không sửa mã ứng dụng, dependency hay cấu hình production.

## Nguồn và môi trường

- Source SHA: `b949513b254bee55a3887e619786ea91f85b477f`.
- Nhánh: `qa/khanhson2005`.
- Node.js `v24.14.1`; npm `11.11.0`; Linux x86_64 / WSL2.
- API host: none; APK dùng `PreviewBackend` dữ liệu RAM, không gọi production backend.
- MCP package: `@mobilenext/mobile-mcp@1.0.13`; MCP SDK `2.4.0`.
- Package và npm cache nằm trong `.qa-tools/mobile-mcp` và `.qa-tools/npm-cache`; hai đường dẫn bị `.gitignore` loại trừ. Telemetry tắt bằng `MOBILEMCP_DISABLE_TELEMETRY=1`.
- Hướng dẫn upstream: [Mobile MCP README](https://github.com/mobile-next/mobile-mcp) yêu cầu Node.js 20+, Android Platform Tools và cho phép tắt telemetry bằng biến môi trường trên.

## Cài đặt và kiểm tra MCP

| Lệnh / thao tác | Kết quả |
|---|---|
| `npm_config_cache="$PWD/.qa-tools/npm-cache" npm install --prefix .qa-tools/mobile-mcp --no-save --no-package-lock @mobilenext/mobile-mcp@latest` | Thành công, exit 0; npm báo thêm 118 packages. Bản được phân giải là `1.0.13`. |
| `MCP-SMOKE-001`: JSON-RPC `initialize`, `tools/list`, `tools/call` qua stdio | Thành công, exit 0; protocol `2025-06-18`, server `mobile-mcp 1.0.13`, 33 công cụ và có `mobile_list_available_devices`. |
| `ANDROID_HOME="$PWD/.qa-tools/android-sdk" MOBILECLI_HOME="$PWD/.qa-tools/mobile-mcp/home" MOBILEMCP_DISABLE_TELEMETRY=1 .qa-tools/mobile-mcp/node_modules/.bin/mobilecli devices` | Thành công, exit 0; Mobile CLI thấy một thiết bị Android thật, online. |
| `MCP-SMOKE-WIN-ADB-001`: MCP `tools/call` — `mobile_list_available_devices` | Thành công, exit 0; thấy một thiết bị Android thật, model RMX3370, Android 13. Số serial/ID đã không ghi vào báo cáo. |

Thiết lập MCP đã được coordinator đăng ký trong cấu hình Codex toàn cục. Lệnh dùng Node cục bộ, telemetry tắt; legacy mode được bật để điều khiển qua ADB/uiautomator mà không cài helper vào điện thoại:

```toml
[mcp_servers.mobile-mcp]
command = "/home/khanhson2005/.nvm/versions/node/v24.14.1/bin/node"
args = ["/home/khanhson2005/projects/QuizHub/.qa-tools/mobile-mcp/node_modules/@mobilenext/mobile-mcp/lib/index.js"]
env = { ANDROID_HOME = "/home/khanhson2005/projects/QuizHub/.qa-tools/android-sdk", MOBILECLI_HOME = "/home/khanhson2005/projects/QuizHub/.qa-tools/mobile-mcp/home", MOBILEMCP_DISABLE_TELEMETRY = "1", MOBILEMCP_LEGACY_ROBOT = "1" }
```

## Thiết bị native

- Sơn cho phép cài công cụ Android cần thiết. Windows Platform Tools `37.0.1` được cài tại `C:\Users\Admin\AppData\Local\QuizHub-QA\platform-tools`; checksum SHA-1 khớp metadata chính thức của Google (`e03e78b1d80b396f1c3358e31251cb31740e1110`, 8,044,989 byte). `adb.exe version`: exit 0, Android Debug Bridge `1.0.41`, Platform Tools `37.0.1-15733141`.
- WSL shim `.qa-tools/android-sdk/platform-tools/adb` gọi trực tiếp Windows `adb.exe`. Không dùng TCP bridge và không mở ADB server ra mạng.
- `adb.exe devices -l`: exit 0, đúng một USB device online; serial đã che. Đọc riêng các thuộc tính: model `RMX3370`, release `13`, API `33`; mỗi lệnh `getprop`: exit 0. Mobile MCP cũng nhận một thiết bị `GT Neo2` / `RMX3370`, Android `13`, trạng thái `online`.
- APK QA riêng `vn.edu.hust.quizhub.qa.preview` được coordinator cài và mở; label `QuizHub QA Preview`, role `LECTURER`. APK SHA-256: `6a1b2e9af785f0a55ae81df5253174eb4bbacd0081b1c10dfc0b6f9ee0fb684a`. APK được build từ source `b949513b254bee55a3887e619786ea91f85b477f`; docs HEAD lúc ghi báo cáo là `b865b38eb2a9b6b23de34a1e2b3e108f1f377afd` (chỉ thay đổi docs/rules, không phải source đã build).
- Kích thước màn hình do MCP báo: `1080x2400`. Trước các thao tác và ảnh, `mobile_get_foreground_app` xác nhận `vn.edu.hust.quizhub.qa.preview`, activity `vn.edu.hust.quizhub.MainActivity`.

## Kết quả UI native

| Case | Thao tác và kết quả quan sát | Trạng thái / evidence |
|---|---|---|
| NATIVE-QB-01 | Chọn tab QBank, mở session “Ôn tập cây cân bằng AVL”, câu Q101. Chọn B (`O(log n)`), gửi đáp án; màn hình hiện “Chính xác!” và giải thích độ phức tạp AVL. | PASS — `qbank-tab.png`, `qbank-session-detail.png`, `qbank-b-selected.png`, `qbank-after-submit.png` |
| NATIVE-QB-02 | Mở đánh giá, chọn 4 (“Câu hỏi hay”), gửi; mở thống kê. Danh sách thống kê hiện rating vừa gửi. | PASS — `qbank-rating-sheet.png`, `qbank-rating-selected.png`, `qbank-rating-submitted.png`, `qbank-stats.png` |
| NATIVE-QB-03 | Nút Back từ thống kê trở lại câu hỏi; Back lần nữa về danh sách QBank. | PASS — `qbank-back.png`, `qbank-back-to-list.png` |
| NATIVE-EX-01 | Mở danh sách đề thi mẫu rồi mở “Đề giữa kỳ IT3011 - 20251”; chi tiết hiện 3 câu và các nút “AI gợi ý”. | PASS — `exam-list.png`, `exam-detail.png` |
| NATIVE-AI-01 | Mở “AI gợi ý” cho câu 1, chọn hành động viết lời giải từng bước, gửi. Màn hình kết quả hiển thị cảnh báo xanh “Không phát hiện ảo giác”, độ tin cậy 92% và nội dung gợi ý mock. | PASS — `exam-ai-result-visible.png` |
| NATIVE-AI-02 | Chọn “Bỏ qua” để không áp dụng gợi ý vào câu hỏi mẫu. Lệnh tap thành công, nhưng hai lần chụp MCP sau đó đen toàn bộ ảnh; không thể xác định app có render nội dung hay không. | BLOCKED / INCONCLUSIVE — ảnh giữ tại [exam-ai-dismiss-blank-screen.png](../evidence/2026-10-26/android-ui/exam-ai-dismiss-blank-screen.png); chưa xác nhận lỗi ứng dụng. Dừng thao tác vì không còn bằng chứng màn hình đọc được. |
| NATIVE-EX-02 | Tạo đề với môn/lớp và 2 câu. | BLOCKED — chưa chạy do màn hình sau thao tác trước bị đen. |

Mobile MCP `mobile_list_elements_on_screen` báo `Error: Cannot read properties of undefined (reading 'node')`, nên tương tác dùng tọa độ dựa trên ảnh. Robot mặc định ban đầu timeout khi khởi động device server; legacy mode hoạt động sau khi cho phép tiến trình Node spawn bundled `mobilecli` (phiên bản `1.0.21`). Lỗi cây accessibility là lỗi công cụ; không tính là lỗi ứng dụng.

Ảnh chụp và ảnh inconclusive còn lại nằm trong `qa-artifacts/2026-10-26/android-ui/native-mcp/` (ignored). Evidence được chọn: [QBank answer](../evidence/2026-10-26/android-ui/qbank-after-submit.png), [QBank stats](../evidence/2026-10-26/android-ui/qbank-stats.png), [exam detail](../evidence/2026-10-26/android-ui/exam-detail.png), [AI suggestion result](../evidence/2026-10-26/android-ui/exam-ai-result-visible.png), và ảnh màn đen chưa xác định nguyên nhân. Không ghi serial/ID thiết bị trong báo cáo.

Sau khi kiểm tra, coordinator gọi Mobile MCP `mobile_uninstall_app` cho riêng `vn.edu.hust.quizhub.qa.preview`; kết quả báo đã gỡ app. Kiểm tra đích `adb shell pm path vn.edu.hust.quizhub.qa.preview` trả exit 1 và output rỗng, phù hợp trạng thái package không còn trên thiết bị. Không thao tác app QuizHub chính.

**DEVICE_DISCOVERY_SHA:** `b949513b254bee55a3887e619786ea91f85b477f`.
**APK_TESTED_SOURCE_SHA:** `b949513b254bee55a3887e619786ea91f85b477f`.
**DOCS_HEAD_AT_REPORT:** `b865b38eb2a9b6b23de34a1e2b3e108f1f377afd`.
