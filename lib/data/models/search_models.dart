// lib/data/models/search_models.dart
import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';
import '../../data/models/author_model.dart';
import '../../data/models/question_models.dart';
import '../../data/models/subject_model.dart';
import '../../data/models/cursor_page.dart';

enum SearchType {
  all('ALL', 'Tất cả'),
  post('POST', 'Bài viết'),
  user('USER', 'Người dùng'),
  question('QUESTION', 'Câu hỏi'),
  session('SESSION', 'Buổi đóng góp'),
  subject('SUBJECT', 'Môn học');

  final String apiValue;
  final String label;

  const SearchType(this.apiValue, this.label);

    static SearchType fromJson(dynamic value) {
    final normalized = value?.toString().toUpperCase();

    return SearchType.values.firstWhere(
      (type) => type.apiValue == normalized,
      orElse: () => SearchType.all,
    );
  }
}

/// Chuyển danh sách URL từ JSON, bỏ null và chuỗi "null".
/// Chuyển danh sách chuỗi từ JSON, bỏ null và chuỗi "null".
List<String> _searchStrings(dynamic value) {
  return J.asList(value)
      .map((item) {
        final raw = J.asString(item);
        if (raw == null || raw.toLowerCase() == 'null') return null;
        return raw;
      })
      .whereType<String>()
      .toList();
}

// -----------------------------------------------------------------------------
// Global search item
// -----------------------------------------------------------------------------

class GlobalSearchItem extends Equatable {
  final SearchType type;
  final double? relevanceScore;

  final SearchPost? post;
  final SearchUser? user;
  final SearchQuestion? question;
  final SearchSession? session;
  final SubjectModel? subject;

  const GlobalSearchItem({
    required this.type,
    this.relevanceScore,
    this.post,
    this.user,
    this.question,
    this.session,
    this.subject,
  });

  factory GlobalSearchItem.fromJson(Map<String, dynamic> json) {
    return GlobalSearchItem(
      type: SearchType.fromJson(json['type']),
      relevanceScore: J.asDouble(json['relevance_score']),
      post: json['post'] == null
          ? null
          : SearchPost.fromJson(J.asMap(json['post'])!),
      user: json['user'] == null
          ? null
          : SearchUser.fromJson(J.asMap(json['user'])!),
      question: json['question'] == null
          ? null
          : SearchQuestion.fromJson(J.asMap(json['question'])!),
      session: json['session'] == null
          ? null
          : SearchSession.fromJson(J.asMap(json['session'])!),
      subject: json['subject'] == null
          ? null
          : SubjectModel.fromJson(J.asMap(json['subject'])!),
    );
  }

  @override
  List<Object?> get props => [
    type,
    relevanceScore,
    post,
    user,
    question,
    session,
    subject,
  ];
}

// -----------------------------------------------------------------------------
// Post search result
// -----------------------------------------------------------------------------

class SearchPost extends Equatable {
  final int postId;
  final String content;
  final AuthorModel author;
  final String? postType;
  final List<String> mediaUrls;
  final int reactCount;
  final int commentCount;
  final DateTime? createdAt;

  const SearchPost({
    required this.postId,
    required this.content,
    required this.author,
    this.postType,
    this.mediaUrls = const [],
    this.reactCount = 0,
    this.commentCount = 0,
    this.createdAt,
  });

  factory SearchPost.fromJson(Map<String, dynamic> json) {
    // Search API trả thông tin author ở dạng phẳng.
    // Chuyển về cấu trúc AuthorModel đang dùng trong app.
    final author = AuthorModel(
      userId: J.intOr(json['author_id']),
      fullName: J.stringOr(json['author_name'], 'Người dùng'),
      avatarUrl: J.asString(json['author_avatar_url']),
      frameUrl: J.asString(json['author_frame_url']),
    );

    return SearchPost(
      postId: J.intOr(json['post_id']),
      content: J.stringOr(json['content']),
      author: author,
      postType: J.asString(json['post_type']),
      mediaUrls: _searchStrings(json['media_urls']),
      reactCount: J.intOr(json['react_count']),
      commentCount: J.intOr(json['comment_count']),
      createdAt: J.asDate(json['created_at']),
    );
  }

