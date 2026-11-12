import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../data/profile_repository.dart';
import '../models/order_alerts.dart';
import '../theme/app_colors.dart';
import 'api_error.dart';

/// Предложение подписаться на новые заказы в городах фильтра ленты —
/// подписка явная, но на виду: под пустой лентой и в конце списка.
/// Все города уже в подписке — карточки нет, а под пустой лентой
/// ([emptyFeed]) строка «пришлём пуш» со ссылкой на настройку.
class OrderAlertsPrompt extends StatefulWidget {
  const OrderAlertsPrompt({
    super.key,
    required this.auth,
    required this.cities,
    required this.onConfigure,
    this.emptyFeed = false,
  });

  final AuthService auth;

  /// Города фильтра ленты.
  final Set<String> cities;

  /// Шторка подписки — когда одним тапом не выйти (лимит городов) или
  /// из строки «Настроить».
  final VoidCallback onConfigure;
  final bool emptyFeed;

  @override
  State<OrderAlertsPrompt> createState() => _OrderAlertsPromptState();
}

class _OrderAlertsPromptState extends State<OrderAlertsPrompt> {
  late final _profile = ProfileRepository.of(widget.auth);
  bool _saving = false;

  Future<void> _subscribe(OrderAlerts alerts, Set<String> missing) async {
    final cities = {...alerts.cities, ...missing};
    if (cities.length > OrderAlerts.maxCities) {
      widget.onConfigure();
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await _profile.updateOrderAlerts(alerts.copyWith(cities: cities));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Пришлём пуш о новых заказах: ${_names(missing)}',
          ),
        ),
      );
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _names(Set<String> cities) =>
      (cities.toList()..sort()).join(', ');

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.auth,
      builder: (context, _) {
        final user = widget.auth.user;
        if (user == null || widget.cities.isEmpty) {
          return const SizedBox.shrink();
        }
        final alerts = user.orderAlerts;
        final missing = {
          for (final city in widget.cities)
            if (!alerts.covers(city)) city,
        };
        if (missing.isEmpty) {
          return widget.emptyFeed
              ? _subscribedLine(context)
              : const SizedBox.shrink();
        }
        return _card(context, alerts, missing);
      },
    );
  }

  Widget _subscribedLine(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Center(
        child: TextButton.icon(
          onPressed: widget.onConfigure,
          icon: Icon(
            Icons.notifications_active_outlined,
            size: 16,
            color: c.text2,
          ),
          label: Text(
            'Пришлём пуш, когда появится заказ · Настроить',
            style: TextStyle(fontSize: 12.5, color: c.text2),
          ),
        ),
      ),
    );
  }

  Widget _card(BuildContext context, OrderAlerts alerts, Set<String> missing) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(top: 14, bottom: 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: c.bg1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.line),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_none, size: 20, color: c.modeWork),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Сообщать о новых заказах',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: c.text1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_names(missing)} — пуш, как только опубликуют',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: c.text2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _saving ? null : () => _subscribe(alerts, missing),
            style: ElevatedButton.styleFrom(
              backgroundColor: c.modeWork,
              foregroundColor: c.modeWorkInk,
              elevation: 0,
              // ширина не прыгает, пока вместо подписи крутилка
              minimumSize: const Size(104, 40),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: _saving
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.modeWorkInk,
                    ),
                  )
                : const Text('Включить'),
          ),
        ],
      ),
    );
  }
}
