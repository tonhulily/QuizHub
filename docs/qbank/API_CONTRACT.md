# Hợp đồng API: Ngân hàng câu hỏi + Đề thi + AI

Tài liệu của Bước 1 cho module "Question Bank + Exam + AI". Mỗi màn hình dùng endpoint nào, ai
được gọi, quy tắc nào phải giữ, chỗ nào backend còn thiếu. Viết code module thì tra file này trước.

- Nguồn: Swagger `https://snsqb.duckdns.org/api/v1/docs/openapi.json`, đọc ngày 24/10/2026 (128 endpoint).
- JSON thật: chạy `scripts/dump_qbank_api.sh` (mục 7), kết quả nằm trong `docs/api-samples/`.
  **Chỗ nào JSON thật khác Swagger thì theo JSON thật**, rồi sửa model và file này.
- Code tương ứng: model trong `lib/data/models/{subject_model,question_models,session_models,exam_models,ai_models}.dart`,
  repository trong `lib/data/repositories/`, dữ liệu mẫu trong `lib/dev/preview_qbank.dart`.

## 1. Khái niệm (khác hình dung ban đầu)

| Khái niệm | Nghĩa trong backend |
|---|---|
| **Session (phiên đề xuất)** | Một **bộ** câu hỏi trắc nghiệm mà một người nộp cho **một môn học**. Không phải "phiên làm bài". "Submission" trong bảng phân công chính là session của mình. |
| Trạng thái phiên | `PENDING` (chờ duyệt) → `REVIEWING` (giảng viên đã mở xem) → `RESOLVED` (đã xử lý xong). Chỉ sửa / xoá được khi `PENDING`. |
| Trạng thái câu hỏi | `PENDING` / `APPROVED` / `REJECTED`, duyệt **từng câu**. Phiên `RESOLVED` vẫn có thể có câu bị từ chối. |
| Thang 0 đến 4 | Dùng cho cả "độ tự tin" của tác giả và "đánh giá" của người khác: 0 sai hoàn toàn, 1 LLM bịa, 2 tác giả chưa vững, 3 cơ bản, 4 câu hỏi hay. |
| Nguồn câu hỏi | `HOMO_SAPIENS` (tự soạn) hoặc `LLM` (AI sinh). Lưu ý: khi **tạo** gửi `llm_generated: true/false`, khi **sửa** gửi `source`. |
| Độ khó, chủ đề | `UNCLASSIFIED` / `EASY` / `MEDIUM` / `HARD`, kèm `topic`. Chỉ có trong đề thi và kết quả tìm kiếm, người đề xuất không chọn. |

## 2. Quyền theo vai trò

| Chức năng | Sinh viên | Giảng viên |
|---|---|---|
| Xem môn, đề xuất / sửa / xoá phiên của mình | Có (chỉ môn đang học, khác môn thì 403) | Có |
| Luyện tập: xem câu hỏi, trả lời, đánh giá, thống kê | Có | Có |
| **Sinh đề, danh sách đề, chi tiết đề, xuất file** | **Không (403)** | Có |
| AI refine | Chưa rõ, cần thử bằng JSON thật | Có |
| **AI apply** (ghi đè câu hỏi bằng bản AI) | **Không** ("Giảng viên/Người kiểm duyệt") | Có |
| Duyệt phiên (approve / reject / complete-review) | Không | Có, **ngoài phạm vi module này** |

Hệ quả cho UI: nhánh Đề thi và nút Áp dụng AI phải **ẩn với sinh viên** (dựa vào `role` của
người đăng nhập), không đợi bấm vào rồi mới báo lỗi 403.

## 3. Bảng contract

Phân trang: con trỏ `after` (truyền lại `pagination.after` của trang trước), `limit` mặc định 10.
Riêng `/search` dùng offset. Mọi response bọc `{code, message, data}`, `ApiClient` tự bóc.

### 3.1 Môn học — `SubjectRepository`

| Màn hình | Thao tác | Endpoint | Hàm |
|---|---|---|---|
| Bộ lọc môn (Bank Home, My Exams) | Tất cả môn, A đến Z | `GET /subjects` | `all()` (có cache trong RAM) |
| Form tạo phiên | Môn mình đang học | `GET /sessions/my-enrolled-subjects` | `enrolled()` |

### 3.2 Phiên đề xuất của tôi — `SubmissionRepository`

