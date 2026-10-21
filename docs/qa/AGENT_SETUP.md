# Cấu hình Codex cho QA

- [`AGENTS.md`](../../AGENTS.md): phạm vi QA, nhánh, delegation và bằng chứng áp dụng cho toàn repo.
- [`quizhub-qa`](../../.agents/skills/quizhub-qa/SKILL.md): quy trình QA; tự động discovery hoặc gọi trực tiếp `$quizhub-qa`.
- [`qa.rules`](../../.codex/rules/qa.rules): hỏi trước lệnh `git push`; không thay quyền người dùng hay chính sách nhánh.
- [QA matrix](../../QA.md), [kế hoạch test](TEST_PLAN.md), [quy trình Git](GIT_WORKFLOW.md): nguồn chi tiết về case và cách chạy.

Main session chỉ điều phối và giao việc cho agent; không tự triển khai, không kiểm tra tiến độ hoặc đọc file trung gian. Chờ agent gửi kết quả rồi review, sửa giao việc hoặc khởi chạy lại khi cần. Mặc định dùng `gpt-6-luna` mức low; quyền delegation đã được Sơn cấp cho workflow QA này.

Codex discovery phụ thuộc thời điểm khởi tạo phiên; phiên đang mở có thể chưa nạp cấu hình vừa sửa. Rules trong `.codex/rules/` chỉ được nạp khi project được trust. Rule `git push` chỉ là lớp hỏi xác nhận cho shell-prefix khớp; nó không chặn alias hay plugin và không cấp quyền push.

Nguồn chính thức: [AGENTS.md](https://developers.openai.com/codex/guides/agents-md), [Skills](https://developers.openai.com/codex/skills), [Rules](https://developers.openai.com/codex/rules).
