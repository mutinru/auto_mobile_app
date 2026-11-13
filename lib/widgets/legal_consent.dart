import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../data/legal_repository.dart';
import '../models/legal_text.dart';
import '../screens/legal_document_screen.dart';
import '../theme/app_colors.dart';

/// Галочка «Принимаю соглашение и даю согласие на обработку ПД» на экране
/// входа (QA 2026-11-05 №14). Без неё вход не пройдёт: сервер требует
/// `accept_legal` и сам записывает, какую редакцию документов человек принял.
/// Ссылки открывают документы, нажатие по остальному тексту — галочку.
class LegalConsentCheckbox extends StatefulWidget {
  const LegalConsentCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.repository,
  });

  /// Откуда экран документа берёт текст (гостевой `ApiClient`).
  final LegalRepository repository;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  State<LegalConsentCheckbox> createState() => _LegalConsentCheckboxState();
}

class _LegalConsentCheckboxState extends State<LegalConsentCheckbox> {
  late final Map<LegalDocument, TapGestureRecognizer> _links = {
    for (final doc in LegalDocument.values)
      doc: TapGestureRecognizer()
        ..onTap = () => openLegalDocument(context, widget.repository, doc),
  };

  @override
  void dispose() {
    for (final recognizer in _links.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  TextSpan _link(String text, LegalDocument doc) => TextSpan(
    text: text,
    recognizer: _links[doc],
    style: TextStyle(
      color: context.colors.text1,
      decoration: TextDecoration.underline,
      decorationColor: context.colors.text3,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: widget.value,
            onChanged: (v) => widget.onChanged(v ?? false),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            activeColor: c.statusDone,
            checkColor: c.modeBuyInk,
            side: BorderSide(color: c.text3, width: 1.5),
            semanticLabel:
                'Принимаю пользовательское соглашение и даю согласие '
                'на обработку персональных данных',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            // диктор переключает саму галочку, ссылки остаются в тексте
            excludeFromSemantics: true,
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onChanged(!widget.value),
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Принимаю '),
                    _link('пользовательское соглашение', LegalDocument.terms),
                    const TextSpan(text: ' и даю '),
                    _link(
                      'согласие на обработку персональных данных',
                      LegalDocument.consent,
                    ),
                    const TextSpan(text: ' в соответствии с '),
                    _link(
                      'политикой обработки данных',
                      LegalDocument.privacy,
                    ),
                  ],
                ),
                style: TextStyle(fontSize: 12, color: c.text2, height: 1.45),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
