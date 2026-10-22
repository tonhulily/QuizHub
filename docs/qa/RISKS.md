# Rủi ro QA cần xác minh

Đánh giá code ban đầu dựa trên runtime snapshot `2af89368608946ac8949766776f527d589495fe8`.
Hai invariant client dưới đây được chạy với `ApiClient`/`AuthInterceptor` thật và Dio
adapter giả trong Flutter test. Lần chạy đầu dùng QA source
`d58cdf01a4b2e04a41901e8804fe1d49847faccf`; xác nhận lại sau merge upstream trên
`520c7381f0159ce40f9534ace1c657b87aa523d1` (runtime snapshot main
`6ee7f6d9a9a9d2342803c41a32f8dd03ac7a0d48`). Đây chỉ tái hiện logic
client trong bộ nhớ, không phải request thật, server, proxy, thiết bị hay production.
Lệnh và output: [repro README](../../qa/repro/README.md), [log mới nhất](../../qa-artifacts/2026-10-22/repro-520c738.log)
(artifact local bị ignore). Assertion trong repro là invariant được đề xuất để owner xác nhận;
chưa mặc định là contract backend đã duyệt hay hành vi hiện tại của code. Chi tiết thực thi nằm trong
[TEST_CASES.md](TEST_CASES.md); readiness và môi trường ở [PROGRESS.md](PROGRESS.md).

## RSK-01 — protected request có thể gửi Bearer sang host redirect ngoài API

