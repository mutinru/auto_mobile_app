/// Кнопки действия макета (design/app_auto_podbor.html): нижняя область,
/// основная, нейтральная, текстовая и «следующий шаг».
library;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// .detail-cta — нижняя область с разделителем сверху.
class BottomCta extends StatelessWidget {
  const BottomCta({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.colors.line)),
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
          backgroundColor: context.colors.statusDone,
          foregroundColor: context.colors.modeBuyInk,
          disabledBackgroundColor: context.colors.bg3,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
                  if (icon != null) ...[
                    Icon(icon, size: 16),
                    const SizedBox(width: 8),
                  ],
                  // на узком телефоне (360 dp) длинная подпись с иконкой не
                  // влезала в строку — переносится, а не вылезает за кнопку
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: context.text.ctaPrimary,
                    ),
                  ),
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

/// .cta.flat — нейтральная кнопка на bg-3 (например, «Повторить»).
class CtaFlat extends StatelessWidget {
  const CtaFlat({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

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
          backgroundColor: context.colors.bg3,
          foregroundColor: context.colors.text1,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16),
              const SizedBox(width: 8),
            ],
            Text(label, style: context.text.ctaPrimary),
          ],
        ),
      ),
    );
  }
}

/// .cta-ghost — вторичная текстовая кнопка под основной.
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
        child: Text(label, style: context.text.ctaGhost),
      ),
    );
  }
}

/// .next-btn — зелёная кнопка «следующий шаг»: подпись капсом, название
/// пункта и круг со стрелкой. «Дальше» на экране детали и «Начать осмотр» /
/// «Продолжить» на схеме.
class NextStepButton extends StatelessWidget {
  const NextStepButton({
    super.key,
    required this.caption,
    required this.title,
    required this.onPressed,
  });

  final String caption;
  final String title;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: context.colors.statusDone,
        foregroundColor: context.colors.modeBuyInk,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  caption.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: context.colors.modeBuyInk,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_forward,
              color: context.colors.statusDone,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}
