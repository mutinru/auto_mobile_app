import 'package:flutter/material.dart';

import '../state/notification_scope.dart';
import '../theme/app_colors.dart';
import '../widgets/app_ui.dart';
import '../widgets/notification_bell.dart';
import '../widgets/support_sheet.dart';
import '../widgets/theme_switch.dart';

/// Что пользователь выбрал на стартовом экране.
enum AppIntent { buy, work, browse }

/// Кадр 01 макета design/car-storefront-modes.html — «Что вас сюда
/// привело?». Первый экран приложения: один необязательный вопрос вместо
/// скрытых путей, пропускается любым из трёх вариантов.
///
/// Экран самодостаточный — ни сети, ни сторов, выбор уходит колбэком наружу.
/// Сверху — поддержка и переключатель темы (design/first-launch-screen.html):
/// оба доступны ещё до входа. Вошедшему рядом с темой — колокольчик
/// уведомлений, чтобы новое было видно, не выбирая режим.
///
/// Вопрос лежит в корне всегда (QA 2026-11-05 №2, №19): вошедший видит его,
/// вернувшись «назад» из раздела, — поэтому ему тексты без онбординга.
class IntentScreen extends StatelessWidget {
  const IntentScreen({
    super.key,
    required this.onChoose,
    this.onNotifications,
    this.signedIn = false,
  });

  final ValueChanged<AppIntent> onChoose;

  /// Вошёл: «Куда перейти?» без строк про регистрацию.
  final bool signedIn;

  /// Открыть ленту уведомлений. null — гость: колокольчика нет.
  final VoidCallback? onNotifications;

  @override
  Widget build(BuildContext context) {
    final onNotifications = this.onNotifications;
    final showBell =
        onNotifications != null && NotificationScope.maybeOf(context) != null;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // .top-row — поддержка слева, (колокольчик и) тема справа
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SupportButton(),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showBell) ...[
                        NotificationBell(onTap: onNotifications),
                        const SizedBox(width: 8),
                      ],
                      const ThemeSwitch(),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  // .fl-body — по центру экрана, поля 24
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // .fl-mark
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: context.colors.bg1,
                          border: Border.all(color: context.colors.line),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(
                          Icons.directions_car_filled_outlined,
                          size: 26,
                          color: context.colors.text1,
                        ),
                      ),
                      const SizedBox(height: 20),

                      Text(
                        signedIn ? 'Куда перейти?' : 'Что вас сюда привело?',
                        style: context.text.flTitle,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        signedIn
                            ? 'Аккаунт один на оба сценария — переключиться '
                                  'можно в любой момент.'
                            : 'Настроим главный экран. Переключить режим можно '
                                  'в любой момент — регистрация пока не нужна.',
                        style: context.text.flSub,
                      ),
                      const SizedBox(height: 24),

                      _IntentCard(
                        accent: context.colors.modeBuy,
                        ink: context.colors.modeBuyInk,
                        soft: context.colors.buySoft,
                        edge: context.colors.buyEdge,
                        icon: Icons.search,
                        name: 'Ищу автомобиль',
                        desc: 'Нужен подборщик, который проверит машину',
                        onTap: () => onChoose(AppIntent.buy),
                      ),
                      const SizedBox(height: 10),
                      _IntentCard(
                        accent: context.colors.modeWork,
                        ink: context.colors.modeWorkInk,
                        soft: context.colors.workSoft,
                        edge: context.colors.workEdge,
                        icon: Icons.currency_ruble,
                        name: 'Беру заказы на подбор',
                        // без цифр: в макете «12 заказов · от 9 000 ₽» —
                        // выдумка, а живых данных у экрана нет (он без сети
                        // и без геопозиции, «рядом» посчитать не из чего)
                        desc:
                            'Подборы и разовые осмотры — заказчики платят за работу',
                        onTap: () => onChoose(AppIntent.work),
                      ),

                      CtaGhost(
                        label: 'Просто посмотрю',
                        onPressed: () => onChoose(AppIntent.browse),
                      ),

                      if (!signedIn) ...[
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            'Это не роль и не регистрация — только вид главного экрана. '
                            'Аккаунт остаётся один на оба сценария.',
                            style: context.text.flNote,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// .fl-card — крупный вариант выбора с цветным акцентом режима.
class _IntentCard extends StatelessWidget {
  const _IntentCard({
    required this.accent,
    required this.ink,
    required this.soft,
    required this.edge,
    required this.icon,
    required this.name,
    required this.desc,
    required this.onTap,
  });

  final Color accent;
  final Color ink;

  /// --buy-soft / --work-soft и --*-edge: прозрачность в темах разная,
  /// поэтому не выводим из [accent], а берём токены палитры.
  final Color soft;
  final Color edge;
  final IconData icon;
  final String name;
  final String desc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: soft,
          border: Border.all(color: edge, width: 1.5),
          borderRadius: BorderRadius.circular(17),
          boxShadow: [
            BoxShadow(
              color: context.colors.cardShadow,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // .fl-ico
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 20, color: ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: context.text.flName),
                  const SizedBox(height: 3),
                  Text(desc, style: context.text.flDesc),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 16, color: context.colors.text3),
          ],
        ),
      ),
    );
  }
}