| Màn hình | Thao tác | Endpoint | Hàm |
|---|---|---|---|
| My Submissions | Danh sách, lọc `status`, `subject_id` | `GET /sessions/my-submissions` | `mySubmissions()` |
| Submission Detail | Chi tiết phiên + mọi câu (có đáp án đúng, độ tự tin, người duyệt) | `GET /sessions/my-submissions/{id}` | `detail()` |
| Create Submission | Nộp phiên mới → 201, trạng thái `PENDING` | `POST /sessions/propose` | `propose()` |
| Edit Submission | Sửa thông tin + danh sách câu (chỉ `PENDING`) | `PUT /sessions/my-submissions/{id}` | `update()` |
| Submission Detail | Xoá phiên + toàn bộ câu, ảnh (chỉ `PENDING`) | `DELETE /sessions/my-submissions/{id}` | `delete()` |

Lỗi cần xử lý riêng: 403 (đã duyệt, không sửa được nữa, hoặc chưa đăng ký môn), 404 khi ảnh đính kèm hết
hạn lưu tạm (ảnh phải upload qua `/medias/...` ngay trước khi nộp).

### 3.3 Duyệt ngân hàng và luyện tập — `QuestionBankRepository`

| Màn hình | Thao tác | Endpoint | Hàm |
|---|---|---|---|
| Question Bank Home | Tìm phiên (có `status`) | `GET /search?type=SESSION&query=` | `searchSessions()` |
| Question Bank Home | Tìm câu hỏi (nhóm "Câu hỏi" trong kết quả) | `GET /search?type=QUESTION&query=` | `searchQuestions()` |
| Trang cá nhân, Bank Home | Phiên của một người (người khác chỉ thấy `RESOLVED`) | `GET /users/{id}/sessions` | `sessionsOfUser()` |
| Question Detail (trong phiên) | Mọi câu của phiên. Câu chưa trả lời thì **ẩn** `is_correct` và lời giải | `GET /sessions/{id}/questions` | `sessionQuestions()` |
| Answer | Nộp đáp án, nhận đúng / sai + lời giải | `POST /questions/{id}/answer` | `answer()` |
| Rating | Chấm 0 đến 4, kèm nhận xét hoặc cờ báo lỗi | `POST /questions/{id}/rate` | `rate()` |
| Rating | Danh sách đánh giá | `GET /questions/{id}/ratings` | `ratings()` |
| Statistics | Lượt làm, tỉ lệ đúng, phân bố A/B/C/D, phân bố sao | `GET /questions/{id}/statistics` | `statistics()` |

### 3.4 Đề thi (chỉ giảng viên) — `ExamRepository`

| Màn hình | Thao tác | Endpoint | Hàm |
|---|---|---|---|
| Exam Generator | Lớp học phần mình dạy (bắt buộc chọn ít nhất 1) | `GET /lecturer/course-classes/my-classes` | `myClasses()` |
| Exam Generator → Preview | Sinh đề: môn, số câu, tỉ lệ độ khó, trọng số chủ đề, lớp | `POST /exams/generate` | `generate()` |
| My Exams | Danh sách đề, lọc môn, `limit` tối đa 20 | `GET /exams/my-exams` | `myExams()` |
| Exam Detail | Câu hỏi theo thứ tự, đáp án, độ khó, chủ đề | `GET /exams/{id}` | `detail()` |
| Export | PDF / Excel, kèm đáp án hay không, khổ giấy → link tải có hạn | `GET /exams/{id}/export` | `exportFile()` |

### 3.5 AI — `AiRepository`

| Màn hình | Thao tác | Endpoint | Hàm |
|---|---|---|---|
| Nút "AI tinh chỉnh" trên câu hỏi **đã có id** | Gửi chỉ thị (tối đa 1000 ký tự) → bản gợi ý + kiểm định ảo giác + `edit_log_id` | `POST /questions/{id}/ai-refine` | `refine()` |
| Màn so sánh trước / sau | Áp dụng (`approve: true`) hoặc bỏ (`false`) theo `edit_log_id` | `POST /questions/{id}/ai-apply` | `apply()` |

## 4. Quy tắc nghiệp vụ phải giữ ở client

1. **Mỗi câu chỉ trả lời một lần**: server trả **409** nếu trả lời lại. Khoá nút sau khi nộp, đọc
   `my_interaction.answered` để biết câu đã làm.
