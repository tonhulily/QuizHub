# Native preview Student: học thuật và minigame — 2026-11-25

**Phạm vi:** UI preview Android, không phải API/FCM/security acceptance. Preview fixtures và state nằm trong RAM. Chỉ đặt một lượt Game 2 trên session seed 3; không sửa nội dung câu 301/302.

- Source: `d89a8d660d93842475b694100ccef1fdf783ed9e`.
- Checkout HEAD khi chạy: `f5381457571c4f3d1aec116def79f6132750f9de`.
- Student preview artifact SHA-256: `7e73007a0f1a0a641a0f60c7ee75375cb671bede178c151f9b57a7292347a718`; package `vn.edu.hust.quizhub.qa.retest`.
- Mobile MCP: RMX3370, Android 13, MCP báo type `emulator`; không kết luận máy vật lý. Màn hình 1080×2400, mật độ 480 dpi (360 dp chiều ngang), font scale 1.0 theo lần đọc ADB chỉ đọc của điều phối viên. Không dùng ADB trong lượt native.
- API host: không có; phạm vi preview-only, không QA API/account.
- Evidence: `docs/qa/evidence/2026-11-25/native-student-academic/`.

## Kết quả

| Case | Thao tác / quan sát | Kết quả |
|---|---|---|
| S-START-01 | Mở Home Student preview; hierarchy có QuizHub, tạo bài viết, tìm kiếm, tin nhắn và feed fixture. | PASS — `S-START-01-home-context.png` |
| S-ROLE-01 | `Ngân hàng đề` có `Đề xuất câu hỏi`, `Phiên của tôi`, `Minigame`; không hiện shortcut `Đề thi`. | PASS — assertion UI Student, không xác minh quyền server/deep-link. `S-ROLE-01-qbank-shortcuts.png` |
| S-QB-01 | Mở `Ôn tập cây cân bằng AVL`, Q101 trước trả lời; chưa lộ đáp án/lời giải. | PASS — `S-QB-01-preanswer-context.png` |
| S-QB-02 | Q101 chọn A (`O(1)`) → `Nộp đáp án`; UI báo `Chưa đúng. Đáp án đúng: B` và lời giải. | PASS — `S-QB-02-wrong-answer.png` |
| S-QB-03 | Q102 chọn A → `Nộp đáp án`; UI báo `Chính xác!` và lời giải. | PASS — `S-QB-03-correct-answer.png` |
| S-AI-01 | Mở session seed 3 của Student; `AI gợi ý` hiện ở chi tiết câu. | PASS — khả năng tiếp cận UI; không suy ra quyền API. `S-AI-05-discard.png` (chi tiết session và control AI), `S-AI-02-refine-input.png` |
| S-AI-02 | Mở `AI tinh chỉnh`, preset prompt và `Gửi cho AI`; preview trả suggestion/template. | PASS — chỉ mô phỏng preview; không đánh giá chất lượng AI. `S-AI-02-refine-input.png`, `S-AI-03-suggestion.png` |
| S-AI-03 | Bấm `So sánh`; modal hiển thị Bản gốc/Bản AI song song. | PASS — `S-AI-04-compare.png` |
| S-AI-04 | Chọn `Bỏ qua`; quay về chi tiết session, nội dung câu gốc còn nguyên. Không chọn `Dùng bản gợi ý`/không lưu. | PASS — `S-AI-05-discard.png` |
| S-GAME-00 | `Minigame` hub render Game 1/2/4, rank card, `Lịch sử dự đoán`, `Bảng xếp hạng`. | PASS — chức năng/nội dung hub hiển thị; ngoại lệ layout được ghi riêng ở S-GAME-LAYOUT-01. `S-GAME-00-hub.png` |
| S-GAME-LAYOUT-01 | Quan sát hub ở kích thước Android mặc định; hàng reward và action của Game 2 bị tràn, Flutter in cảnh báo `OVERFLOWED BY 15 PIXELS` đè lên chip/action. | FAIL — lỗi layout trực tiếp trên UI; ảnh giữ nguyên tại `S-GAME-00-hub.png`. Chưa retest trên lease mới. Candidate source: `lib/features/minigame/widgets/game_widgets.dart`, `GameCard.build()` hàng `Row` chứa `Expanded(QbankChip)` và `actionLabel`; callsite Game 2 trong `lib/features/minigame/view/minigame_hub_view.dart`. Owner theo [QA.md](../../../QA.md): Dũng / TV2 (gamification). |
| S-G1-01 | Game 1 liệt kê lớp 171146 và 171150. | PASS — `S-G1-01-class-list.png` |
| S-G1-02 | Lớp 171146, nhập 0 và chốt; hierarchy lúc chạy hiện `Tối thiểu 1`. | NOT RUN — ảnh chụp bị lẫn khung hình từ ứng dụng khác nên đã loại bỏ; không dùng làm bằng chứng. Cần retest validation trên lớp chưa cược 171150 ở lease sau. |
| S-G1-03 | Nhập `012` (giá trị số 12), chốt; UI xác nhận ghi nhận và card hiện `Đã đoán 12 người cho ngày mai`. | PASS — UI preview, không phải response backend. `S-G1-03-valid-bet.png` |
| S-G1-04 | Mở lại Game 1; lớp 171146 ở trạng thái `Đã đoán 12...`, không còn nút dự đoán. | PASS — guard UI; không gọi lại để khẳng định HTTP 409. `S-G1-04-already-predicted.png` |
| S-G1-05 | Mở form lớp 171150 rồi `Huỷ`; trở về danh sách, lớp vẫn hiện `Dự đoán cho ngày mai`. | PASS — huỷ không tạo lượt. `S-G1-05-cancel-result.png`; dialog trước huỷ: `S-G1-05-cancel-dialog.png` |
| S-G2-01 | Game 2 chọn session seed 3 `Bảng băm và xử lý đụng độ`; fixture báo 2 câu tự soạn. | PASS — `S-G2-01-human-only-dialog.png` |
| S-G2-02 | Dialog chỉ có trường số câu tự soạn (không có trường AI); chốt `1`, hierarchy ngay sau submit báo `Đã ghi nhận dự đoán. Chúc bạn may mắn!`. | PASS — human-only preview path, không chứng minh API. Screenshot `S-G2-02-human-bet-success.png` không bắt được toast; `S-GH-03-history.png` xác nhận entry 0 AI · 1 tự soạn đang chờ kết quả. |
| S-G2-03 | Thử đặt lại session 3 với human=1; hierarchy sau submit báo `Bạn đã đặt cược Game 2 cho phiên này rồi.` | PASS — thông báo transient quan sát qua hierarchy, không được chụp lại; `S-G2-03-duplicate-message.png` chỉ là ảnh context của session detail, không làm bằng chứng cho toast. Không gọi API trực tiếp/không khẳng định mã 409. |
| S-G4-01 | Game 4 liệt kê IT3011/IT3070; mở form IT3011 và huỷ, trở về danh sách không có dự đoán mới. | PASS — `S-G4-01-subject-list.png`, `S-G4-02-dialog.png`, `S-G4-03-cancel-state.png` |
| S-G4-02 | Mở lại IT3011, nhập 25, chốt; UI hiện `Bạn đoán: 25 câu hỏi`, `Chờ kết quả`. | PASS — preview UI. `S-G4-04-valid-bet.png` |
| S-GH-01 | Leaderboard kỳ học hiển thị user #3, 135 điểm và danh sách xếp hạng fixture. | PASS — `S-GH-01-leaderboard-term.png` |
| S-GH-02 | Chọn `Theo môn`; view có IT3011/IT3070 và hiển thị dữ liệu leaderboard môn (user #3, 55 điểm). | PASS — fixture UI. `S-GH-02-leaderboard-subject.png` |
| S-GH-03 | Lịch sử hiển thị hai lượt mới chờ kết quả (Game 1: 12; Game 2: 0 AI · 1 tự soạn) và hai lượt Game 1 resolved mẫu. | PASS — `S-GH-03-history.png` |
| S-QB-04 | Q102 trong practice: `Thống kê câu hỏi` hiển thị 51 lượt, tỉ lệ đúng 59%, phân bố A30/B7/C7/D7 và 0 lượt đánh giá; chọn gửi đánh giá 4 sao (`Câu hỏi hay`), UI hiện `Cảm ơn bạn đã đánh giá!` và nút đổi thành `Đã chấm`. | PASS — preview cục bộ. `S-QB-04-statistics.png`, `S-QB-04-rating-sheet.png`, `S-QB-04-rating-success.png` |
| S-EXAM-01 | Đường UI Student vào màn đề thi khác shortcut Qbank. | NOT RUN — không quan sát đường dẫn UI khác; không deep-link hoặc gọi endpoint. `Đề thi` shortcut không hiện ở S-ROLE-01. |
| S-G2-04 | Tạo phiên QA mới 3 câu (1 AI, 2 tự soạn, phương án riêng và đáp án A) rồi đặt cược Game 2 hỗn hợp. | NOT RUN — đã thử tạo bản nháp mới nhưng IME nối lặp nội dung khi sửa trường; hủy bản nháp trước khi gửi. Không tạo session mới, không sửa session/câu seed 3/301/302. |
| S-G2-05 | Đặt số AI dương cho session 3 chỉ có câu tự soạn. | NOT RUN — UI không có trường AI khi số câu AI là 0; nhánh backend 400 không thể thử qua UI và không gọi endpoint trực tiếp. |
| S-G4-03 | Đặt trùng môn IT3011 sau prediction đã ghi nhận. | NOT RUN — màn Game 4 thay nút dự đoán bằng trạng thái đã đặt; không có action submit lại qua UI. Không ép 409 qua endpoint. |

**Đếm:** 23 PASS, 1 FAIL, 0 BLOCKED, 0 WAITING, 5 NOT RUN (29 case có ID trong bảng).

## Giới hạn và khôi phục

Giữa lượt chạy, hierarchy tạm chuyển sang ứng dụng khác. Một lần chụp màn hình đua thời điểm với chuyển ứng dụng và đã bắt nhầm khung hình; ảnh đã bị loại khỏi evidence và xóa, không commit. Không còn dữ liệu cá nhân trong evidence được giữ lại. User xác nhận quay lại QuizHub và lượt test tiếp tục từ Game 1. Không có bằng chứng crash hay lỗi app; lỗi overflow riêng ở S-GAME-LAYOUT-01 có bằng chứng screenshot. Không logout/reset, không thay setting thiết bị, không cài/gỡ app.

Source `lib/dev/preview_qbank.dart` ghi preview permissive với mọi role, không mô phỏng 403; `lib/dev/preview_games.dart` giả lập fixture/errors trong RAM. Vì vậy không dùng kết quả để xác nhận API thật, role authorization, persistence sau restart, chất lượng AI hay luật game ngoài preview. Không cập nhật issue tracker.
