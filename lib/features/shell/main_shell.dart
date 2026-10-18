import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/design_system/app_colors.dart';
import '../../core/router/app_routes.dart';
import '../../core/widgets/fb_widgets.dart';
import '../home/home_tab.dart';
import '../menu/menu_tab.dart';
import '../friends/view/friends_tab.dart';
import 'placeholder_tab.dart';
import '../../core/design_system/app_icons.dart';

/// Định nghĩa 1 tab của shell. Module khác chỉ cần thay `builder` của tab
/// tương ứng bằng màn hình thật (không đụng phần còn lại của shell).
class ShellTab {
  /// Tên tab (tooltip / accessibility)
  final String label;

  /// Tiêu đề hiện trên header. `null` = hiện wordmark QuizHub (tab Trang chủ).
  final String? title;
  final IconData icon;
  final IconData activeIcon;
  final WidgetBuilder builder;

  /// Hiện nút "+" (tạo bài viết) trên header của tab này.
  final bool showCreate;

  const ShellTab({
    required this.label,
    this.title,
    required this.icon,
    required this.activeIcon,
    required this.builder,
    this.showCreate = false,
  });
}

/// Khung điều hướng chính theo bố cục Facebook:
/// header (tiêu đề + nút Tìm kiếm / Nhắn tin) + thanh tab icon phía trên.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  /// Danh sách tab. Thay `PlaceholderTab` bằng màn hình thật khi tích hợp.
  static final List<ShellTab> tabs = [
    ShellTab(
      label: 'Trang chủ',
      icon: AppIcons.home,
      activeIcon: AppIcons.homeActive,
      showCreate: true,
      builder: (_) => const HomeTab(),
    ),
    ShellTab(
      label: 'Bạn bè',
      title: 'Bạn bè',
      icon: AppIcons.friends,
      activeIcon: AppIcons.friendsActive,
      builder: (_) => const FriendsTab(),
    ),
    ShellTab(
      label: 'Ngân hàng đề',
      title: 'Ngân hàng đề',
      icon: AppIcons.quiz,
      activeIcon: AppIcons.quizActive,
      builder: (_) => const PlaceholderTab(
        icon: AppIcons.quizActive,
        message: 'Đề xuất, làm và đánh giá câu hỏi sẽ có ở đây.',
      ),
    ),
    ShellTab(
      label: 'Thông báo',
      title: 'Thông báo',
      icon: AppIcons.notifications,
      activeIcon: AppIcons.notificationsActive,
      builder: (_) => const PlaceholderTab(
        icon: AppIcons.notificationsActive,
        message: 'Thông báo về lượt thích, bình luận, kết bạn... sẽ có ở đây.',
      ),
    ),
    ShellTab(
      label: 'Menu',
      title: 'Menu',
      icon: AppIcons.menu,
      activeIcon: AppIcons.menuActive,
      builder: (_) => const MenuTab(),
    ),
  ];

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(
    length: MainShell.tabs.length,
    vsync: this,
  )..addListener(_onTabChanged);

  // Tab chỉ được dựng khi mở lần đầu, sau đó giữ nguyên trạng thái
  late final List<bool> _built = List.filled(MainShell.tabs.length, false)
    ..[0] = true;

  int get _index => _controller.index;

  void _onTabChanged() {
    if (_controller.indexIsChanging) return;
    setState(() => _built[_controller.index] = true);
  }

  /// Chuyển sang tab thứ [i] (các màn khác gọi qua
  /// `context.findAncestorStateOfType<MainShellState>()?.select(i)`).
  void select(int i) => _select(i);

  void _select(int i) {
    if (i == _index) return;
    _controller.animateTo(i, duration: Duration.zero);
    setState(() => _built[i] = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    await Navigator.of(context).pushNamed(AppRoutes.createPost);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = MainShell.tabs;
    final current = tabs[_index];

    return PopScope(
      // Back ở tab khác -> về tab Trang chủ trước, rồi mới thoát app
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _select(0);
      },
      child: Scaffold(
        backgroundColor: AppColors.white,
        body: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.dark,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                _Header(tab: current, onCreate: _create),
                _TabStrip(controller: _controller, tabs: tabs, onTap: _select),
                Expanded(
                  child: ColoredBox(
                    color: AppColors.backgroundSecondary,
                    child: IndexedStack(
                      index: _index,
                      children: [
                        for (var i = 0; i < tabs.length; i++)
                          _built[i]
                              ? tabs[i].builder(context)
                              : const SizedBox.shrink(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hàng trên cùng: wordmark / tiêu đề tab + các nút tròn.
class _Header extends StatelessWidget {
  final ShellTab tab;
  final VoidCallback onCreate;

  const _Header({required this.tab, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: AppColors.white,
      height: 52,
      padding: const EdgeInsets.only(left: 16, right: 12),
      child: Row(
        children: [
          Expanded(
            child: tab.title == null
                ? Text(
                    'QuizHub',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AppColors.primary600,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  )
                : Text(
                    tab.title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
          // Chỉ icon (không vòng tròn nền), cỡ lớn như Facebook
          if (tab.showCreate)
            HeaderIconButton(
              icon: AppIcons.add,
              tooltip: 'Tạo bài viết',
              onTap: onCreate,
            ),
          HeaderIconButton(
            icon: AppIcons.search,
            tooltip: 'Tìm kiếm',
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.searchUsers),
          ),
          HeaderIconButton(
            icon: AppIcons.messenger,
            tooltip: 'Tin nhắn',
            onTap: () => showComingSoon(context, 'Tin nhắn'),
          ),
        ],
      ),
    );
  }
}

/// Thanh tab chỉ có icon, gạch chân màu thương hiệu dưới tab đang chọn.
class _TabStrip extends StatelessWidget {
  final TabController controller;
  final List<ShellTab> tabs;
  final ValueChanged<int> onTap;

  const _TabStrip({
    required this.controller,
    required this.tabs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(bottom: BorderSide(color: AppColors.borderLight)),
      ),
      child: TabBar(
        controller: controller,
        onTap: onTap,
        dividerColor: AppColors.transparent,
        indicatorColor: AppColors.primary600,
        indicatorWeight: 3,
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: AppColors.primary600,
        unselectedLabelColor: AppColors.textSecondary,
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(AppColors.transparent),
        tabs: [
          for (final t in tabs)
            Tab(
              height: 46,
              icon: Icon(
                controller.index == tabs.indexOf(t) ? t.activeIcon : t.icon,
                size: 30,
              ),
              iconMargin: EdgeInsets.zero,
            ),
        ],
      ),
    );
  }
}
