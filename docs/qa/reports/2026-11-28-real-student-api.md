# Student API smoke và web runtime — 2026-11-28

## Student API baseline

- **Kết quả:** 53 PASS, 0 FAIL, 0 BLOCKED, 1 WAITING / 54 probes.
- **Source SHA:** `c34ece09f92f06103257eabfa2c92a92d46d40a3`.
- **Host:** `snsqb.duckdns.org`.
- **Lệnh:** `python3 qa/api/real_student_probe.py --phase baseline --output docs/qa/evidence/2026-11-28/real-api/baseline.json`; exit `0`. Credentials được truyền qua stdin, không lưu trong evidence.
- **Tài khoản:** bốn tài khoản student. Login, identity, refresh, logout và xác nhận refresh token bị thu hồi đều đạt; anonymous `/users/me` trả `401/9998`, student gọi lecturer-only endpoint trả `403/1009`.
- **Phạm vi:** các GET đọc cho settings, subjects, submissions, search, posts, notifications, games, friendships/follows, devices, cosmetics, conversations, blocks, badges và activity feeds. Đây là API smoke có giới hạn, không phải toàn bộ acceptance hoặc UI.

Contract gap còn **WAITING**: tài liệu OpenAPI khai báo `GET /sessions/my-enrolled-subjects`, runtime trả `404/1012`; route app đang dùng `GET /sessions/my-enrolled-course-classes` trả `200/1000`, một lớp. Chưa kết luận bug; cần owner xác nhận route chuẩn và cập nhật tài liệu.

## Chat API hai tài khoản

- **Source SHA:** `30bb1ef8227c8f5fa9f5244c39e4a4f134c79ced`.
- **Lệnh:** `node qa/api/real_chat_probe.mjs --output docs/qa/evidence/2026-11-28/real-api/chat-final.json`; credentials hai tài khoản test truyền qua stdin; exit `0`.
- **Kết quả:** 9/9 PASS: hai login, tạo/lấy direct conversation (`201`), hai STOMP socket, nhận marker QA, REST history (`200/1000`), thu hồi `EVERYONE` và xác minh `revoked=true` (`200/1000`), hai logout.
- GET history đánh dấu hội thoại đã đọc. Direct conversation có thể được tạo hoặc lấy lại; không xóa hội thoại. Marker duy nhất đã thu hồi và kiểm tra không log nội dung tin nhắn.
- Evidence: [chat-final.json](../evidence/2026-11-28/real-api/chat-final.json). Lần chạy đầu trước khi cập nhật cleanup được giữ local trong ignored `qa-artifacts/2026-11-28/chat-initial.json`, không dùng làm kết quả cuối.

## Social API hai tài khoản

- **Source SHA:** `1255b538b44f885a0d72c59aaccd5f759f1ebe59`.
- **Lệnh:** `python3 qa/api/real_social_probe.py --output docs/qa/evidence/2026-11-28/real-api/social-final.jsonl`; credentials hai tài khoản test truyền qua stdin; exit `0`.
- **Kết quả:** 13 invariant PASS và 22 HTTP_PASS, 0 FAIL/WAITING/BLOCKED. Đây là số assertion và HTTP checks, không phải 35 test case độc lập.
- Luồng quan sát: đọc bài public/riêng theo A/B, comment, like on/off, danh sách comment, A bị từ chối khi xóa comment của B (`403/1009`); B xóa comment của mình (`200/1000`). A tạo bài test; các bài test được xóa sau kiểm tra; cleanup báo `0` còn lại và cả hai logout `200/1000`.
- Comment sau khi xóa vẫn có tombstone: cùng ID còn trong history với `deleted=true`, `hidden=true`, author null và nội dung không còn khớp marker QA. Lần chạy đầu thoát `1` vì harness đòi row biến mất; đây là giả định kiểm tra sai, không phải bug đã xác nhận. Lần cuối kiểm tra tombstone theo model và đạt.
- Evidence: [social-final.jsonl](../evidence/2026-11-28/real-api/social-final.jsonl), [initial harness run](../evidence/2026-11-28/real-api/social-initial-harness.jsonl). Lượt ban đầu tại source `30bb1ef8227c8f5fa9f5244c39e4a4f134c79ced` thoát `1` do assertion yêu cầu comment ID biến mất. Lượt cuối tại source `1255b538b44f885a0d72c59aaccd5f759f1ebe59` kiểm tra tombstone flags của model và thoát `0`.

## Academic API hai tài khoản