- **Mức / owner / trạng thái:** P1 security · dev network + QA retest · invariant fail trong client fake-transport repro trên `520c738`; chưa xác nhận có server redirect ngoài origin.
- **Trigger:** endpoint protected trả `307` hoặc `308` với `Location` trỏ sang host khác.
- **Quan sát/repro:** [`ApiClient._send`](../../lib/core/network/api_client.dart#L217) gửi lại method/body tới URL do [`_redirectTarget`](../../lib/core/network/api_client.dart#L253) trả về mà không kiểm tra origin. Request redirect đi qua [`AuthInterceptor.onRequest`](../../lib/core/network/auth_interceptor.dart#L41). Adapter giả trả `308 Location: https://other.test/capture` cho `POST /posts` protected; request ghi nhận có `Bearer dummy-access` và `{'marker': 'dummy-body'}`. Test `protected redirect must block or strip credentials off origin` fail đúng invariant. Kết quả xác nhận hành vi client trong harness này, không chứng minh server thật tạo redirect đó.
- **Tác động:** nếu API/proxy cấu hình sai hoặc host tin cậy bị xâm nhập, token phiên có thể bị gửi tới bên thứ ba.
- **Repro nhỏ nhất:** [`network_risks_test.dart`](../../qa/repro/network_risks_test.dart#L64) gửi POST protected với token/body giả, adapter trả 308 khác origin rồi assert request tiếp theo không mang token/body. Test hiện fail với token/body đều được gửi. Unit redirect hiện tại chỉ dùng login public ([`api_client_test.dart`](../../test/core/api_client_test.dart#L116)). Không dùng token thật hoặc host production.
- **Expected / bằng chứng còn thiếu:** owner xác nhận policy redirect/origin. Nếu redirect ngoài origin không được phép, expected là chặn trước request thứ hai; nếu có CDN upload origin hợp lệ, cần allowlist cụ thể. Lưu request headers đã redact và target origin trong harness test.

## RSK-02 — request chờ refresh lỗi mạng bị phân loại thành hết phiên

- **Mức / owner / trạng thái:** P1 UX/session · dev network + QA retest · invariant fail trong client fake-transport repro trên `520c738`; chưa xác minh UI trên app/device.
- **Trigger:** hai protected request cùng gặp 401, một refresh đang chạy, refresh trả lỗi mạng.
- **Quan sát/repro:** owner refresh phân biệt lỗi mạng ở [`_refreshOnce`](../../lib/core/network/auth_interceptor.dart#L139); waiter chuyển mọi `false` thành `invalid` ([`auth_interceptor.dart`](../../lib/core/network/auth_interceptor.dart#L108)). Repro giữ refresh bằng completer, phát caller thứ hai khi refresh đầu đã chạy, chờ cả hai 401 rồi drain event queue trước khi thả timeout. Kết quả: đúng một refresh; caller đầu `noConnection`, caller chờ `unauthorized`; token vẫn còn và không có session-expired event. Test `parallel 401 callers must both retain network error on refresh timeout` fail vì caller thứ hai sai loại lỗi. Comment nội bộ yêu cầu giữ phiên và trả lỗi mạng ([`auth_interceptor.dart`](../../lib/core/network/auth_interceptor.dart#L11)).
- **Tác động:** trong cùng một lần mất mạng, một thao tác có thể báo hết phiên trong khi thao tác khác báo lỗi mạng; UI/QA nhận kết quả không nhất quán.
- **Repro nhỏ nhất:** deterministic completers trong [`network_risks_test.dart`](../../qa/repro/network_risks_test.dart#L114) đồng bộ cả hai 401 và refresh timeout. `api_client_test` có concurrent success và single invalid-refresh, chưa có concurrent network timeout ([test lines 205](../../test/core/api_client_test.dart#L205), [239](../../test/core/api_client_test.dart#L239)). Liên quan case [AUTH-03](TEST_CASES.md#auth-03--access-token-hết-hạn-refresh-invalid-và-lỗi-mạng).
- **Expected / bằng chứng còn thiếu:** theo comment hiện tại thì giữ phiên và lỗi mạng cho tất cả caller; client-layer exception mismatch đã tái hiện, còn mapping UI/device và phản ứng của backend chưa được kiểm tra.

## RSK-03 — cache cục bộ có thể được hiển thị sau khi secure token storage bị lỗi

- **Mức / owner / trạng thái:** P1 privacy candidate · dev auth/storage + QA hai tài khoản · luồng dữ liệu client đọc tại source SHA `542e29cb914eeb6f2be80b2403cd33639fd8d328`; NOT RUN, chưa kiểm tra luồng boot → đăng nhập B → lỗi `/users/me` → quan sát UI trên app/device.
- **Trigger có điều kiện:** secure storage ném lỗi khi app boot (comment trong code nêu Keystore hỏng sau restore). `TokenStorage.load` bắt lỗi rồi gọi `clear()` nhưng không đụng `LocalStorage` ([`TokenStorage`](../../lib/core/storage/token_storage.dart#L26)); boot không phiên chuyển tới Login mà không dọn cache ([`SplashView`](../../lib/features/splash/splash_view.dart#L47)). Sau đăng nhập, [`ProfileCubit.load`](../../lib/features/profile/cubit/profile_cubit.dart#L46) có thể phát `cachedMe` trước khi đợi `/users/me` và giữ nó nếu request trả lỗi mạng; Home khởi tạo feed từ cache ([`HomeTab`](../../lib/features/home/home_tab.dart#L37)). Key cache profile/feed không gắn account ID ([`LocalStorage`](../../lib/core/storage/local_storage.dart#L23)).
- **Quan sát code vs. suy luận:** code cho thấy cache A vẫn đọc được sau nhánh lỗi token; đây là quan sát tĩnh. Suy luận rủi ro là sau đó tài khoản B có thể nhìn cache A, nhất là khi `/users/me` lỗi. Logout bình thường dọn cache qua [`AuthRepository.clearLocalSession`](../../lib/data/repositories/auth_repository.dart#L71); finding chỉ áp dụng nhánh bootstrap lỗi/phiên mất bất thường, không phải logout bình thường. Chưa quan sát UI thực tế hoặc chứng minh fixture plugin đi qua boot và login đầy đủ.
- **Tái hiện / trạng thái:** NOT RUN. Giả thuyết cần xác minh: seed cache marker A trong SharedPreferences, khiến secure-storage read lỗi khi boot qua fake plugin hoặc device test an toàn, rồi đăng nhập B và làm `/users/me` lỗi mạng; quan sát xem ProfileCubit/Home có hiển thị cache A hay không. Không phá Keychain/Keystore tài khoản cá nhân. Hiện chưa có harness được kiểm chứng, lệnh hay kết quả chạy; không tính là PASS. Liên quan [AUTH-05](TEST_CASES.md#auth-05--đổi-a-sang-b-không-rò-dữ-liệu-và-nhớ-đúng-tài-khoản).
- **Expected / bằng chứng còn thiếu:** tiêu chí riêng tư đề xuất là không hiển thị cache của tài khoản khác; đây chưa phải yêu cầu được README ghi rõ. Owner cần xác nhận hành vi sau keystore corruption/restore và liệu cache phải cô lập theo user. Chưa chạy harness hẹp hoặc kiểm tra app/device; cần xác minh marker A không render sau khi đăng nhập B, kể cả khi `/users/me` offline. Không phá Keychain/Keystore tài khoản cá nhân.

## Đã xem, chưa nâng thành finding

- Việc `changePassword` cập nhật saved credential duy nhất mà không so sánh email hiện tại là điểm cần test, nhưng không đủ bằng chứng về một đường UI bình thường giữ credential A trong khi B đổi password. Không coi là lỗi xác nhận; policy nhiều tài khoản và thao tác account-switch cần được chốt trước khi mở defect. Có thể kiểm tra có điều kiện trong [AUTH-05](TEST_CASES.md#auth-05--đổi-a-sang-b-không-rò-dữ-liệu-và-nhớ-đúng-tài-khoản).
- Media repository kiểm tra kích thước byte và phần mở rộng GIF trước upload; bộ unit fake hiện đã bao phủ ngưỡng này. Không thấy từ phạm vi đọc này một sai lệch đủ căn cứ để ghi finding mới về picker/upload. Kiểm tra UI picker, byte thực sự được upload và server vẫn theo [MEDIA-01](TEST_CASES.md#media-01--biên-4-mib-và-gif-bị-chặn-trước-upload), [MEDIA-02](TEST_CASES.md#media-02--quyền-cameragallery-huỷ-picker-và-upload-timeout).
