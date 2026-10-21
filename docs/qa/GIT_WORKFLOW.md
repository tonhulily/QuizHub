# Quy trình Git cho QA cá nhân

Hướng dẫn này giữ công việc của tester trên nhánh local `qa/khanhson2005` và cập nhật mã từ upstream `main`.

## Ranh giới nhánh

- `main` là nguồn duy nhất để nhận thay đổi app.
- `qa/khanhson2005` là nhánh QA cá nhân lâu dài, chỉ để kiểm thử và lưu test, cấu hình, tài liệu, bằng chứng QA.
- Có thể merge `origin/main` vào QA để kiểm tra snapshot mới.
- Tuyệt đối không merge QA vào `main` hay nhánh khác, không mở PR từ QA, và không push nếu chưa có yêu cầu rõ ràng trong phạm vi công việc sau này.
- Mặc định mã runtime trên QA phải giống `main` đã tích hợp. Không mang riêng hành vi runtime QA sang; giới hạn thay đổi QA vào test, cấu hình QA và tài liệu.
- Dùng `git fetch origin` để cập nhật thông tin remote rồi kiểm tra SHA và diff. Fetch không đẩy commit.
- Không dùng `git pull`, `reset --hard`, `clean -fd` hoặc stash tự động trong quy trình này.

## Bắt đầu phiên QA

Kiểm tra nhánh và working tree:

```bash
git branch --show-current
git status --short
```

Chỉ tiếp tục trên `qa/khanhson2005`. Nếu nhánh chưa tồn tại, tạo từ `origin/main` sau khi fetch:

```bash
git fetch origin
git switch --no-track -c qa/khanhson2005 origin/main
```

Nếu nhánh đã tồn tại, chuyển sang nhánh đó khi working tree sạch:

```bash
git switch qa/khanhson2005
```

Nếu `git status --short` có kết quả, xem diff và lưu công việc bằng checkpoint có chủ đích hoặc dừng phiên. Không bắt đầu đồng bộ khi còn thay đổi chưa lưu; không stash hay xóa chúng để làm sạch trạng thái.

Khi chạy QA, ghi commit nguồn đang thử:

```bash
git rev-parse HEAD
git log -1 --oneline --decorate
```

## Cập nhật từ upstream main

`git fetch` đã được dùng trong phiên hướng dẫn này chưa? Chưa; chưa fetch hay đồng bộ branch nào. Khi bắt đầu phiên QA thực, chạy:

```bash
git fetch origin
```

Xác nhận đang ở đúng nhánh và working tree sạch:

```bash
git branch --show-current
git status --short
```

Ghi SHA đầy đủ trước khi merge. `BASE_BEFORE` phải là SHA `main` thực tế đã được tích hợp gần nhất; kiểm tra lịch sử merge nếu chưa có ghi nhận từ phiên trước. `git merge-base` là gợi ý để tìm điểm chung, không thay cho xác nhận mốc tích hợp:

```bash
QA_BEFORE=$(git rev-parse HEAD)
MAIN_SNAPSHOT=$(git rev-parse origin/main)
BASE_BEFORE=$(git merge-base HEAD origin/main)
printf 'QA_BEFORE=%s\nMAIN_SNAPSHOT=%s\nBASE_BEFORE=%s\n' "$QA_BEFORE" "$MAIN_SNAPSHOT" "$BASE_BEFORE"
git log --merges --first-parent --oneline HEAD
```

Nếu merge history không xác nhận `BASE_BEFORE` là commit upstream đã tích hợp lần trước, dùng SHA đã ghi trong handoff trước. Không suy đoán rồi ghi nó thành baseline.

So sánh công việc QA riêng và phần upstream kể từ baseline đã tích hợp:

