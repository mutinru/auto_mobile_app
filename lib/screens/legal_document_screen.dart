import 'package:flutter/material.dart';

import '../data/legal_repository.dart';
import '../models/legal_text.dart';
import '../theme/app_colors.dart';
import '../util/ru_date.dart';
import '../widgets/api_error.dart';
import '../widgets/app_ui.dart';
import '../widgets/legal_blocks.dart';

/// Открыть документ своим экраном — без браузера и адреса (тексты с
/// сервера, `GET /legal/{код}`). Репозиторий передаёт вызывающий: стор не
/// создаём в builder маршрута.
Future<void> openLegalDocument(
  BuildContext context,
  LegalRepository repository,
  LegalDocument doc,
) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LegalDocumentScreen(repository: repository, doc: doc),
    ),
  );
}

/// Соглашение, политика или согласие на обработку ПД.
class LegalDocumentScreen extends StatefulWidget {
  const LegalDocumentScreen({
    super.key,
    required this.repository,
    required this.doc,
  });

  final LegalRepository repository;
  final LegalDocument doc;

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  LegalText? _text;
  String? _error;
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
      final text = await widget.repository.fetch(widget.doc);
      if (mounted) setState(() => _text = text);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = _text;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DetailHead(
              eyebrow: 'Документы',
              // заголовок с сервера, пока не загрузился — свой
              title: text?.title.isNotEmpty == true
                  ? text!.title
                  : widget.doc.title,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: _loading && text == null
                  ? const Center(child: CircularProgressIndicator())
                  : text == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _error ?? 'Не удалось загрузить документ',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: c.text2),
                            ),
                            const SizedBox(height: 12),
                            CtaFlat(label: 'Повторить', onPressed: _load),
                          ],
                        ),
                      ),
                    )
                  : SelectionArea(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
                        children: [
                          if (text.edition case final edition?)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                'Редакция от ${dayMonth(edition)} ${edition.year}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: c.text3,
                                ),
                              ),
                            ),
                          LegalBlocks(
                            text.blocks,
                            onOpenDocument: (doc) => openLegalDocument(
                              context,
                              widget.repository,
                              doc,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
