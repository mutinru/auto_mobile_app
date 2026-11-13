import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/legal_text.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Блоки документа своими виджетами (формат — [LegalBlock]): заголовки,
/// абзацы, списки, цитаты, черта. Ссылка на другой документ зовёт
/// [onOpenDocument], внешняя (`https:`, `mailto:`) уходит в систему.
class LegalBlocks extends StatelessWidget {
  const LegalBlocks(this.blocks, {super.key, required this.onOpenDocument});

  final List<LegalBlock> blocks;
  final ValueChanged<LegalDocument> onOpenDocument;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final (i, block) in blocks.indexed)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : _gapBefore(block)),
          child: _block(block),
        ),
    ],
  );

  double _gapBefore(LegalBlock block) =>
      block.type == LegalBlockType.heading ? 22 : 10;

  Widget _block(LegalBlock block) => switch (block.type) {
    LegalBlockType.heading => _Rich(
      block.spans,
      kind: block.level <= 2 ? _Kind.h2 : _Kind.h3,
      onOpenDocument: onOpenDocument,
    ),
    LegalBlockType.paragraph => _Rich(
      block.spans,
      onOpenDocument: onOpenDocument,
    ),
    LegalBlockType.list => _List(block, onOpenDocument: onOpenDocument),
    LegalBlockType.quote => _Quote(
      LegalBlocks(block.children, onOpenDocument: onOpenDocument),
    ),
    LegalBlockType.rule => const _Rule(),
  };
}

enum _Kind { body, h2, h3 }

/// Строка с разметкой. Stateful — ради распознавателей нажатий у ссылок:
/// их нужно освобождать.
class _Rich extends StatefulWidget {
  const _Rich(
    this.spans, {
    this.kind = _Kind.body,
    required this.onOpenDocument,
  });

  final List<LegalSpan> spans;
  final _Kind kind;
  final ValueChanged<LegalDocument> onOpenDocument;

  @override
  State<_Rich> createState() => _RichState();
}

class _RichState extends State<_Rich> {
  /// По распознавателю на кусок-ссылку (null — не ссылка), в порядке spans.
  /// Создаются один раз, а не в build: смена темы пересобирает виджет.
  List<TapGestureRecognizer?> _recognizers = const [];

  @override
  void initState() {
    super.initState();
    _recognizers = _makeRecognizers();
  }

  @override
  void didUpdateWidget(_Rich old) {
    super.didUpdateWidget(old);
    if (!identical(old.spans, widget.spans)) {
      _disposeRecognizers();
      _recognizers = _makeRecognizers();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  List<TapGestureRecognizer?> _makeRecognizers() => [
    for (final span in widget.spans)
      if (span.link case final link?)
        TapGestureRecognizer()..onTap = () => _open(link)
      else
        null,
  ];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r?.dispose();
    }
  }

  Future<void> _open(String link) async {
    final doc = LegalDocument.fromLink(link);
    if (doc != null) {
      widget.onOpenDocument(doc);
      return;
    }
    final uri = Uri.tryParse(link);
    final messenger = ScaffoldMessenger.maybeOf(context);
    var ok = false;
    try {
      ok =
          uri != null &&
          await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Не удалось открыть ссылку')),
      );
    }
  }

  TextStyle _base(BuildContext context) {
    final c = context.colors;
    return switch (widget.kind) {
      _Kind.h2 => TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.34,
        height: 1.3,
        color: c.text1,
      ),
      _Kind.h3 => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: c.text1,
      ),
      _Kind.body => TextStyle(fontSize: 14, height: 1.55, color: c.text2),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Text.rich(
      TextSpan(
        children: [
          for (final (i, span) in widget.spans.indexed)
            TextSpan(
              text: span.text,
              recognizer: _recognizers[i],
              style: TextStyle(
                fontWeight: span.strong ? FontWeight.w600 : null,
                fontStyle: span.em ? FontStyle.italic : null,
                fontFamily: span.code ? AppTheme.monoFamily : null,
                color: span.strong || span.link != null ? c.text1 : null,
                decoration: span.link != null ? TextDecoration.underline : null,
                decorationColor: c.text3,
              ),
            ),
        ],
      ),
      style: _base(context),
    );
  }
}

class _List extends StatelessWidget {
  const _List(this.block, {required this.onOpenDocument});

  final LegalBlock block;
  final ValueChanged<LegalDocument> onOpenDocument;

  @override
  Widget build(BuildContext context) {
    final marker = TextStyle(
      fontSize: 14,
      height: 1.55,
      color: context.colors.text3,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, item) in block.items.indexed)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: block.ordered ? 26 : 18,
                  child: Text(
                    block.ordered ? '${block.start + i}.' : '•',
                    style: marker,
                  ),
                ),
                Expanded(
                  child: LegalBlocks(item, onOpenDocument: onOpenDocument),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Quote extends StatelessWidget {
  const _Quote(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // скругление — обрезкой: у BoxDecoration рамка только слева со
    // скруглением не рисуется
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: c.bg1,
          border: Border(left: BorderSide(color: c.statusProgress, width: 3)),
        ),
        child: child,
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Divider(height: 1, thickness: 1, color: context.colors.line),
  );
}
