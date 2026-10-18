import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/utils/json_utils.dart';
import 'package:quizhub/core/utils/validators.dart';
import 'package:quizhub/data/models/cursor_page.dart';
import 'package:quizhub/data/models/post_model.dart';
import 'package:quizhub/data/models/profile_model.dart';

void main() {
  group('J (tolerant json)', () {
    test('parses numbers/bools given as strings', () {
      expect(J.asInt('12'), 12);
      expect(J.asInt(12.0), 12);
      expect(J.asBool('true'), true);
      expect(J.asBool(0), false);
      expect(J.asDouble('1.5'), 1.5);
    });

    test('parses ISO and unix dates', () {
      expect(J.asDate('2026-10-06T12:00:00Z'), isNotNull);
      expect(J.asDate(1760000000)!.year, 2025);
      expect(J.asDate(1760000000000)!.year, 2025);
      expect(J.asDate(null), isNull);
    });
  });

  group('Validators', () {
    test('email', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('abc'), isNotNull);
      expect(Validators.email('hieu.dv22980@sis.hust.edu.vn'), isNull);
    });

    test('new password rules', () {
      expect(Validators.newPassword('abc'), isNotNull); // quá ngắn
      expect(Validators.newPassword('abc@1234'), isNotNull); // ký tự đặc biệt
      expect(Validators.newPassword('abc 1234'), isNotNull); // khoảng trắng
      expect(Validators.newPassword('Abc12345'), isNull);
    });

    test('word count', () {
      expect(Validators.wordCount('  '), 0);
      expect(Validators.wordCount('xin chào  các bạn'), 4);
    });
  });

  group('Models', () {
    test('PostModel.fromJson', () {
      final p = PostModel.fromJson({
        'post_id': 7,
        'content': 'Hello',
        'post_type': 'SOCIAL_POST',
        'visibility': 'FRIENDS',
        'media_urls': [
          {
            'url': 'https://x/y.png',
            'type': 'IMAGE',
            'width': 10,
            'height': 20,
          },
        ],
        'author': {'user_id': 3, 'full_name': 'An'},
        'react_count': 2,
        'comment_count': '4',
        'reacted_by_me': true,
        'created_at': '2026-10-06T12:00:00Z',
        'updated_at': '2026-10-06T13:00:00Z',
      });
      expect(p.postId, 7);
      expect(p.visibility, PostVisibility.friends);
      expect(p.media.single.isImage, true);
      expect(p.commentCount, 4);
      expect(p.reactedByMe, true);
      expect(p.isEdited, true);
      expect(p.copyWith(reactCount: 9).reactCount, 9);
    });

    test('CursorPage.fromJson', () {
      final page = CursorPage<int>.fromJson({
        'items': [
          {'a': 1},
          {'a': 2},
        ],
        'pagination': {'after': 55, 'has_next': true},
      }, (m) => m['a'] as int);
      expect(page.items, [1, 2]);
      expect(page.after, '55');
      expect(page.hasNext, true);
    });

    test('ProfileModel.fromJson + toJson round trip', () {
      final json = {
        'user_id': 169,
        'email': 'a@b.com',
        'full_name': 'Đồng Văn Hiếu',
        'role': 'LECTURER',
        'gender': 'MALE',
        'date_of_birth': '2004-08-05',
        'gamification_points': 12,
        'friends_count': 5,
      };
      final p = ProfileModel.fromJson(json);
      expect(p.role.isLecturer, true);
      expect(p.gender, Gender.male);
      expect(p.gamificationPoints, 12.0);
      final again = ProfileModel.fromJson(p.toJson());
      expect(again.fullName, p.fullName);
      expect(again.dateOfBirth, p.dateOfBirth);
    });
  });
}
