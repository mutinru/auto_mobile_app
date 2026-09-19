import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Повторяющиеся блоки макета (design/app_auto_podbor.html).
/// Каждый виджет соответствует CSS-классу, значения взяты из стилей,
/// а не подобраны на глаз — см. комментарии с именами классов.

/// .detail-head — шапка экрана: кнопка назад, надстрочник + заголовок,
/// справа либо .detail-pos (счётчик), либо .head-action (иконка).
class DetailHead extends StatelessWidget {
  const DetailHead({
    super.key,
    required this.title,
    this.eyebrow,
    this.onBack,
    this.trailing,
  });

  final String title;
  final String? eyebrow;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // .detail-head { padding: 18px 22px 14px; gap: 12px }
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 14),
      child: Row(
        children: [
          if (onBack != null) ...[
            SquareIconButton(icon: Icons.arrow_back, onTap: onBack!),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(eyebrow!.toUpperCase(), style: AppText.detailEyebrow),
                  const SizedBox(height: 3),
                ],
                Text(title, style: AppText.detailTitle),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

/// .back / .head-action — квадратная кнопка 38×38 с радиусом 11.
class SquareIconButton extends StatelessWidget {
  const SquareIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 17,
  });

  final IconData icon;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: AppColors.bg1,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: size, color: AppColors.text2),
      ),
    );
  }
}

/// .detail-pos — моноширинный счётчик справа в шапке (04/13, 2 / 4, 34 мин).
class DetailPos extends StatelessWidget {
  const DetailPos(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontFamily: AppTheme.monoFamily,
          fontSize: 12,
          color: AppColors.text3,
        ),
      ),
    );
  }
}

/// .pill — статусная плашка. Цвет задаётся снаружи: фон — 14% от него.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color});

  final String text;

  /// null → нейтральный вариант (.pill без модификатора: bg-3 / text-2)
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color == null ? AppColors.bg3 : color!.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text.toUpperCase(),
        style: AppText.pill.copyWith(color: color ?? AppColors.text2),
      ),
    );
  }
}

/// .avatar — кружок с инициалами и градиентом из макета.
class Avatar extends StatelessWidget {
  const Avatar(this.initials, {super.key, this.size = 26});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: size >= 48 ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: size >= 48 ? BorderRadius.circular(17) : null,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5A6470), Color(0xFF2C3138)],
        ),
      ),
      child: Text(
        initials,
        style: AppText.avatar.copyWith(fontSize: size >= 48 ? 17 : 10),
      ),
    );
  }
}

/// .section-head — подпись секции + опциональная правая подпись.
class SectionHead extends StatelessWidget {
  const SectionHead(this.title, {super.key, this.extra});

  final String title;
  final String? extra;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title.toUpperCase(), style: AppText.sectionTitle),
          if (extra != null) Text(extra!, style: AppText.sectionExtra),
        ],
      ),
    );
  }
}

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
  });

  final String label;
  final String value;

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
        ? AppText.fieldMono
        : (placeholder ? AppText.fieldPlaceholder : AppText.fieldValue);

    return Padding(
      // .field { margin-bottom: 10px }
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppText.fieldLabel),
          const SizedBox(height: 6),
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              constraints: BoxConstraints(minHeight: minHeight ?? 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: AppColors.bg1,
                border: Border.all(color: AppColors.line),
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
                      style: const TextStyle(
                        fontFamily: AppTheme.monoFamily,
                        fontSize: 12,
                        color: AppColors.text3,
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
        ],
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
  });

  final String label;
  final TextEditingController controller;
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
            Text(label.toUpperCase(), style: AppText.fieldLabel),
            const SizedBox(height: 6),
          ],
          Container(
            constraints: BoxConstraints(minHeight: minHeight ?? 0),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.bg1,
              border: Border.all(color: AppColors.line),
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
                    style: mono ? AppText.fieldMono : AppText.fieldValue,
                    cursorColor: AppColors.statusDone,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintText: hint,
                      hintStyle: AppText.fieldPlaceholder,
                    ),
                  ),
                ),
                if (unit != null) ...[
                  const SizedBox(width: 10),
                  Text(
                    unit!,
                    style: const TextStyle(
                      fontFamily: AppTheme.monoFamily,
                      fontSize: 12,
                      color: AppColors.text3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// .chip — переключаемая «таблетка». В app_auto_podbor.html активный
/// вариант оранжевый (st-progress), а не зелёный.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.on,
    this.onTap,
    this.activeColor = AppColors.statusProgress,
  });

  final String label;
  final bool on;
  final VoidCallback? onTap;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: on ? activeColor.withValues(alpha: 0.12) : AppColors.bg1,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: on ? activeColor.withValues(alpha: 0.5) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: AppText.chip.copyWith(color: on ? activeColor : AppColors.text2),
        ),
      ),
    );
  }
}

