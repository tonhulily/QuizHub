# Fixture QA cho QuizHub

Chỉ cần Python 3, không cần package ngoài:

```bash
python3 qa/fixtures/generate_fixtures.py
python3 -m unittest discover -s qa/fixtures -p 'test_*.py' -v
```

Mặc định file được tạo trong `qa-artifacts/fixtures/` (đã ignore bởi Git). Có thể truyền một thư mục output khác làm đối số duy nhất. File fixture trùng tên có cùng nội dung được giữ nguyên; nếu nội dung khác, generator dừng và không ghi đè.

- `post_499_words.txt`, `post_500_words.txt`, `post_501_words.txt`: văn bản tiếng Việt UTF-8; `post_500_mixed_whitespace.txt` dùng space, tab, LF và CRLF.
- `password_5/6/32/33.txt`: mật khẩu chữ-số tại biên độ dài; `password_special_char.txt` và `password_embedded_space.txt` có ký tự không hợp lệ cho mật khẩu mới.
- `photo_1.png` đến `photo_5.png`: năm PNG 1×1 hợp lệ, khác màu để thử chọn bốn và năm ảnh.
- `image_exact_4mib.png` và `image_over_4mib_by_1.png`: PNG 1×1 hợp lệ, kích thước chính xác 4,194,304 và 4,194,305 byte; phần đệm là chunk ancillary có CRC.
- `animated.gif`, `animated_uppercase.GIF`: GIF 1×1 hợp lệ, có global color table và LZW index trỏ tới palette.
- `manifest.json`: kích thước file và giới hạn của bộ fixture.

Self-check chỉ xác minh generator và cấu trúc fixture; nó không chứng minh app/API chấp nhận hoặc từ chối file, backend giải mã media, hay upload thành công. `MediaRepository` kiểm tra đuôi `.gif` (không phân biệt hoa thường) và kích thước trước upload. Chỉ thử upload trên môi trường test được phép; không dùng dữ liệu cá nhân. Video UI chưa triển khai nên không tạo file `.mp4` giả.

**Lưu ý picker:** UI có thể resize/re-encode ảnh và bỏ phần padding, nên kích thước file được chọn có thể khác fixture gốc. Để xác minh chính xác ngưỡng byte phía client, truyền fixture trực tiếp vào repository bằng test harness và kiểm tra API giả không nhận request với file quá cỡ. Backend validation cần kiểm tra riêng trên API test được phép.
