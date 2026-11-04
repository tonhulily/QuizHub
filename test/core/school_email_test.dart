import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/utils/validators.dart';

void main() {
  test('tự thêm tên miền trường khi chỉ nhập tên đăng nhập', () {
    expect(
      Validators.withSchoolDomain(' nhu.mt235184 '),
      'nhu.mt235184@sis.hust.edu.vn',
    );
  });

  test('giữ nguyên email đã có tên miền và chuỗi rỗng', () {
    expect(Validators.withSchoolDomain('a@gmail.com'), 'a@gmail.com');
    expect(Validators.withSchoolDomain('  '), '');
  });

  test('tên đăng nhập trần hợp lệ sau khi thêm tên miền', () {
    expect(
      Validators.email(Validators.withSchoolDomain('nhu.mt235184')),
      isNull,
    );
  });
}
