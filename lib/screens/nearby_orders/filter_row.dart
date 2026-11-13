import 'package:flutter/material.dart';

import '../../data/auth_service.dart';
import '../../state/nearby_feed_controller.dart';
import '../../theme/app_colors.dart';
import '../../widgets/app_ui.dart';

/// .filter-row — быстрые фильтры («Все · N», «Мало откликов»), подписка на
/// новые заказы и включённые фильтры шторки чипами с крестиком.
class NearbyFilterRow extends StatelessWidget {
  const NearbyFilterRow({
    super.key,
    required this.feed,
    required this.all,
    required this.auth,
    required this.onOrderAlerts,
  });

  final NearbyFeedController feed;

  /// Свободных заказов без фильтров.
  final int all;

  /// null — чипа подписки нет (без сессии).
  final AuthService? auth;
  final VoidCallback onOrderAlerts;

  @override
  Widget build(BuildContext context) {
    final work = context.colors.modeWork;
    final auth = this.auth;
    // Align — иначе короткий ряд встаёт по центру колонки
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
        child: Row(
          children: [
            AppChip(
              label: 'Все · $all',
              on: !feed.fewResponsesOnly,
              activeColor: work,
              onTap: () => feed.setFewResponses(false),
            ),
            const SizedBox(width: 6),
            AppChip(
              label: 'Мало откликов',
              on: feed.fewResponsesOnly,
              activeColor: work,
              onTap: () => feed.setFewResponses(true),
            ),
            // подписка на новые заказы — всегда на виду
            if (auth != null)
              ListenableBuilder(
                listenable: auth,
                builder: (context, _) {
                  final alerts = auth.user?.orderAlerts;
                  if (alerts == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: AppChip(
                      key: const ValueKey('order-alerts-chip'),
                      label: alerts.isOn ? 'Уведомления' : 'Сообщать о новых',
                      icon: alerts.isOn
                          ? Icons.notifications_active_outlined
                          : Icons.notifications_none,
                      on: alerts.isOn,
                      activeColor: work,
                      onTap: onOrderAlerts,
                    ),
                  );
                },
              ),
            for (final (label, without) in feed.activeChips()) ...[
              const SizedBox(width: 6),
              AppChip(
                label: '$label  ✕',
                on: true,
                activeColor: work,
                onTap: () => feed.filters.set(without),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Число включённых фильтров поверх кнопки шапки. 0 — без бейджа.
class FilterCountBadge extends StatelessWidget {
  const FilterCountBadge({
    super.key,
    required this.count,
    required this.child,
  });

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -4,
          right: -4,
          child: IgnorePointer(
            child: Container(
              constraints: const BoxConstraints(minWidth: 17),
              height: 17,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.colors.modeWork,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: context.colors.bg0, width: 2),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: context.colors.modeWorkInk,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