  @override
  List<Object?> get props => [
    postId,
    content,
    author,
    postType,
    mediaUrls,
    reactCount,
    commentCount,
    createdAt,
  ];
}

// -----------------------------------------------------------------------------
// User search result
// -----------------------------------------------------------------------------

class SearchUser extends Equatable {
  final int userId;
  final String fullName;
  final String? studentLecturerCode;
  final String? email;
  final String? bio;
  final String? avatarUrl;
  final String? frameUrl;
  final String? schoolFaculty;
  final String? major;
  final String? role;
  final int totalProposedQuestions;
  final int badgesCount;
  final int followersCount;

  const SearchUser({
    required this.userId,
    required this.fullName,
    this.studentLecturerCode,
    this.email,
    this.bio,
    this.avatarUrl,
    this.frameUrl,
    this.schoolFaculty,
    this.major,
    this.role,
    this.totalProposedQuestions = 0,
    this.badgesCount = 0,
    this.followersCount = 0,
  });

  factory SearchUser.fromJson(Map<String, dynamic> json) {
    return SearchUser(
      userId: J.intOr(json['user_id']),
      fullName: J.stringOr(json['full_name'], 'Người dùng'),
      studentLecturerCode: J.asString(json['student_lecturer_code']),
      email: J.asString(json['email']),
      bio: J.asString(json['bio']),
      avatarUrl: J.asString(json['avatar_url']),
      frameUrl: J.asString(json['avatar_frame_url']),
      schoolFaculty: J.asString(json['school_faculty']),
      major: J.asString(json['major']),
      role: J.asString(json['role']),
      totalProposedQuestions: J.intOr(json['total_proposed_questions']),
      badgesCount: J.intOr(json['badges_count']),
      followersCount: J.intOr(json['followers_count']),
    );
  }

  @override
  List<Object?> get props => [
    userId,
    fullName,
    studentLecturerCode,
    email,
    bio,
    avatarUrl,
    frameUrl,
    schoolFaculty,
    major,
    role,
    totalProposedQuestions,
    badgesCount,
    followersCount,
  ];
}

// -----------------------------------------------------------------------------
// Question search result
// -----------------------------------------------------------------------------

class SearchQuestion extends Equatable {
  final int questionId;
  final String? questionCode;
  final int? subjectId;
  final String? subjectName;
  final int? topicId;
  final String? topicName;
  final String? status;
  final Difficulty difficulty;
  final String content;
  final List<QuestionOption> options;
  final String? explanation;
  final List<String> imageUrls;
  final double? avgRating;
  final int ratingCount;
  final int reactCount;
  final int commentCount;
  final DateTime? createdAt;

  const SearchQuestion({
    required this.questionId,
    this.questionCode,
    this.subjectId,
    this.subjectName,
    this.topicId,
    this.topicName,
    this.status,
    this.difficulty = Difficulty.unclassified,
    required this.content,
    this.options = const [],
    this.explanation,
    this.imageUrls = const [],
    this.avgRating,
    this.ratingCount = 0,
    this.reactCount = 0,
    this.commentCount = 0,
    this.createdAt,
  });

  factory SearchQuestion.fromJson(Map<String, dynamic> json) {
    return SearchQuestion(
      questionId: J.intOr(json['question_id']),
      questionCode: J.asString(json['question_code']),
      subjectId: J.asInt(json['subject_id']),
      subjectName: J.asString(json['subject_name']),
      topicId: J.asInt(json['topic_id']),
      topicName: J.asString(json['topic_name']),
      status: J.asString(json['status']),
      difficulty: Difficulty.parse(json['difficulty']),
      content: J.stringOr(json['content']),
      options: J.list(json['options'], QuestionOption.fromJson),
      explanation: J.asString(json['explanation']),
      imageUrls: _searchStrings(json['image_urls']),
      avgRating: J.asDouble(json['avg_rating']),
      ratingCount: J.intOr(json['rating_count']),
      reactCount: J.intOr(json['react_count']),
      commentCount: J.intOr(json['comment_count']),
      createdAt: J.asDate(json['created_at']),
    );
  }

  @override
  List<Object?> get props => [
    questionId,
    questionCode,
    subjectId,
    subjectName,
    topicId,
    topicName,
    status,
    difficulty,
    content,
    options,
    explanation,
    imageUrls,
    avgRating,
    ratingCount,
    reactCount,
    commentCount,
    createdAt,
  ];
}