```bash
git log --oneline --left-right "${QA_BEFORE}...${MAIN_SNAPSHOT}"
git diff --stat "${BASE_BEFORE}..${QA_BEFORE}"
git diff --stat "${BASE_BEFORE}..${MAIN_SNAPSHOT}"
git diff --name-status "${BASE_BEFORE}..${QA_BEFORE}"
git diff --name-status "${BASE_BEFORE}..${MAIN_SNAPSHOT}"
git diff "${BASE_BEFORE}..${MAIN_SNAPSHOT}"
```

Diff từ `BASE_BEFORE` tới `MAIN_SNAPSHOT` cho biết thay đổi upstream cần nhận kể từ bản `main` đã tích hợp. Xác nhận phạm vi và mọi file giao nhau trước khi merge.

Đọc danh sách file QA thay đổi. Nếu có sửa mã runtime app riêng trên QA, dừng và xử lý thay đổi đó trước khi đồng bộ; không để merge/rebase mang runtime riêng sang snapshot mới. Mặc định chỉ giữ test, cấu hình QA và tài liệu.

## Merge mặc định, ghim theo SHA

Merge commit giữ lịch sử QA và cho biết snapshot upstream nào đã được nhập. Sau khi đã lưu `MAIN_SNAPSHOT`, dùng chính SHA đó; không merge tên ref có thể di chuyển như `origin/main`:

```bash
git merge-base --is-ancestor "$MAIN_SNAPSHOT" "$QA_BEFORE"
```

Nếu lệnh trên thành công, `MAIN_SNAPSHOT` đã có trong QA: Git sẽ báo `Already up to date` nếu merge, và không tạo merge commit. Không chạy `git commit` sau trường hợp này. Ghi nhận `TESTED_SHA` sẽ là SHA QA thực tế sau đó và tiếp tục quy trình kiểm thử.

Nếu SHA chưa được tích hợp, bắt đầu merge có kiểm soát:

```bash
git merge --no-ff --no-commit "$MAIN_SNAPSHOT"
```

Khi không có conflict, xem staged diff và kiểm tra tĩnh trước khi commit:

```bash
git status
git diff --cached --check
git diff --cached --stat
git diff --cached
git diff --name-only --diff-filter=U
```

Nếu các kiểm tra tĩnh sạch và nội dung đã được duyệt, tạo riêng merge commit:

```bash
git commit -m "chore(qa): sync main $MAIN_SNAPSHOT"
```

Ghi SHA merge commit. Chỉ sau commit mới chạy regression thật. Các kiểm tra staged diff trước commit chỉ là rà soát sơ bộ, không phải bằng chứng QA cho một `TESTED_SHA`.

## Xử lý conflict

Khi Git báo conflict, merge đang dở. Xem trạng thái và danh sách file:

```bash
git status
git diff --name-only --diff-filter=U
```

Với từng file, có thể xem base, QA hiện tại và upstream tương ứng:

```bash
git show :1:path/to/file
git show :2:path/to/file
git show :3:path/to/file
```

Trong merge, stage 1 là base, stage 2 là nhánh QA, stage 3 là SHA upstream đang merge. Thay đường dẫn ví dụ bằng file cụ thể.

- Với mã runtime app, giữ phiên bản từ `MAIN_SNAPSHOT`; không áp lại hành vi runtime riêng của QA. Chỉ đổi quy tắc này nếu một yêu cầu tương lai xác định rõ phạm vi khác.
- Với test QA, fixture, tài liệu và cấu hình dành riêng cho QA, giữ nội dung cá nhân và cập nhật phần phụ thuộc vào app khi cần.
- Nếu một file chứa nội dung cần từ cả hai phía, giải quyết thủ công và xem toàn bộ kết quả.
- Không chọn `--ours` hoặc `--theirs` cho toàn bộ merge. Dùng một phía cho một file riêng lẻ chỉ khi nội dung file đó đã được kiểm tra.

Stage từng file đã giải quyết, rồi xác nhận không còn conflict và xem staged diff:

```bash
git add path/to/resolved-file
git diff --name-only --diff-filter=U
git diff --cached --check
git diff --cached
git status
```

