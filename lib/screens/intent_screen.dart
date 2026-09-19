import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';

/// Что пользователь выбрал на стартовом экране.
enum AppIntent { buy, work, browse }

/// Кадр 01 макета design/car-storefront-modes.html — «Что вас сюда
/// привело?». Первый экран приложения: один необязательный вопрос вместо
/// скрытых путей, пропускается любым из трёх вариантов.
///
/// Экран самодостаточный — ни сети, ни сторов, выбор уходит колбэком наружу.
class IntentScreen extends StatelessWidget {
  const IntentScreen({super.key, required this.onChoose});

  final ValueChanged<AppIntent> onChoose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          // .fl-body — по центру экрана, поля 24
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // .fl-mark
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.bg1,
                  border: Border.all(color: AppColors.line),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.directions_car_filled_outlined,
                  size: 26,
                  color: AppColors.text1,
                ),
              ),
              const SizedBox(height: 20),

              const Text('Что вас сюда привело?', style: AppText.flTitle),
              const SizedBox(height: 8),
              const Text(
                'Настроим главный экран. Переключить режим можно в любой '
                'момент — регистрация пока не нужна.',
                style: AppText.flSub,
              ),
              const SizedBox(height: 24),

              _IntentCard(
                accent: AppColors.modeBuy,
                ink: AppColors.modeBuyInk,
                icon: Icons.search,
                name: 'Ищу автомобиль',
                desc: 'Нужен подборщик, который проверит машину',
                onTap: () => onChoose(AppIntent.buy),
              ),
              const SizedBox(height: 10),
              _IntentCard(
                accent: AppColors.modeWork,
                ink: AppColors.modeWorkInk,
                icon: Icons.currency_ruble,
                name: 'Беру заказы на подбор',
                // цифры — текст из макета, а не данные API
                desc: '12 свободных заказов рядом · от 9 000 ₽',
                onTap: () => onChoose(AppIntent.work),
              ),

              CtaGhost(
                label: 'Просто посмотрю',
                onPressed: () => onChoose(AppIntent.browse),
              ),

              const SizedBox(height: 14),
              const SizedBox(
                width: double.infinity,
                child: Text(
                  'Это не роль и не регистрация — только вид главного экрана. '
                  'Аккаунт остаётся один на оба сценария.',
                  style: AppText.flNote,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
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
    required this.icon,
    required this.name,
    required this.desc,
    required this.onTap,
  });

  final Color accent;
  final Color ink;
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
          color: accent.withValues(alpha: 0.06),
          border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.5),
          borderRadius: BorderRadius.circular(17),
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
                  Text(name, style: AppText.flName),
                  const SizedBox(height: 3),
                  Text(desc, style: AppText.flDesc),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: AppColors.text3,
            ),
          ],
        ),
      ),
    );
  }
}
