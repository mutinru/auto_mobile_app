/// Шапки и мелкие блоки макета (design/app_auto_podbor.html): шапка
/// экрана, плашки, аватар, заголовок секции. Значения — из стилей макета,
/// имена CSS-классов — в комментариях.
library;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_theme.dart';

/// «Назад» для [DetailHead.onBack] — только если под этим экраном есть
/// маршрут. Не Navigator.canPop(): тот true и тогда, когда поверх открыт
/// другой экран, — экран-раздел, перерисованный из-под него (общий стор),
/// получал ложную стрелку, а её pop() снимал корневой маршрут → чёрный экран.
VoidCallback? backIfCanPop(BuildContext context) =>
    (ModalRoute.of(context)?.canPop ?? false)
    ? () => Navigator.of(context).maybePop()
    : null;

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
                  Text(
                    eyebrow!.toUpperCase(),
                    style: context.text.detailEyebrow,
                  ),
                  const SizedBox(height: 3),
                ],
                Text(title, style: context.text.detailTitle),
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
          color: context.colors.bg1,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: size, color: context.colors.text2),
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
        color: context.colors.bg1,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: AppTheme.monoFamily,
          fontSize: 12,
          color: context.colors.text3,
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
        color: color == null
            ? context.colors.bg3
            : color!.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text.toUpperCase(),
        style: context.text.pill.copyWith(
          color: color == null
              ? context.colors.text2
              : context.colors.textFor(color!),
        ),
      ),
    );
  }
}

/// .avatar — кружок с инициалами и градиентом из макета. С [url] — фото
/// пользователя той же формы; пока грузится или не загрузилось — инициалы.
class Avatar extends StatelessWidget {
  const Avatar(this.initials, {super.key, this.size = 26, this.url});

  final String initials;
  final double size;

  /// Аватар с сервера (квадрат 512×512); null — только инициалы.
  final String? url;

  bool get _large => size >= 48;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: _large ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: _large ? BorderRadius.circular(17) : null,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [context.colors.avatarFrom, context.colors.avatarTo],
        ),
      ),
      child: Text(
        initials,
        style: context.text.avatar.copyWith(fontSize: _large ? 17 : 10),
      ),
    );
    final url = this.url;
    if (url == null) return fallback;

    // декодируем под размер на экране, а не все 512 px на каждую карточку
    final px = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    final image = Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      cacheWidth: px,
      frameBuilder: (_, child, frame, sync) =>
          frame == null && !sync ? fallback : child,
      errorBuilder: (_, _, _) => fallback,
    );
    return _large
        ? ClipRRect(borderRadius: BorderRadius.circular(17), child: image)
        : ClipOval(child: image);
  }
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
          Text(title.toUpperCase(), style: context.text.sectionTitle),
          if (extra != null) Text(extra!, style: context.text.sectionExtra),
        ],
      ),
    );
  }
}
