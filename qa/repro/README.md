# Tái hiện rủi ro network

Hai test opt-in này gọi `ApiClient` và `AuthInterceptor` thật qua Dio adapter trong
bộ nhớ. Chúng không gọi server, không cần tài khoản và không thuộc bộ regression mặc
định trong `test/`.

```bash
XDG_CONFIG_HOME=/tmp/quizhub-qa-sdk/config \
XDG_CACHE_HOME=/tmp/quizhub-qa-sdk/cache \
PUB_CACHE=/tmp/quizhub-pub-cache \
FLUTTER_SUPPRESS_ANALYTICS=true CI=true \
/tmp/quizhub-qa-sdk/flutter/bin/flutter test --no-pub \
  qa/repro/network_risks_test.dart --reporter expanded
```

Các assertion mô tả invariant an toàn. Test đỏ là bằng chứng harness đã quan sát
hành vi client trái invariant; không sửa expected để khớp hành vi hiện tại. Test xanh
chỉ nghĩa trigger đó không tái hiện trong harness, không chứng minh backend, proxy,
thiết bị hay production an toàn.

Redirect test chấp nhận hai kết quả an toàn: client chặn redirect ngoài origin trước
khi gửi request, hoặc gửi request nhưng bỏ cả Authorization lẫn body. Test bắt và
chấp nhận riêng `ApiException` từ nhánh chặn; exception khác sẽ làm test lỗi. Refresh
test chờ request A bắt đầu refresh rồi phát request B, đồng bộ cả hai 401 trước khi
thả timeout, sau đó kiểm tra error type, token, event hết phiên và số refresh.

Flutter test runner cần bind localhost tạm thời. Sandbox có thể chặn socket này trước
khi test được tải; lần reproduction được chạy trong môi trường cho phép loopback. Output
đầy đủ nằm ở `qa-artifacts/network-risks-repro.log` (ignored/local). Hai test reproduction
đỏ là kết quả riêng; chúng không làm thay đổi hay bị xóa bởi kết quả xanh của 95 test
regression mặc định.
