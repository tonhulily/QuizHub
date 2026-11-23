import 'package:flutter_test/flutter_test.dart';
import 'package:quizhub/data/models/question_models.dart';
import 'package:quizhub/data/models/search_models.dart';

void main() {
  test('SearchType parses case-insensitively and falls back to all', () {
    expect(SearchType.fromJson('user'), SearchType.user);
    expect(SearchType.fromJson('QUESTION'), SearchType.question);
    expect(SearchType.fromJson('unknown'), SearchType.all);
    expect(SearchType.fromJson(null), SearchType.all);
  });

  test('GlobalSearchPage parses items and cursor pagination', () {
    final page = GlobalSearchPage.fromJson({
      'total_hits': 12,
      'items': [
        {'type': 'USER', 'user': {'user_id': 7, 'full_name': 'Nguyen An'}},
      ],
      'pagination': {
        'after': 20, 'before': 0, 'has_next': true, 'has_prev': false,
      },
    });
    expect(page.items.single.user!.userId, 7);
    expect(page.items.single.type, SearchType.user);
    expect(page.after, '20');
    expect(page.hasNext, isTrue);
    expect(page.totalHits, 12);
    expect(page.before, 0);
    expect(page.hasPrev, isFalse);
  });

  test('GlobalSearchPage tolerates malformed top-level data', () {
    final page = GlobalSearchPage.fromJson({
      'items': 'not-a-list', 'pagination': 'not-an-object',
    });
    expect(page.items, isEmpty);
    expect(page.after, isNull);
    expect(page.hasNext, isFalse);
    expect(page.totalHits, 0);
  });

  test('SearchUser uses safe defaults for missing fields', () {
    final user = SearchUser.fromJson({});
    expect(user.userId, 0);
    expect(user.fullName, 'Người dùng');
    expect(user.followersCount, 0);
    expect(user.avatarUrl, isNull);
  });

  test('SearchQuestion filters null-like image URLs and parses options', () {
    final question = SearchQuestion.fromJson({
      'question_id': 3, 'content': 'Nội dung', 'difficulty': 'HARD',
      'image_urls': ['https://a.test/1.png', null, 'null', 10],
      'options': [{'key': 'A', 'text': 'Đáp án A'}],
    });
    expect(question.questionId, 3);
    expect(question.difficulty, Difficulty.hard);
    expect(question.imageUrls, ['https://a.test/1.png']);
    expect(question.options.single.key, 'A');
  });

  test('unknown difficulty falls back to unclassified', () {
    final question = SearchQuestion.fromJson({
      'question_id': 4, 'content': 'Nội dung', 'difficulty': 'VERY_HARD',
    });
    expect(question.difficulty, Difficulty.unclassified);
  });

  test('SavedSearchResponse parses history and trending terms', () {
    final response = SavedSearchResponse.fromJson({
      'saved_searches': [
        {'saved_search_id': 9, 'query_text': 'Cấu trúc dữ liệu'},
      ],
      'trending_searches': ['Flutter', null, 'null', ''],
    });
    expect(response.savedSearches.single.savedSearchId, 9);
    expect(response.savedSearches.single.queryText, 'Cấu trúc dữ liệu');
    expect(response.trendingSearches, ['Flutter']);
  });
}