// -----------------------------------------------------------------------------
// Contribution session search result
// -----------------------------------------------------------------------------

class SearchSession extends Equatable {
  final int sessionId;
  final String title;
  final String? content;
  final int? subjectId;
  final String? subjectName;
  final String? status;
  final int questionCount;
  final int reactCount;
  final int commentCount;
  final DateTime? createdAt;

  const SearchSession({
    required this.sessionId,
    required this.title,
    this.content,
    this.subjectId,
    this.subjectName,
    this.status,
    this.questionCount = 0,
    this.reactCount = 0,
    this.commentCount = 0,
    this.createdAt,
  });

  factory SearchSession.fromJson(Map<String, dynamic> json) {
    return SearchSession(
      sessionId: J.intOr(json['session_id']),
      title: J.stringOr(json['title']),
      content: J.asString(json['content']),
      subjectId: J.asInt(json['subject_id']),
      subjectName: J.asString(json['subject_name']),
      status: J.asString(json['status']),
      questionCount: J.intOr(json['question_count']),
      reactCount: J.intOr(json['react_count']),
      commentCount: J.intOr(json['comment_count']),
      createdAt: J.asDate(json['created_at']),
    );
  }

  @override
  List<Object?> get props => [
    sessionId,
    title,
    content,
    subjectId,
    subjectName,
    status,
    questionCount,
    reactCount,
    commentCount,
    createdAt,
  ];
}

// -----------------------------------------------------------------------------
// Search page
// -----------------------------------------------------------------------------

class GlobalSearchPage extends CursorPage<GlobalSearchItem> {
  /// Tổng số kết quả tìm được trên toàn bộ các trang.
  final int totalHits;

  /// Offset của trang trước do API trả về.
  final int? before;

  /// Có trang trước hay không.
  final bool hasPrev;

  const GlobalSearchPage({
    super.items = const [],
    super.after,
    super.hasNext = false,
    this.totalHits = 0,
    this.before,
    this.hasPrev = false,
  });

  factory GlobalSearchPage.fromJson(dynamic data) {
    final json = J.asMap(data) ?? const <String, dynamic>{};
    final pagination = J.asMap(json['pagination']);

    return GlobalSearchPage(
      items: J.list(
        json['items'],
        GlobalSearchItem.fromJson,
      ),
      // API trả after dạng int, CursorPage sử dụng String.
      after: J.asInt(pagination?['after'])?.toString(),
      hasNext: J.asBool(pagination?['has_next']),
      totalHits: J.intOr(json['total_hits']),
      before: J.asInt(pagination?['before']),
      hasPrev: J.asBool(pagination?['has_prev']),
    );
  }

  @override
  List<Object?> get props => [
    ...super.props,
    totalHits,
    before,
    hasPrev,
  ];
}

// -----------------------------------------------------------------------------
// Saved search history and trending keywords
// -----------------------------------------------------------------------------

class SavedSearch extends Equatable {
  final int savedSearchId;
  final String queryText;
  final DateTime? lastSearchedAt;

  const SavedSearch({
    required this.savedSearchId,
    required this.queryText,
    this.lastSearchedAt,
  });

  factory SavedSearch.fromJson(Map<String, dynamic> json) {
    return SavedSearch(
      savedSearchId: J.intOr(json['saved_search_id']),
      queryText: J.stringOr(json['query_text']),
      lastSearchedAt: J.asDate(json['last_searched_at']),
    );
  }

  @override
  List<Object?> get props => [
        savedSearchId,
        queryText,
        lastSearchedAt,
      ];
}

class SavedSearchResponse extends Equatable {
  final List<SavedSearch> savedSearches;
  final List<String> trendingSearches;

  const SavedSearchResponse({
    this.savedSearches = const [],
    this.trendingSearches = const [],
  });

  factory SavedSearchResponse.fromJson(dynamic data) {
    final json = J.asMap(data) ?? const <String, dynamic>{};

    return SavedSearchResponse(
      savedSearches: J.list(
        json['saved_searches'],
        SavedSearch.fromJson,
      ),
      trendingSearches: _searchStrings(json['trending_searches']),
    );
  }

  @override
  List<Object?> get props => [savedSearches, trendingSearches];
}