2. Khi trả lời, gửi kèm `question_updated_at` **nguyên văn** chuỗi `updated_at` đã nhận
   (`PracticeQuestion.updatedAtRaw`). Server trả **412** nếu câu đã bị sửa từ lúc tải về: tải lại phiên.
3. Câu chưa trả lời thì `is_correct` vắng mặt (`QuestionOption.isCorrect == null`). Không suy đáp án từ đó.
4. Đánh giá: `rating` nguyên trong 0 đến 4; `is_error: true` thì server tự coi điểm là 0.
5. Sửa / xoá phiên chỉ khi `PENDING` (`SessionStatus.editable`). Ẩn nút ở các trạng thái khác.
6. Đề xuất chỉ cho môn trong `enrolled()`. Tiêu đề, nội dung câu bắt buộc (không rỗng). Độ tự tin trong 0 đến 4.
7. Tỉ lệ độ khó khi sinh đề nên có tổng bằng 1.0 (`DifficultyRatio.isValid`). `class_ids` không được rỗng.
8. AI: `prompt` tối đa 1000 ký tự. 403 `CONTENT_VIOLATES_POLICY` nghĩa là chỉ thị bị chặn (nghi prompt injection):
   báo người dùng sửa chỉ thị, không thử lại tự động. `refusal_reason` có giá trị thì AI từ chối, không có bản gợi ý.
9. Link xuất file có hạn (`expires_at`): mở ngay bằng `url_launcher`, không lưu link để dùng sau.

## 5. Model ↔ schema Swagger

| Model (Dart) | Schema | Ghi chú |
|---|---|---|
| `SubjectModel` | `SubjectResponse`, `SubjectSearchResultDto` | |
| `SubmissionSummary` | `SubmissionSessionSummaryDto`, `SessionSearchResultDto` | Danh sách nằm trong khoá **`contents`**, không phải `items` (`SubmissionSummary.pageFromJson`). Số câu là `question_counts` (danh sách) hoặc `question_count` (tìm kiếm) |
| `SubmissionDetail`, `SubmissionQuestion` | `MySubmissionDetailResponse`, `MySubmissionQuestionDto` | |
| `SessionQuestions`, `PracticeQuestion` | `SessionQuestionsResponse`, `PracticeQuestionDto` | Đáp án đúng, lời giải trong `hidden_fields` |
| `QuestionOption` | `QuestionOption`, `OptionDto` | `isCorrect` có thể null |
| `AnswerResult`, `RateResult`, `RatingItem`, `QuestionStatistics` | `AnswerQuestionResponse`, `RateQuestionResponse`, `RatingItemDto`, `QuestionStatisticsResponse` | |
| `SessionDraft`, `QuestionDraft` | `ProposeSessionRequest` / `QuestionProposeDto`, `UpdateSubmissionSessionRequest` / `QuestionUpdateDto` | Hai hàm `toProposeJson()` và `toUpdateJson()` vì hai body khác nhau |
| `ExamSummary`, `ExamDetail`, `ExamQuestion`, `ExamStatistic` | `ExamItem`, `ExamDetailResponse`, `ExamQuestionDto`, `Statistic` | |
| `GenerateExamInput`, `DifficultyRatio` | `GenerateExamRequest`, `DifficultyDistribution` | |
| `ExportResult`, `CourseClassModel` | `ExportResponse`, `CourseClassResponse` | |
| `AiRefineResult`, `AiViolation`, `AiApplyResult` | `AiRefineResponse` (+ `SuggestedQuestionDto`, `BtpropAuditDto`, `AiMetadataDto`), `AiApplyResponse` | |

## 6. Backend còn thiếu / chưa rõ: cần chốt trước khi làm UI

