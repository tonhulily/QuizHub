import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/core/network/api_client.dart';
import 'package:quizhub/core/network/api_exception.dart';
import 'package:quizhub/core/network/session_events.dart';
import 'package:quizhub/core/storage/local_storage.dart';
import 'package:quizhub/data/models/media_item.dart';
import 'package:quizhub/data/models/post_model.dart';
import 'package:quizhub/data/repositories/feed_repository.dart';
import 'package:quizhub/data/repositories/post_repository.dart';
import 'package:quizhub/dev/preview_backend.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingPreferences implements SharedPreferences {
  final bool throwOnSave;
  final _cache = <String, Object>{};

  _FailingPreferences({required this.throwOnSave});

  @override
  Object? get(String key) => _cache[key];

  @override
  List<String>? getStringList(String key) => _cache[key] as List<String>?;

  @override
  Future<bool> setString(String key, String value) async {
    _cache[key] = value;
    if (throwOnSave) throw StateError('disk write failed');
    return false;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences preferences;
  late ApiClient api;
  late PostRepository posts;
  late FeedRepository feed;
  final events = <SessionEvents>[];

  void connect({SharedPreferences? store, bool persistent = true}) {
    final session = SessionEvents();
    events.add(session);
    final prefs = store ?? preferences;
    final storage = LocalStorage(prefs);
    api = ApiClient(
      tokens: PreviewTokens(),
      events: session,
      baseUrl: 'https://example.test/api/v1',
      adapter: PreviewBackend(preferences: persistent ? prefs : null),
    );
    posts = PostRepository(api, storage);
    feed = FeedRepository(api, storage);
  }

  Future<void> restart() async {
    // Dựng lại cả SharedPreferences và backend từ dữ liệu đã serialize, tương
    // đương mở app mới; không dùng lại Map bài viết của phiên trước.
    final disk = <String, Object>{
      for (final key in preferences.getKeys()) key: preferences.get(key)!,
    };
    SharedPreferences.setMockInitialValues(disk);
    preferences = await SharedPreferences.getInstance();
    connect();
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    connect();
  });
  tearDown(() {
    for (final session in events) {
      session.dispose();
    }
    events.clear();
  });

  test(
    'sửa bài rồi mở app lại: chi tiết, feed và trang cá nhân cùng dữ liệu',
    () async {
      final before = await posts.getById(12);
      await posts.update(
        12,
        content: 'Nội dung đã sửa, giữ qua lần mở app sau 📚',
        media: [],
        visibility: PostVisibility.onlyMe,
      );
      final saved = await posts.getById(12);

      await restart();

      final restored = await posts.getById(12);
      expect(restored, saved);
      expect(restored.content, 'Nội dung đã sửa, giữ qua lần mở app sau 📚');
      expect(restored.visibility, PostVisibility.onlyMe);
      expect(restored.media, isEmpty);
      expect(restored.createdAt, before.createdAt);
      expect(restored.updatedAt, isNot(before.updatedAt));
      expect(
        (await feed.getFeed()).items
            .singleWhere((i) => i.postId == 12)
            .toPost(),
        restored,
      );
      expect((await posts.myPosts()).items.single, restored);
    },
  );

  test(
    'bài tạo mới giữ ID, ảnh và vẫn chỉnh sửa được sau khi mở lại',
    () async {
      const image = MediaItem(
        key: 'sample-image',
        url: 'https://example.test/image.jpg',
        type: MediaType.image,
        width: 800,
        height: 600,
      );
      final created = await posts.create(content: 'Bài mới', media: [image]);
      await restart();
      expect(await posts.getById(created.postId), created);

      await posts.update(created.postId, content: 'Bài mới đã chỉnh sửa');
      await restart();
      final restored = await posts.getById(created.postId);
      expect(restored.content, 'Bài mới đã chỉnh sửa');
      expect(restored.media, [image]);
      expect(restored.postId, created.postId);
    },
  );

  test('bài đã xoá không trở lại và ID đã xoá không được cấp lại', () async {
    final first = await posts.create(content: 'Bài cần giữ');
    final deleted = await posts.create(content: 'Bài cần xoá');
    await posts.delete(deleted.postId);
    await posts.delete(12);
    await restart();

    expect(await posts.getById(first.postId), first);
    await expectLater(
      posts.getById(deleted.postId),
      throwsA(
        isA<ApiException>().having(
          (e) => e.type,
          'type',
          ApiErrorType.notFound,
        ),
      ),
    );
    expect((await posts.myPosts()).items, [first]);
    final ids = (await feed.getFeed()).items.map((i) => i.postId).toSet();
    expect(ids, isNot(contains(deleted.postId)));
    expect(ids, isNot(contains(12)));
    final next = await posts.create(content: 'Bài tiếp theo');
    expect(next.postId, greaterThan(deleted.postId));
    expect(
      (await feed.getFeed()).items.any((i) => i.postId == next.postId),
      isTrue,
    );
  });

  test('tập bài rỗng vẫn được giữ, không nạp lại bài mẫu đã xoá', () async {
    for (final id in [11, 12, 13]) {
      await posts.delete(id);
    }
    await restart();
    expect((await posts.myPosts()).items, isEmpty);
    expect((await feed.getFeed()).items.where((i) => i.isPost), isEmpty);
  });

  test('dữ liệu xoá từ bản cũ không làm bài mới bị ẩn do trùng ID', () async {
    SharedPreferences.setMockInitialValues({
      'deleted_post_ids': ['12', '100', '101'],
    });
    preferences = await SharedPreferences.getInstance();
    connect();
    final created = await posts.create(content: 'Bài mới sau khi nâng bản');
    expect(created.postId, greaterThan(101));
    await restart();
    expect(await posts.getById(created.postId), created);
    final ids = (await feed.getFeed()).items.map((i) => i.postId).toSet();
    expect(ids, contains(created.postId));
    expect(ids, isNot(contains(12)));
  });

  test('các request lưu đồng thời không ghi đè mất bài của nhau', () async {
    final created = await Future.wait([
      posts.create(content: 'Bài thứ nhất'),
      posts.create(content: 'Bài thứ hai'),
    ]);
    await posts.update(12, content: 'Bài mẫu đã sửa');
    await restart();

    for (final post in created) {
      expect(await posts.getById(post.postId), post);
    }
    expect(created.map((p) => p.postId).toSet(), hasLength(2));
    expect((await posts.getById(12)).content, 'Bài mẫu đã sửa');
  });

  test('không báo lưu thành công cho bài không còn tồn tại', () async {
    await expectLater(
      posts.update(99999, content: 'Không tồn tại'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.type,
          'type',
          ApiErrorType.notFound,
        ),
      ),
    );
  });

  for (final throwsOnSave in [false, true]) {
    test(
      'lỗi ghi ($throwsOnSave): báo lỗi và hoàn tác cả dữ liệu lẫn cache',
      () async {
        final broken = _FailingPreferences(throwOnSave: throwsOnSave);
        connect(store: broken);
        final before = await posts.getById(12);
        await expectLater(
          posts.update(12, content: 'Không được báo thành công'),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 500),
          ),
        );
        expect(await posts.getById(12), before);
        connect(store: broken);
        expect(await posts.getById(12), before);
      },
    );
  }

  for (final raw in ['not json', '{"version":1,"posts":[{}]}']) {
    test(
      'dữ liệu lưu hỏng không làm mất bộ mẫu hoặc lỗi khởi động: $raw',
      () async {
        SharedPreferences.setMockInitialValues({'preview_posts_v1': raw});
        preferences = await SharedPreferences.getInstance();
        connect();
        expect((await posts.getById(12)).postId, 12);
        await posts.update(12, content: 'Lưu lại bình thường');
        await restart();
        expect((await posts.getById(12)).content, 'Lưu lại bình thường');
      },
    );
  }

  test(
    'fixture không truyền preferences vẫn độc lập giữa các lần tạo',
    () async {
      connect(persistent: false);
      final original = await posts.getById(12);
      await posts.update(12, content: 'Chỉ trong fixture');
      connect(persistent: false);
      expect((await posts.getById(12)).content, original.content);
    },
  );
}