Sau khi rà soát tĩnh xong, commit merge riêng như bước trên. Chạy regression thật trên commit đã tạo; nếu chưa thể giải quyết an toàn, dừng và giữ nguyên trạng thái để tiếp tục sau. Không xóa thay đổi bằng reset.

## Rebase tùy chọn, không phải mặc định

Rebase chỉ dành cho chuỗi QA local chưa chia sẻ gồm test, cấu hình QA và tài liệu khi cần lịch sử tuyến tính. Nó viết lại SHA các commit QA; không rebase lịch sử đã chia sẻ, đã push hoặc đang được dùng làm bằng chứng cần giữ. Không rebase chuỗi có thay đổi runtime riêng và không luân phiên merge với rebase cùng chuỗi commit.

Nếu có lý do cụ thể để rebase, ghi checkpoint trước rồi dùng SHA upstream đã chụp:

```bash
git rebase "$MAIN_SNAPSHOT"
```

Giải quyết conflict theo từng file, giữ runtime theo upstream như quy tắc trên, rồi xác minh lại diff và SHA. `git rebase --abort` chỉ hủy rebase đang dở để quay về trạng thái trước rebase. Không force-push. Với QA thường lệ, dùng merge mặc định.

## Chạy và ghi nhận QA

Sau khi merge đã commit, lấy SHA nguồn chính xác:

```bash
TESTED_SHA=$(git rev-parse HEAD)
git status --short
printf 'TESTED_SHA=%s\n' "$TESTED_SHA"
```

Chạy regression trên working tree sạch tại `TESTED_SHA`. Nếu có sửa lỗi hay thay đổi file sau đó, commit checkpoint mới và chạy lại các kiểm tra bị ảnh hưởng; không gắn kết quả cũ vào SHA mới.

Trong báo cáo/handoff, ghi riêng:

- `MAIN_SNAPSHOT`: SHA upstream đã tích hợp; không thay bằng giá trị mới hơn của `origin/main` sau này.
- `QA_BEFORE`: SHA nhánh QA trước khi đồng bộ.
- `TESTED_SHA`: commit chính xác đã chạy regression.
- Kết quả lệnh, thiết bị/môi trường, thời gian chạy, lỗi còn mở và đường dẫn bằng chứng.

Khi `main` tiến thêm sau này, kết quả vẫn mô tả chính xác cặp snapshot `MAIN_SNAPSHOT` và `TESTED_SHA`; nó không chứng nhận `main` mới hơn.

## Commit QA và so sánh upstream sạch

Giữ commit QA nhỏ và tách commit đồng bộ upstream khỏi commit test/tài liệu QA, ví dụ:

```text
chore(qa): sync main <sha>
test(qa): cover profile refresh after reconnect
docs(qa): record android smoke results
```

Đặt test riêng dưới `test/qa/` khi phù hợp. Test QA không thay thế CI, không chứng nhận release upstream và không được nhập ngược vào `main` theo quy trình này.

Khi cần so sánh với upstream sạch, tạo worktree detached đúng `MAIN_SNAPSHOT`:

```bash
git worktree add --detach .worktrees/main-baseline "$MAIN_SNAPSHOT"
```

`.worktrees/` phải được ignore trước khi tạo worktree. Không dùng chung build, dữ liệu, credentials hay cài đặt app nếu chúng làm nhiễu so sánh. Sau khi lưu kết quả, dọn worktree nếu sạch:

```bash
git worktree remove .worktrees/main-baseline
```

Đây là bước tùy chọn. Hướng dẫn này chưa tạo worktree, fetch hay đồng bộ nhánh.

## Tài liệu Git chính thức

- [git-merge](https://git-scm.com/docs/git-merge)
- [git-rebase](https://git-scm.com/docs/git-rebase)
- [git-worktree](https://git-scm.com/docs/git-worktree)