| # | Vấn đề | Ảnh hưởng | Đề xuất / câu hỏi |
|---|---|---|---|
| 1 | **Không có API liệt kê ngân hàng câu hỏi theo môn.** Chỉ có `/search` (cần từ khoá, không lọc môn) và `/users/{id}/sessions` | Question Bank Home không có nguồn dữ liệu chuẩn | Xin backend `GET /sessions?subject_id=&status=RESOLVED` (phân trang con trỏ). Tạm thời dùng `/search?type=SESSION`; cần thử `query` rỗng có trả hết không |
| 2 | **Không có `GET /questions/{id}`** | Question Detail không mở trực tiếp bằng id được (vd từ thông báo, tìm kiếm câu hỏi) | Tạm lấy từ `GET /sessions/{id}/questions`. Kết quả tìm kiếm QUESTION **không có `session_id`**: xin backend thêm `session_id` vào `QuestionSearchResultDto`. App đã đọc trường này nếu có (bấm câu thì mở phiên, nhảy tới câu); thiếu thì chỉ xem trước nội dung |
| 3 | Swagger của **danh sách phiên** và **chi tiết phiên** không có trường `status`; câu hỏi trong chi tiết không có trạng thái duyệt | Không hiện được nhãn Chờ duyệt / Đã duyệt, không biết lúc nào cho sửa | Kiểm tra JSON thật. Model đã đọc `status` nếu có, thiếu thì là `unknown` (khoá sửa / xoá) |
| 4 | `GET /sessions/{id}/questions` của phiên `RESOLVED` trả **mọi câu** hay **chỉ câu `APPROVED`**? | Người luyện tập có thể thấy câu bị từ chối | Hỏi backend |
| 5 | `PUT` sửa phiên: câu **không gửi lên** thì bị xoá hay giữ nguyên? | Xoá một câu trong form có thể không có tác dụng | Hỏi backend |
| 6 | Sinh viên gọi `ai-refine` được không? Refine chỉ dùng được cho câu **đã có id** | Không thể nhờ AI khi đang soạn câu mới (trước khi nộp) | Hỏi backend; nếu đúng thì nút AI chỉ có ở phiên đã nộp và còn `PENDING` |
| 7 | Đánh giá lại lần hai được không (ghi đè hay 409)? | Màn Rating có cho sửa không | Thử bằng tài khoản test |
| 8 | Danh sách đánh giá chỉ có `user_id`, **không có tên / ảnh** | Không hiện được người đánh giá | Xin thêm `author` như bình luận. Tạm thời app gọi `GET /users/{id}` cho từng người (`UserDirectory`, cache theo id), lỗi thì hiện "Người dùng #id" |
| 9 | Giá trị `format` khi xuất: `excel` hay `xlsx`? | Có thể nhận lỗi 400 khi xuất Excel | Model đang gửi `excel`; thử cả hai |
| 10 | Sinh đề cần `class_ids`, nhưng **sinh viên không có lớp dạy** | Bảng phân công ghi "Sinh đề" nhưng sinh viên bị 403 | Chốt với nhóm: nhánh Đề thi chỉ hiện cho giảng viên, test bằng tài khoản giảng viên hoặc bản xem trước |
| 12 | Câu hỏi trong chi tiết phiên (`MySubmissionQuestionDto`) có `react_count`, `comment_count` nhưng **không có `reacted_by_me`** | Nút Thích dưới mỗi câu không biết mình đã thích chưa khi mở màn | Xin thêm `reacted_by_me` như `PostResponseDto`. App đã đọc nếu có; bấm Thích thì lấy trạng thái + số từ kết quả `POST /react` |
| 11 | `GET /sessions/{id}` (bản cho giảng viên duyệt) **tự chuyển phiên sang `REVIEWING`** | Mở nhầm bằng tài khoản giảng viên làm đổi dữ liệu thật | Module này không gọi API đó; script lấy mẫu cũng đã bỏ |

Câu trả lời của backend ghi thẳng vào bảng trên (thêm cột "Trả lời") để cả nhóm cùng tra.

## 7. Lấy JSON thật

Chạy ở thư mục gốc dự án, bằng tài khoản **của chính bạn** (script chỉ gọi GET, không ghi dữ liệu,
không lưu token):

```bash
EMAIL=ban@sis.hust.edu.vn PASSWORD='mat-khau' bash scripts/dump_qbank_api.sh
# Lần 2, khi đã biết id (lấy phiên ĐÃ DUYỆT từ search_sessions*.json):
EMAIL=... PASSWORD='...' SESSION_ID=12 QUESTION_ID=105 EXAM_ID=3 bash scripts/dump_qbank_api.sh
```

Đọc bảng in ra: `200` có API, `403` không đủ quyền (cũng là thông tin), `404/405` sai đường dẫn.
Sau đó so từng file với model ở mục 5, lệch chỗ nào thì sửa `fromJson` và thêm test.
Nếu JSON có thông tin cá nhân của người khác, đừng commit file đó (`docs/api-samples/` chỉ để đối chiếu).
