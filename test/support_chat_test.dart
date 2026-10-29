import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/config/api_config.dart';
import 'package:auto_podbor_mobile/data/auth_service.dart';
import 'package:auto_podbor_mobile/data/mock_chat_repository.dart';
import 'package:auto_podbor_mobile/models/chat_message.dart';
import 'package:auto_podbor_mobile/models/chat_role.dart';
import 'package:auto_podbor_mobile/screens/support_chat_screen.dart';
import 'package:auto_podbor_mobile/state/chat_store.dart';
import 'package:auto_podbor_mobile/state/support_chat_scope.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';
import 'package:auto_podbor_mobile/widgets/support_sheet.dart';

Map<String, dynamic> _json(String role, {String? name, List<Map<String, dynamic>> attachments = const []}) => {
      'id': 7,
      'body': 'Текст',
      'attachments': attachments,
      'is_mine': role == 'me',
      'sender': {'role': role, 'name': name},
      'created_at': '2026-10-29T10:15:00+00:00',
    };

void main() {
  group('ChatMessage.fromJson', () {
    test('sender.role: me, system и роли участников', () {
      final mine = ChatMessage.fromJson(_json('me', name: 'Андрей'));
      expect(mine.isMine, isTrue);
      expect(mine.senderRole, isNull);

      final system = ChatMessage.fromJson(_json('system'));
      expect(system.isSystem, isTrue);
      expect(system.senderRole, isNull);

      final support = ChatMessage.fromJson(_json('support', name: 'Поддержка'));
      expect(support.isFromSupport, isTrue);
      expect(support.senderName, 'Поддержка');

      expect(ChatMessage.fromJson(_json('requester')).senderRole, ChatRole.requester);
      expect(ChatMessage.fromJson(_json('executor')).senderRole, ChatRole.executor);
    });

    test('адрес фото — свой хост, путь с сервера', () {
      final message = ChatMessage.fromJson(_json('me', attachments: [
        {'id': 3, 'url': 'http://localhost:8083/api/messages/7/attachments/3', 'width': 300, 'height': 600},
      ]));

      expect(message.attachments.single.url, '${ApiConfig.origin}/api/messages/7/attachments/3');
      expect(message.attachments.single.aspectRatio, 0.5);
    });
  });

  group('SupportChatScreen', () {
    Widget screen(ChatStore store) => MaterialApp(
          theme: AppTheme.dark,
          home: SupportChatScreen(store: store),
        );

    testWidgets('пустой чат, отправка и ответ поддержки через опрос', (tester) async {
      final repo = MockChatRepository();
      await tester.pumpWidget(screen(ChatStore(repo)));
      await tester.pumpAndSettle();

      expect(find.text('Напишите, что случилось — ответим здесь же'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Не грузится отчёт');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pumpAndSettle();

      expect(find.text('Не грузится отчёт'), findsOneWidget);
      // поле очищено после успешной отправки
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);

      repo.simulateReply('Уже смотрим');
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      expect(find.text('Уже смотрим'), findsOneWidget);
      expect(find.text('Поддержка'), findsWidgets);
      // ответ поддержки отмечен прочитанным
      expect(repo.lastReadId, isNotNull);

      // экран закрываем, чтобы погасить таймер опроса
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('ошибка открытия — текст и «Повторить»', (tester) async {
      final repo = MockChatRepository(failOpen: true);
      await tester.pumpWidget(screen(ChatStore(repo)));
      await tester.pumpAndSettle();

      expect(find.text('Не удалось открыть чат'), findsOneWidget);

      repo.failOpen = false;
      await tester.tap(find.text('Повторить'));
      await tester.pumpAndSettle();

      expect(find.text('Напишите, что случилось — ответим здесь же'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('шторка поддержки', () {
    Widget app(AuthService auth) => MaterialApp(
          theme: AppTheme.dark,
          builder: (_, child) => SupportChatScope(
            auth: auth,
            repository: MockChatRepository.new,
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showSupportSheet(context),
                child: const Text('открыть'),
              ),
            ),
          ),
        );

    testWidgets('вошедшему «Написать в чат» открывает чат в приложении', (tester) async {
      await tester.pumpWidget(app(AuthService()..debugSetToken('t')));
      await tester.tap(find.text('открыть'));
      await tester.pumpAndSettle();

      expect(find.text('Прямо в приложении, ответим здесь же'), findsOneWidget);

      await tester.tap(find.text('Написать в чат'));
      await tester.pumpAndSettle();

      expect(find.byType(SupportChatScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('гостю — Telegram, чат не открывается', (tester) async {
      await tester.pumpWidget(app(AuthService()));
      await tester.tap(find.text('открыть'));
      await tester.pumpAndSettle();

      expect(find.text('После входа — в приложении, пока откроем Telegram'), findsOneWidget);
      expect(find.text('Без аккаунта — Telegram или звонок.'), findsOneWidget);
    });
  });
}
