import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/models/current_user.dart';
import 'package:auto_podbor_mobile/models/user_summary.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/app_ui.dart';
import 'package:auto_podbor_mobile/widgets/avatar_editor.dart';

/// Аватар: ссылка из API, картинка вместо инициалов, шторка смены фото.
void main() {
  test('avatar_url разбирается у пользователя и в профиле', () {
    final summary = UserSummary.fromJson({
      'id': 1,
      'name': 'Игорь В.',
      'avatar_url': '/storage/avatars/1/a.jpg',
    });
    expect(summary.avatarUrl, endsWith('/storage/avatars/1/a.jpg'));
    expect(summary.avatarUrl, startsWith('http'));

    final me = CurrentUser.fromJson({
      'id': 1,
      'name': 'Игорь В.',
      'email': '',
      'avatar_url': null,
    });
    expect(me.avatarUrl, isNull);
  });

  Future<void> host(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: Center(child: child)),
    ),
  );

  testWidgets('без ссылки — инициалы, со ссылкой — картинка', (tester) async {
    await host(tester, const Avatar('ИВ', size: 36));
    expect(find.text('ИВ'), findsOneWidget);
    expect(find.byType(Image), findsNothing);

    await host(
      tester,
      const Avatar('ИВ', size: 36, url: 'http://x/storage/avatars/1/a.jpg'),
    );
    expect(find.byType(Image), findsOneWidget);
  });

  group('редактор аватара', () {
    late List<String> uploaded;
    late int deleted;

    Future<void> pump(
      WidgetTester tester, {
      String? url,
      String? picked = '/tmp/square.jpg',
    }) async {
      uploaded = [];
      deleted = 0;
      await host(
        tester,
        AvatarEditor(
          name: 'Игорь В.',
          url: url,
          pick: (_, _) async => picked,
          onUpload: (path) async => uploaded.add(path),
          onDelete: () async => deleted++,
        ),
      );
    }

    testWidgets('без фото — «Удалить» нет; выбранный квадрат уходит', (
      tester,
    ) async {
      await pump(tester);
      await tester.tap(find.byType(AvatarEditor));
      await tester.pumpAndSettle();

      expect(find.text('Удалить фото'), findsNothing);
      await tester.tap(find.text('Выбрать из галереи'));
      await tester.pumpAndSettle();
      expect(uploaded, ['/tmp/square.jpg']);
    });

    testWidgets('передумал при обрезке — ничего не уходит', (tester) async {
      await pump(tester, picked: null);
      await tester.tap(find.byType(AvatarEditor));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Сделать фото'));
      await tester.pumpAndSettle();
      expect(uploaded, isEmpty);
    });

    testWidgets('с фото — можно удалить', (tester) async {
      await pump(tester, url: 'http://x/storage/avatars/1/a.jpg');
      await tester.tap(find.byType(AvatarEditor));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Удалить фото'));
      await tester.pumpAndSettle();
      expect(deleted, 1);
      expect(uploaded, isEmpty);
    });
  });
}
