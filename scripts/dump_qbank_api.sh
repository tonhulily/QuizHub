#!/usr/bin/env bash
# Gọi thử các API GET của module Ngân hàng câu hỏi + Đề thi, lưu JSON THẬT vào
# docs/api-samples/ để đối chiếu model (Swagger thiếu vài trường, vd `status`
# trong danh sách phiên). Hợp đồng API: docs/qbank/API_CONTRACT.md
#
# Dùng (chạy ở thư mục gốc dự án):
#   EMAIL=ban@sis.hust.edu.vn PASSWORD='matkhau' bash scripts/dump_qbank_api.sh
# Lần 2, khi đã biết id từ kết quả lần 1 (nên lấy phiên ĐÃ DUYỆT trong
# search_sessions*.json, câu hỏi của phiên đó, đề thi trong my_exams.json):
#   EMAIL=... PASSWORD='...' SESSION_ID=12 QUESTION_ID=105 EXAM_ID=3 \
#     bash scripts/dump_qbank_api.sh
#
# Chỉ gọi GET (không tạo/sửa dữ liệu), không lưu token ra file.
# KHÔNG gọi GET /sessions/{id}: với tài khoản giảng viên, API đó chuyển phiên
# của người khác sang REVIEWING (thay đổi dữ liệu thật).
set -u
BASE="${API_BASE_URL:-https://snsqb.duckdns.org/api/v1}"
OUT="docs/api-samples"
mkdir -p "$OUT"
: "${EMAIL:?Thiếu EMAIL}"
: "${PASSWORD:?Thiếu PASSWORD}"

# Spec đầy đủ (công khai) để tra schema khi viết model
curl -sS -L -o "$OUT/openapi.json" "$BASE/docs/openapi.json"

login=$(curl -sS -L -X POST "$BASE/auth/login" \
  -H 'Content-Type: application/json' -H 'Accept: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"device_id\":\"api-dump-script\",\"platform\":\"ANDROID\",\"device_name\":\"api-dump-script\",\"os_version\":\"0\",\"app_version\":\"1.0.0\"}")
TOKEN=$(printf '%s' "$login" | sed -n 's/.*"access_token" *: *"\([^"]*\)".*/\1/p')
ROLE=$(printf '%s' "$login" | sed -n 's/.*"role" *: *"\([^"]*\)".*/\1/p')
ME=$(printf '%s' "$login" | sed -n 's/.*"user_id" *: *\([0-9][0-9]*\).*/\1/p')
if [ -z "$TOKEN" ]; then
  echo "Đăng nhập thất bại: $login"
  exit 1
fi
echo "Đăng nhập OK (role: ${ROLE:-?}, user_id: ${ME:-?})"
echo "-----------------------------------------------------------------"
printf '%-28s %-5s %s\n' "FILE" "HTTP" "PATH"

call() { # call <tên-file> <path>
  local code
  code=$(curl -sS -L -o "$OUT/$1.json" -w '%{http_code}' \
    -H "Authorization: Bearer $TOKEN" -H 'Accept: application/json' "$BASE$2")
  printf '%-28s %-5s %s\n' "$1" "$code" "$2"
}

# --- Môn học ---
call subjects                  "/subjects"
call my_enrolled_subjects      "/sessions/my-enrolled-subjects"
# --- Phiên đề xuất của tôi (xem có trường `status` không) ---
call my_submissions            "/sessions/my-submissions"
call my_submissions_paged      "/sessions/my-submissions?limit=2"
call my_submissions_pending    "/sessions/my-submissions?status=PENDING"
call my_submissions_resolved   "/sessions/my-submissions?status=RESOLVED"
[ -n "$ME" ] && call my_sessions_public "/users/$ME/sessions"
# --- Duyệt ngân hàng: chưa có API theo môn, thử tìm kiếm (có / không từ khoá) ---
call search_sessions_empty     "/search?type=SESSION"
call search_sessions           "/search?type=SESSION&query=on"
call search_questions          "/search?type=QUESTION&query=thuat"
# --- Lỗi mẫu (để biết format lỗi thật) ---
call err_submission_404        "/sessions/my-submissions/999999999"
code=$(curl -sS -L -o "$OUT/err_no_token.json" -w '%{http_code}' \
  -H 'Accept: application/json' "$BASE/sessions/my-submissions")
printf '%-28s %-5s %s\n' "err_no_token" "$code" "/sessions/my-submissions (không token)"
# --- Giảng viên (sinh viên nhận 403: cũng là thông tin cần lưu) ---
call my_exams                  "/exams/my-exams"
call lecturer_classes          "/lecturer/course-classes/my-classes"
call sessions_pending          "/sessions/pending"
# --- Gamification (để dành cho module khác) ---
call leaderboard               "/games/leaderboard"
call my_predictions            "/games/my-predictions"
call check_in                  "/games/check-in"

if [ -n "${SESSION_ID:-}" ]; then
  call submission_detail       "/sessions/my-submissions/$SESSION_ID"
  call session_questions       "/sessions/$SESSION_ID/questions"
fi
if [ -n "${QUESTION_ID:-}" ]; then
  call question_ratings        "/questions/$QUESTION_ID/ratings"
  call question_statistics     "/questions/$QUESTION_ID/statistics"
fi
if [ -n "${EXAM_ID:-}" ]; then
  call exam_detail             "/exams/$EXAM_ID"
  call exam_export_pdf         "/exams/$EXAM_ID/export"
  call exam_export_excel       "/exams/$EXAM_ID/export?format=excel"
  call exam_export_xlsx        "/exams/$EXAM_ID/export?format=xlsx"
fi

# Đăng xuất phiên của script để không để lại thiết bị lạ trong tài khoản
curl -sS -L -o /dev/null -X POST "$BASE/auth/logout" -H "Authorization: Bearer $TOKEN"
echo "-----------------------------------------------------------------"
echo "Xong. Kết quả trong $OUT/  (200 = có API; 404/405 = sai đường dẫn; 403 = không đủ quyền)"
echo "Đối chiếu với docs/qbank/API_CONTRACT.md mục 5 và 6."
