import 'package:flutter/foundation.dart';

/// Документы для пользователя. Коды — ручное зеркало ключей
/// `config/legal.php` бекенда; тексты и редакция живут на сервере
/// (`GET /legal/{код}`) и меняются без новой сборки.
enum LegalDocument {
  terms('terms', 'Пользовательское соглашение'),
  privacy('privacy', 'Политика обработки персональных данных'),
  consent('consent', 'Согласие на обработку персональных данных');

  const LegalDocument(this.code, this.title);

  final String code;
  final String title;

  static LegalDocument? fromCode(String? code) {
    for (final doc in values) {
      if (doc.code == code) return doc;
    }
    return null;
  }

  /// Документ по ссылке из текста (`/legal/privacy`); null — ссылка внешняя.
  static LegalDocument? fromLink(String link) {
    final match = RegExp(r'^/legal/([a-z_]+)$').firstMatch(link);
    return match == null ? null : fromCode(match.group(1));
  }
}

/// Текст документа с сервера: заголовок, редакция и блоки разметки.
/// Формат блоков — зеркало `App\Legal\LegalDocuments` бекенда.
class LegalText {
  const LegalText({
    required this.title,
    this.edition,
    this.blocks = const [],
  });

  final String title;

  /// Дата редакции (`config('legal.version')`); её же сервер пишет в
  /// согласие при входе.
  final DateTime? edition;
  final List<LegalBlock> blocks;

  factory LegalText.fromJson(Map<String, dynamic> json) => LegalText(
    title: json['title'] as String? ?? '',
    edition: DateTime.tryParse(json['edition'] as String? ?? ''),
    blocks: LegalBlock.listFromJson(json['blocks']),
  );
}

enum LegalBlockType { heading, paragraph, list, quote, rule }

/// Блок текста. Незнакомый тип с текстом становится абзацем (сервер новее
/// приложения), без текста — пропускается с записью в лог.
class LegalBlock {
  const LegalBlock(
    this.type, {
    this.level = 2,
    this.ordered = false,
    this.start = 1,
    this.spans = const [],
    this.items = const [],
    this.children = const [],
  });

  final LegalBlockType type;

  /// Уровень заголовка (2 — раздел, 3 — подраздел).
  final int level;

  /// Нумерованный список и номер первого пункта.
  final bool ordered;
  final int start;
  final List<LegalSpan> spans;

  /// Пункты списка — каждый из своих блоков (вложенный список — блок пункта).
  final List<List<LegalBlock>> items;

  /// Содержимое цитаты.
  final List<LegalBlock> children;

  static List<LegalBlock> listFromJson(Object? raw) {
    if (raw is! List) return const [];
    final blocks = <LegalBlock>[];
    for (final item in raw) {
      final block = item is Map<String, dynamic>
          ? LegalBlock.tryFromJson(item)
          : null;
      if (block == null) {
        debugPrint('Пропущен блок документа: $item');
      } else {
        blocks.add(block);
      }
    }
    return blocks;
  }

  static LegalBlock? tryFromJson(Map<String, dynamic> json) {
    final spans = LegalSpan.listFromJson(json['spans']);
    final type = LegalBlockType.values
        .where((t) => t.name == json['type'])
        .firstOrNull;
    switch (type) {
      case LegalBlockType.heading:
        return LegalBlock(
          type!,
          level: json['level'] as int? ?? 2,
          spans: spans,
        );
      case LegalBlockType.list:
        final raw = json['items'];
        return LegalBlock(
          type!,
          ordered: json['ordered'] as bool? ?? false,
          start: json['start'] as int? ?? 1,
          items: raw is List
              ? [for (final item in raw) listFromJson(item)]
              : const [],
        );
      case LegalBlockType.quote:
        return LegalBlock(type!, children: listFromJson(json['children']));
      case LegalBlockType.rule:
        return const LegalBlock(LegalBlockType.rule);
      case LegalBlockType.paragraph:
      case null:
        return spans.isEmpty
            ? null
            : LegalBlock(LegalBlockType.paragraph, spans: spans);
    }
  }
}

/// Кусок строки с разметкой. [link] — `https://`, `mailto:` или
/// `/legal/{код}` (другой документ); прочие ссылки сервер не отдаёт.
class LegalSpan {
  const LegalSpan(
    this.text, {
    this.strong = false,
    this.em = false,
    this.code = false,
    this.link,
  });

  final String text;
  final bool strong;
  final bool em;
  final bool code;
  final String? link;

  static List<LegalSpan> listFromJson(Object? raw) => [
    if (raw is List)
      for (final item in raw)
        if (item is Map<String, dynamic> && item['text'] is String)
          LegalSpan(
            item['text'] as String,
            strong: item['strong'] == true,
            em: item['em'] == true,
            code: item['code'] == true,
            link: item['link'] as String?,
          ),
  ];
}
