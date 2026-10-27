# Tái hiện lỗi QA — source `b949513b254bee55a3887e619786ea91f85b477f`

Đây là ba harness local Flutter đã chạy để tái hiện finding trong review. Chúng không phải kiểm thử backend thật hay native-device test; mã ứng dụng không được sửa để tạo ra kết quả.

| ID / harness | Lệnh đã chạy tại source SHA | Kết quả / ý nghĩa |
|---|---|---|
| QH-QA-001 · `cubit_lifecycle_repro_test.dart.txt` | `XDG_CONFIG_HOME=/tmp/flutter-config FLUTTER_SUPPRESS_ANALYTICS=true .qa-tools/flutter/bin/flutter test --no-pub qa-artifacts/2026-10-26/dung-review/qbank/cubit_lifecycle_repro_test.dart` | Exit 0; assertion xác nhận `LoadCubit.load()` ném `StateError` khi request hoàn tất sau `close()`. |
| QH-QA-002 · `image_only_options_repro_test.dart.txt` | `XDG_CONFIG_HOME=/tmp/flutter-config FLUTTER_SUPPRESS_ANALYTICS=true .qa-tools/flutter/bin/flutter test --no-pub qa-artifacts/2026-10-26/dung-review/qbank/image_only_options_repro_test.dart` | Exit 1 theo kỳ vọng hiện tại: hai ảnh khác nhau với text rỗng bị báo “có hai phương án trùng nhau”. |
| QH-QA-003 · `export_platform_exception_repro_test.dart.txt` | `XDG_CONFIG_HOME=/tmp/quizhub-flutter-config FLUTTER_SUPPRESS_ANALYTICS=true ./.qa-tools/flutter/bin/flutter test --no-pub qa-artifacts/2026-10-26/dung-review/exam-ai/export_platform_exception_repro_test.dart --reporter expanded` | Exit 1 theo kỳ vọng lỗi: API giả trả URL hợp lệ; launcher giả ném `PlatformException(ACTIVITY_NOT_FOUND)` và exception thoát khỏi UI. Đây không chứng minh lỗi trên thiết bị thật. |

Log đầy đủ, runner và case output gốc: `qa-artifacts/2026-10-26/dung-review/` (ignored, local). Các lệnh và logs ban đầu dùng harness trong thư mục ignored đó; các bản `.dart.txt` ở đây chỉ là evidence dạng tài liệu, không phải source/test mới. Chúng không được đưa vào Flutter analyzer hoặc test discovery. Bản export trong evidence đã chỉnh import helper theo vị trí này; harness gốc trong `qa-artifacts` và lệnh gốc vẫn là bản đã chạy. Nếu cần chạy lại từ bản `.dart.txt`, trước hết chép vào `qa-artifacts/` bị ignore rồi chỉnh import helper tương đối theo vị trí đích; không chạy trực tiếp từ `docs/` hoặc `test/`.
