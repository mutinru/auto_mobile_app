import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:auto_podbor_mobile/data/api_exception.dart';
import 'package:auto_podbor_mobile/data/legal_repository.dart';
import 'package:auto_podbor_mobile/models/legal_text.dart';
import 'package:auto_podbor_mobile/screens/legal_document_screen.dart';
import 'package:auto_podbor_mobile/theme/app_theme.dart';

/// Документы без сети: отдаёт текст по коду или бросает заданную ошибку.
class _FakeLegal implements LegalRepository {
  _FakeLegal({this.error});

  Object? error;
  final requests = <LegalDocument>[];

  @override
  Future<LegalText> fetch(LegalDocument doc) async {
    requests.add(doc);
    final e = error;
    if (e != null) throw e;
    return LegalText.fromJson({
      'title': doc.title,
      'edition': '2026-11-13',
      'blocks': [
        {
          'type': 'heading',
          'level': 2,
          'spans': [
            {'text': '1. Раздел ${doc.code}'},
          ],
        },
        {
          'type': 'paragraph',
          'spans': [
            {'text': 'См. '},
            {'text': 'политику', 'link': '/legal/privacy'},
            {'text': '.'},
          ],
        },
        {
          'type': 'list',
          'ordered': true,
          'start': 3,
          'items': [
            [
              {
                'type': 'paragraph',
                'spans': [
                  {'text': 'третий пункт'},
                ],
              },
            ],
          ],
        },
        {
          'type': 'quote',
          'children': [
            {
              'type': 'paragraph',
              'spans': [
                {'text': 'Черновик', 'strong': true},
              ],
            },
          ],
        },
        {'type': 'rule'},
        // сервер новее приложения: незнакомый блок с текстом — абзацем
        {
          'type': 'table',
          'spans': [
            {'text': 'таблица текстом'},
          ],
        },
        {'type': 'mystery'},
      ],
    });
  }
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    LegalRepository repo,
    ThemeData theme,
  ) => tester.pumpWidget(
    MaterialApp(
      theme: theme,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () =>
                  openLegalDocument(context, repo, LegalDocument.terms),
              child: const Text('открыть'),
            ),
          ),
        ),
      ),
    ),
  );

  test('разбор: типы, флаги, незнакомое', () {
    final text = LegalText.fromJson({
      'title': 'T',
      'edition': '2026-11-13',
      'blocks': [
        {
          'type': 'paragraph',
          'spans': [
            {'text': 'a', 'strong': true, 'em': true, 'code': true},
            {'text': 'b', 'link': 'mailto:x@y.ru'},
          ],
        },
        {'type': 'mystery'},
        {
          'type': 'future',
          'spans': [
            {'text': 'c'},
          ],
        },
      ],
    });
    expect(text.edition, DateTime(2026, 11, 13));
    expect(text.blocks.map((b) => b.type), [
      LegalBlockType.paragraph,
      LegalBlockType.paragraph,
    ]);
    final a = text.blocks.first.spans.first;
    expect([a.strong, a.em, a.code, a.link], [true, true, true, null]);
    expect(text.blocks.first.spans.last.link, 'mailto:x@y.ru');

    expect(LegalDocument.fromLink('/legal/privacy'), LegalDocument.privacy);
    expect(LegalDocument.fromLink('/legal/unknown'), isNull);
    expect(
      LegalDocument.fromLink('https://bitnebit.com/legal/privacy'),
      isNull,
    );
  });

  for (final (name, theme) in [
    ('светлая', AppTheme.light),
    ('тёмная', AppTheme.dark),
  ]) {
    testWidgets('экран рисует документ своими виджетами ($name тема)', (
      tester,
    ) async {
      final repo = _FakeLegal();
      await pump(tester, repo, theme);
      await tester.tap(find.text('открыть'));
      await tester.pumpAndSettle();

      expect(find.text('Пользовательское соглашение'), findsOneWidget);
      expect(find.text('Редакция от 13 ноября 2026'), findsOneWidget);
      expect(find.text('1. Раздел terms', findRichText: true), findsOneWidget);
      expect(find.text('3.'), findsOneWidget);
      expect(find.text('третий пункт', findRichText: true), findsOneWidget);
      expect(find.text('Черновик', findRichText: true), findsOneWidget);
      expect(find.text('таблица текстом', findRichText: true), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ссылка /legal/… открывает второй документ, назад — первый', (
    tester,
  ) async {
    final repo = _FakeLegal();
    await pump(tester, repo, AppTheme.light);
    await tester.tap(find.text('открыть'));
    await tester.pumpAndSettle();

    await tester.tapOnText(find.textRange.ofSubstring('политику'));
    await tester.pumpAndSettle();

    expect(repo.requests, [LegalDocument.terms, LegalDocument.privacy]);
    expect(find.text('Политика обработки персональных данных'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Пользовательское соглашение'), findsOneWidget);
  });

  testWidgets('ошибка — текст и «Повторить»', (tester) async {
    final repo = _FakeLegal(error: ApiException(503, '{"message":"x"}'));
    await pump(tester, repo, AppTheme.light);
    await tester.tap(find.text('открыть'));
    await tester.pumpAndSettle();

    expect(find.text('Повторить'), findsOneWidget);
    // заголовок есть и без ответа сервера
    expect(find.text('Пользовательское соглашение'), findsOneWidget);

    repo.error = null;
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(repo.requests, hasLength(2));
    expect(find.text('Редакция от 13 ноября 2026'), findsOneWidget);
  });
}
