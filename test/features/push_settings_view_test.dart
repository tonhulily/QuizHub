import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:quizhub/data/models/push_settings.dart';
import 'package:quizhub/data/repositories/push_settings_repository.dart';
import 'package:quizhub/features/menu/push_settings_view.dart';

PushSettings _settings({required bool pushEnabled}) => PushSettings(
  pushEnabled: pushEnabled,
  categories: const {
    'SOCIAL': PushCategory(enabled: true, description: 'Mạng xã hội'),
  },
  quietHours: const QuietHours(enabled: true),
  soundEnabled: true,
  vibrationEnabled: true,
);

class _Repo implements PushSettingsRepository {
  final PushSettings initial;
  _Repo(this.initial);

  @override
  Future<PushSettings> getSettings() async => initial;

  @override
  Future<PushSettings> updateSettings(PushSettings settings) async => settings;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _open(WidgetTester tester, PushSettings settings) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final getIt = GetIt.instance;
  await getIt.reset();
  getIt.registerSingleton<PushSettingsRepository>(_Repo(settings));
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const PushSettingsView()),
            ),
            child: const Text('mở'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('mở'));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => GetIt.instance.reset());

  testWidgets('tắt công tắc tổng thì khóa các công tắc con', (tester) async {
    await _open(tester, _settings(pushEnabled: false));

    for (final title in ['Social', 'Bật giờ yên tĩnh', 'Âm thanh', 'Rung']) {
      final tile = tester.widget<SwitchListTile>(
        find.ancestor(
          of: find.text(title),
          matching: find.byType(SwitchListTile),
        ),
      );
      expect(tile.onChanged, isNull, reason: '$title phải bị khóa');
    }
    // Công tắc tổng vẫn thao tác được
    final master = tester.widget<SwitchListTile>(
      find.ancestor(
        of: find.text('Cho phép thông báo'),
        matching: find.byType(SwitchListTile),
      ),
    );
    expect(master.onChanged, isNotNull);
  });

  testWidgets('bật công tắc tổng thì các công tắc con dùng được', (
    tester,
  ) async {
    await _open(tester, _settings(pushEnabled: true));

    final tile = tester.widget<SwitchListTile>(
      find.ancestor(
        of: find.text('Social'),
        matching: find.byType(SwitchListTile),
      ),
    );
    expect(tile.onChanged, isNotNull);
  });

  testWidgets('Back khi chưa có thay đổi thì thoát ngay', (tester) async {
    await _open(tester, _settings(pushEnabled: true));

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Cài đặt thông báo'), findsNothing);
    expect(find.text('Bỏ thay đổi?'), findsNothing);
  });

  testWidgets('Back khi có thay đổi chưa lưu thì hỏi xác nhận', (tester) async {
    await _open(tester, _settings(pushEnabled: true));

    await tester.tap(find.text('Âm thanh'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Bỏ thay đổi?'), findsOneWidget);

    // "Ở lại" giữ nguyên màn hình
    await tester.tap(find.text('Ở lại'));
    await tester.pumpAndSettle();
    expect(find.text('Cài đặt thông báo'), findsOneWidget);

    // "Bỏ thay đổi" thoát ra
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bỏ thay đổi'));
    await tester.pumpAndSettle();
    expect(find.text('Cài đặt thông báo'), findsNothing);
  });
}
