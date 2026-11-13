/// Поля формы, чипы и переключатель макета (design/app_auto_podbor.html).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// .field-label + .field-box — поле формы: подпись сверху, значение в рамке.
class FieldBox extends StatelessWidget {
  const FieldBox({
    super.key,
    required this.label,
    required this.value,
    this.placeholder = false,
    this.mono = false,
    this.unit,
    this.trailing,
    this.onTap,
    this.minHeight,
    this.error,
    this.optional = false,
  });

  final String label;
  final String value;

  /// Текст ошибки под полем; поле — в красной рамке.
  final String? error;

  /// Серое «необязательно» справа от подписи.
  final bool optional;

  /// true → значение показывается цветом text-3 (.field-box.empty)
  final bool placeholder;
  final bool mono;

  /// .field-box .unit — серая единица измерения справа (км)
  final String? unit;

  /// например шеврон у селекта
  final Widget? trailing;
  final VoidCallback? onTap;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final style = mono
        ? context.text.fieldMono
        : (placeholder
              ? context.text.fieldPlaceholder
              : context.text.fieldValue);

    return Padding(
      // .field { margin-bottom: 10px }
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label, optional: optional),
          const SizedBox(height: 6),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: BoxConstraints(minHeight: minHeight ?? 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: context.colors.bg1,
                border: Border.all(
                  color: error != null
                      ? context.colors.statusDefect
                      : context.colors.line,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: minHeight != null
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.center,
                children: [
                  Expanded(child: Text(value, style: style)),
                  if (unit != null) ...[
                    const SizedBox(width: 10),
                    Text(
                      unit!,
                      style: TextStyle(
                        fontFamily: AppTheme.monoFamily,
                        fontSize: 12,
                        color: context.colors.text3,
                      ),
                    ),
                  ],
                  if (trailing != null) ...[
                    const SizedBox(width: 10),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
          FieldError(error),
        ],
      ),
    );
  }
}

/// Подпись поля капсом; у необязательного — серое «необязательно» справа.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.label, {super.key, this.optional = false});

  final String label;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final text = Text(label.toUpperCase(), style: context.text.fieldLabel);
    if (!optional) return text;
    return Row(
      children: [
        Expanded(child: text),
        Text(
          'необязательно',
          style: context.text.fieldLabelNote,
        ),
      ],
    );
  }
}

/// Ошибка под полем — цвет `statusDefect`, как у `SheetError`; null — ничего.
class FieldError extends StatelessWidget {
  const FieldError(this.text, {super.key});

  final String? text;

  @override
  Widget build(BuildContext context) {
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text!,
        style: TextStyle(fontSize: 12, color: context.colors.defectText),
      ),
    );
  }
}

/// .field-box с полем ввода внутри — визуально не отличается от FieldBox,
/// но значение редактируется на месте (в макете так набраны «Год от»,
/// «Пробег до», «Комментарий»).
class FieldBoxInput extends StatelessWidget {
  const FieldBoxInput({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.mono = false,
    this.unit,
    this.keyboardType,
    this.maxLines = 1,
    this.minHeight,
    this.inputFormatters,
    this.autofocus = false,
    this.maxLength,
    this.error,
    this.warning,
    this.helper,
    this.optional = false,
  });

  /// Текст ошибки под полем; поле — в красной рамке.
  final String? error;

  /// Рекомендация под полем (оранжевая, с иконкой); поле — в оранжевой
  /// рамке. Ошибка показывается вместо неё.
  final String? warning;

  /// Серая пояснительная строка под полем; ошибка и рекомендация важнее.
  final String? helper;

  /// Серое «необязательно» справа от подписи.
  final bool optional;

  final String label;
  final TextEditingController controller;
  final bool autofocus;

  /// Ограничение длины без видимого счётчика — поле визуально как в макете.
  final int? maxLength;
  final String? hint;
  final bool mono;
  final String? unit;
  final TextInputType? keyboardType;
  final int maxLines;
  final double? minHeight;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // в макете «Комментарий» — голый field-box под section-head,
          // без собственной подписи
          if (label.isNotEmpty) ...[
            FieldLabel(label, optional: optional),
            const SizedBox(height: 6),
          ],
          Container(
            constraints: BoxConstraints(minHeight: minHeight ?? 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: context.colors.bg1,
              border: Border.all(
                color: error != null
                    ? context.colors.statusDefect
                    : warning != null
                    ? context.colors.statusProgress
                    : context.colors.line,
                width: error != null || warning != null ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: maxLines > 1
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    keyboardType: keyboardType,
                    maxLines: maxLines,
                    inputFormatters: inputFormatters,
                    autofocus: autofocus,
                    maxLength: maxLength,
                    style: mono
                        ? context.text.fieldMono
                        : context.text.fieldValue,
                    cursorColor: context.colors.statusDone,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintText: hint,
                      hintStyle: context.text.fieldPlaceholder,
                      counterText: '',
                    ),
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    unit!,
                    style: TextStyle(
                      fontFamily: AppTheme.monoFamily,
                      fontSize: 12,
                      color: context.colors.text3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (error != null)
            FieldError(error)
          else if (warning != null)
            FieldWarning(warning!)
          else if (helper != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                helper!,
                // тёмная тема — text2, как было в макете
                style: context.text.fieldNote.copyWith(
                  fontSize: 12,
                  height: 1.35,
                  color: context.colors.isLight ? null : context.colors.text2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Рекомендация под полем: оранжевая иконка и текст, как подсказка
/// «чего не хватает» на экране детали осмотра. Не ошибка — не блокирует.
class FieldWarning extends StatelessWidget {
  const FieldWarning(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline,
              size: 14,
              color: context.colors.progressText,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: context.colors.progressText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
