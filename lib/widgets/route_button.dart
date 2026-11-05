import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/order.dart';
import '../util/route_link.dart';
import 'app_ui.dart';

/// «Маршрут до осмотра» — открывает внешний навигатор: карта в приложении
/// не нужна. Ссылки — [routeLinks]; не открылась ни одна — SnackBar.
class RouteButton extends StatelessWidget {
  const RouteButton({super.key, required this.order});

  final Order order;

  Future<void> _open(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    for (final link in routeLinks(order)) {
      try {
        if (await launchUrl(link, mode: LaunchMode.externalApplication)) {
          return;
        }
      } catch (_) {
        // нет приложения под эту схему — пробуем следующую ссылку
      }
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Не удалось открыть навигатор')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CtaFlat(
      label: 'Маршрут до осмотра',
      icon: Icons.directions_outlined,
      onPressed: () => _open(context),
    );
  }
}
