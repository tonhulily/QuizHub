import 'package:flutter/material.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/network/api_exception.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/post_model.dart';
import '../../data/repositories/post_repository.dart';
import '../../di/locator.dart';
import '../../shared/post/post_card.dart';

/// Trang xem riêng một bài viết, tải bản mới nhất theo id từ backend.
class PostDetailView extends StatefulWidget {
  final int postId;

  const PostDetailView({super.key, required this.postId});

  @override
  State<PostDetailView> createState() => _PostDetailViewState();
}

class _PostDetailViewState extends State<PostDetailView> {
  PostModel? _post;
  ApiException? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final post = await getIt<PostRepository>().getById(widget.postId);
      if (!mounted) return;
      setState(() {
        _post = post;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _editPost(PostModel post) async {
    final updated = await Navigator.of(
      context,
    ).pushNamed(AppRoutes.editPost, arguments: post);
    if (updated is PostModel && mounted) setState(() => _post = updated);
  }

  @override
  Widget build(BuildContext context) {
    final post = _post;

    return Scaffold(
      backgroundColor: AppColors.backgroundSecondary,
      appBar: AppBar(title: const Text('Bài viết')),
      body: _loading && post == null
          ? const LoadingView()
          : _error != null && post == null
          ? ErrorView(error: _error, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  if (_error != null)
                    ErrorView(error: _error, onRetry: _load, compact: true)
                  else if (post != null)
                    PostCard(
                      post: post,
                      onEdit: _editPost,
                      onChanged: (updated) => setState(() => _post = updated),
                      onDeleted: (_) => Navigator.of(context).pop(true),
                    ),
                ],
              ),
            ),
    );
  }
}