- Lượt đầu tại source `939445c288fdb52b507b1634cd624d30d34d48b1`: **7 PASS, 2 FAIL, 2 BLOCKED, 4 WAITING**; command exit `0` cho biết runner ghi xong kết quả, không phải tất cả case đạt. Hai FAIL do harness dựa trên schema/path cũ: `/exams/my-exams` (404/1012) và fixture đề xuất hai câu không đạt giới hạn tối thiểu ba câu. Đã giữ [evidence lượt đầu](../evidence/2026-11-28/real-api/academic-initial-harness.json); không coi các FAIL đó là lỗi app.
- Live OpenAPI yêu cầu `/sessions/propose` có `course_class_id`, `title`, `questions` tối thiểu 3 câu; từng câu cần `confidence`, `content`, `llm_generated`, `options`. Form app cũng giới hạn tối thiểu 3 câu. Route exam hiện là `/lecturer/exams/my-exams`. Chi tiết và hash snapshot: [live contract](../evidence/2026-11-28/real-api/live-contract.txt).
- Corrected run tại source `7ed7d7d11893838a20b2d2ea577569ba0997747c`: `python3 qa/api/real_academic_probe.py --output docs/qa/evidence/2026-11-28/real-api/academic-final.json`; hai student accounts qua stdin; exit `0`, **15 PASS, 0 FAIL, 0 BLOCKED, 5 WAITING / 20 case**. Tạo đề xuất QA 3 câu (`201/1000`), đọc chi tiết (`200/1000`), update (`200/1000`) và xác minh giữ đủ 3 câu, xóa (`200/1000`) rồi xác minh vắng (`404/2008`). Student khác bị từ chối khi mở phiên PENDING (`403/1009`); student vào lecturer exams route cũng bị từ chối (`403/1009`). Cả hai logout `200/1000`.
- Năm WAITING: route exam legacy `/exams/my-exams` vẫn `404/1012` và bốn case cần phiên RESOLVED do không có fixture đã duyệt (detail, practice, statistics, ratings). Chưa dùng tài khoản lecturer. [Final evidence](../evidence/2026-11-28/real-api/academic-final.json).

## Student utilities API hai tài khoản

- **Source SHA:** `dbdb2c5d4483f5e299d6970d489f7354015efafc`; `python3 qa/api/real_student_utilities_probe.py --output docs/qa/evidence/2026-11-28/real-api/utilities-final.json`; credentials `son` và `nam` qua stdin; exit `0`.
- **Kết quả:** 31/31 PASS, 0 lỗi/chờ.
- Đã xác minh public profile không lộ email/ngày sinh; feed cursor qua hai trang không lặp ID; saved search tạo/tìm/xóa và xác nhận đã vắng; push settings cập nhật rồi khôi phục và so khớp đầy đủ baseline; follow từ `following=false` thành `true`, rồi hủy follow và xác minh trả về `false`. Hai tài khoản logout thành công.
- Lượt utility đầu có một WAITING do harness đọc `is_following` từ relationship-stats response. Final run dùng field `following` theo contract hiện tại và đạt; [initial harness evidence](../evidence/2026-11-28/real-api/utilities-initial-harness.json) được giữ để trace, không dùng thay cho lượt cuối. [Final evidence](../evidence/2026-11-28/real-api/utilities-final.json).

## Web build và đăng nhập

- **Source SHA:** `0a1fbf8d0f26bcf00b3e40c3ce3647df18359221`.
- **Build:** `.qa-tools/flutter/bin/flutter build web --no-pub -t lib/main.dart --output qa-artifacts/2026-11-28/real-api-web`; exit `0` (93 giây). Build thành công không xác nhận browser flows hoặc API.
- **Browser:** login page tại `http://127.0.0.1:4183/#/login` hiển thị. Login student bị chặn ở preflight CORS khi gọi `https://snsqb.duckdns.org/api/v1/auth/login`: response thiếu `Access-Control-Allow-Origin`; **không gửi auth POST**, không có kết quả đăng nhập.
- **Cleanup:** browser đã đóng; local server port `4183` đã dừng bằng Ctrl-C, exit `0`.
- **Evidence:** [web environment](../evidence/2026-11-28/real-api/web-environment.txt), [baseline JSON](../evidence/2026-11-28/real-api/baseline.json). Full logs/build output nằm trong `qa-artifacts/` và bị ignore.

Các self-check offline đều exit `0` tại source `dbdb2c5d4483f5e299d6970d489f7354015efafc`; không gửi request mạng: `python3 qa/api/real_student_probe.py --phase baseline --output /tmp/real-student-self-check.json --self-check`, `python3 qa/api/real_social_probe.py --self-check`, `SOURCE_SHA=dbdb2c5d4483f5e299d6970d489f7354015efafc node qa/api/real_chat_probe.mjs --self-check`, `python3 qa/api/real_academic_probe.py --output /tmp/real-academic-self-check.json --self-check`, `python3 qa/api/real_student_utilities_probe.py --self-check --output /tmp/real-utilities-self-check.json`. Chúng chỉ xác minh runner/parser, không phải API evidence.

Còn **NOT RUN** trong phạm vi lượt này: native app/FCM/media; positive lecturer flows; practice/answer/rating cần fixture RESOLVED đã xác minh; sửa profile/password; mutations chấp nhận/từ chối/chặn bạn bè; và các hành động tiêu thụ trong game. Kết quả GET không bao phủ các mutation này. Không có bug app mới được xác nhận.

Ma trận acceptance 25 case không đổi: **24 NOT RUN, 1 WAITING, 0 PASS, 0 FAIL**. Các smoke/API probes và browser build được ghi riêng, không cộng vào matrix. Không dùng phone hay tài khoản lecturer trong lượt web này. Chat history GET có side effect đánh dấu hội thoại đã đọc; social xóa bài/comment theo tombstone semantics, nên không khẳng định đã hard-delete toàn bộ dữ liệu phía server.

Môi trường: Linux `6.18.54.1-microsoft-standard-WSL2` x86_64, Python `3.12.3`, Node `v24.14.1`. Tại integration HEAD `dbdb2c5d4483f5e299d6970d489f7354015efafc`, `git diff --exit-code origin/main HEAD -- lib android ios pubspec.yaml pubspec.lock` exit `0`; app runtime và dependency/lock files khớp upstream snapshot `82ef14f38e086d6b558b392fc54a328c3d7f26a2`.