/// .detail-cta — нижняя область с разделителем сверху.
class BottomCta extends StatelessWidget {
  const BottomCta({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

/// .cta-primary — основная зелёная кнопка во всю ширину.
class CtaPrimary extends StatelessWidget {
  const CtaPrimary({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.trailingIcon,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.statusDone,
          foregroundColor: const Color(0xFF07150E),
          disabledBackgroundColor: AppColors.bg3,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 8)],
                  Text(label, style: AppText.ctaPrimary),
                  if (trailingIcon != null) ...[
                    const SizedBox(width: 8),
                    Icon(trailingIcon, size: 16),
                  ],
                ],
              ),
      ),
    );
  }
}

/// .cta-ghost — вторичная текстовая кнопка под основной.
/// .cta.flat — нейтральная кнопка на bg-3 (например, «Показать на карте»).
class CtaFlat extends StatelessWidget {
  const CtaFlat({super.key, required this.label, required this.onPressed, this.icon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.bg3,
          foregroundColor: AppColors.text1,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, size: 16), const SizedBox(width: 8)],
            Text(label, style: AppText.ctaPrimary),
          ],
        ),
      ),
    );
  }
}

class CtaGhost extends StatelessWidget {
  const CtaGhost({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(padding: const EdgeInsets.all(12)),
        child: Text(label, style: AppText.ctaGhost),
      ),
    );
  }
}

/// .toggle — сегментированный переключатель под шапкой.
class AppToggle extends StatelessWidget {
  const AppToggle({
    super.key,
    required this.labels,
    required this.activeIndex,
    required this.onChanged,
  });

  final List<String> labels;
  final int activeIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      // .toggle { margin: 0 22px 14px; padding: 3px; radius: 10px }
      margin: const EdgeInsets.fromLTRB(22, 0, 22, 14),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(7),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == activeIndex ? AppColors.bg3 : Colors.transparent,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: i == activeIndex ? AppColors.text1 : AppColors.text2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Форматирование чисел как в макете: 2 400 000 ₽, 127 450 км.
String money(int value) {
  final s = value.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Инициалы для .avatar из имени вида «Максим К.» → «МК».
String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  final buf = StringBuffer();
  for (final p in parts.take(2)) {
    if (p.isNotEmpty) buf.write(p[0].toUpperCase());
  }
  return buf.toString();
}


/// VIN: ровно 17 знаков, только заглавные латинские и цифры.
/// Буквы I, O и Q в VIN не используются — их легко спутать с 1 и 0,
/// поэтому отсекаем сразу, а не ловим потом ошибкой сервера.
class VinFormatter extends TextInputFormatter {
  const VinFormatter();

  static final _allowed = RegExp(r'[A-HJ-NPR-Z0-9]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleaned = newValue.text
        .toUpperCase()
        .split('')
        .where(_allowed.hasMatch)
        .join();
    final capped = cleaned.length > 17 ? cleaned.substring(0, 17) : cleaned;

    return TextEditingValue(
      text: capped,
      selection: TextSelection.collapsed(offset: capped.length),
    );
  }
}
