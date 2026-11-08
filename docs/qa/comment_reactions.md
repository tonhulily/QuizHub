# Reaction của bình luận

App dùng một loại Thích (LIKE), bấm lại để bỏ thích. Áp dụng cho cả bình luận gốc và phản hồi.

1. Mở Bình luận của một bài. Bấm Thích: nút đổi xanh, số lượt thích tăng. Bấm lại: bỏ xanh,
   số giảm và ẩn số nếu về 0. Số bình luận của bài không được tăng theo số lượt thích.
2. Mở phản hồi, thử thích/bỏ thích độc lập với bình luận gốc. Thử ở màn hình hẹp: các nút không
   tràn ngang. Bình luận không khả dụng không có nút tương tác.
3. Bấm liên tục khi request chưa xong: chỉ gửi một lần cho bình luận đó. Mất mạng hoặc server
   từ chối: UI hoàn tác trạng thái và hiển thị lỗi. Đóng bảng khi đang gửi không gây lỗi emit.
4. Preview: đóng/mở bảng hoặc hot restart, kiểm tra reaction của bình luận mẫu vẫn được giữ.
   Thích ở bài A không ảnh hưởng bài B hoặc bình luận của câu hỏi có cùng số ID đối tượng.

Preview lưu riêng reaction trên máy; danh sách bình luận tạo/xoá trong preview vẫn là phần mock
chưa có lưu trữ. Không xem việc test reaction là đã hoàn tất toàn bộ Comment List.

## API thật cần đối chiếu

Request: `POST /react`, body `target_type: COMMENT`, `target_id: <comment_id>`,
`reaction_type: LIKE`. Dùng cùng repository với bài viết và câu hỏi.

Đặc tả công khai tại <https://snsqb.duckdns.org/api/v1/docs/openapi.json> hiện mô tả COMMENT,
nhưng enum của ReactRequest chỉ liệt kê POST/SESSION/QUESTION. CommentResponseDto cũng chưa có
trường số reaction hoặc trạng thái reaction của người xem. Cần backend xác nhận hỗ trợ COMMENT
và trả `react_count`/`reacted_by_me` (hoặc trường tương đương). FE nhận kết quả `/react` làm chuẩn;
nếu GET bình luận không trả metadata reaction thì không thể xác nhận trạng thái từ server khi
mở phiên mới. Chưa dùng tài khoản thật để gửi reaction lên server trong lần triển khai này.
