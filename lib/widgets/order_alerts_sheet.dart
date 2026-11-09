import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../data/city_repository.dart';
import '../models/order_alerts.dart';
import '../models/order_kind.dart';
import '../state/city_locator.dart';
import '../theme/app_colors.dart';
import 'api_error.dart';
import 'app_sheet.dart';
import 'app_ui.dart';
import 'city_picker_sheet.dart';

/// Подписка на новые заказы: города (чип с ✕ снимает), «Добавить город…»
/// через справочник и виды заказов. Сохраняет сама (PUT /me/order-alerts)
/// и закрывается; ошибка — снекбаром, шторка остаётся.
Future<void> showOrderAlertsSheet(
  BuildContext context, {
  required AuthService auth,
  CityRepository? cities,
  CityLocator? locator,
  Set<String> suggested = const {},
}) {
  return showAppSheet<void>(
    context,
    (_) => OrderAlertsSheet(
      auth: auth,
      cities: cities,
      locator: locator,
      suggested: suggested,
    ),
  );
}

class OrderAlertsSheet extends StatefulWidget {
  const OrderAlertsSheet({
    super.key,
    required this.auth,
    this.cities,
    this.locator,
    this.suggested = const {},
  });

  final AuthService auth;

  /// Города для выключенной подписки — подставляются сразу (города фильтра
  /// ленты), сохранит их только «Сохранить».
  final Set<String> suggested;

  /// Справочник для «Добавить город…»; null — добавить нечем (тесты).
  final CityRepository? cities;
  final CityLocator? locator;

  @override
  State<OrderAlertsSheet> createState() => _OrderAlertsSheetState();
}

class _OrderAlertsSheetState extends State<OrderAlertsSheet> {
  late OrderAlerts _alerts = _initial();

  OrderAlerts _initial() {
    final alerts = widget.auth.user?.orderAlerts ?? const OrderAlerts();
    if (alerts.isOn || widget.suggested.isEmpty) return alerts;
    return alerts.copyWith(
      cities: widget.suggested.take(OrderAlerts.maxCities).toSet(),
    );
  }

  bool _saving = false;

  Future<void> _addCities() async {
    final next = await showCityPickerSheet(
      context,
      cities: widget.cities!,
      selected: _alerts.cities,
      locator: widget.locator,
    );
    if (next == null || !mounted) return;
    setState(() => _alerts = _alerts.copyWith(cities: next));
  }

  void _toggleKind(OrderKind kind) {
    final kinds = {..._alerts.kinds};
    // хотя бы один вид — иначе подписка ни о чём
    if (kinds.contains(kind) && kinds.length == 1) return;
    kinds.contains(kind) ? kinds.remove(kind) : kinds.add(kind);
    setState(() => _alerts = _alerts.copyWith(kinds: kinds));
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.auth.updateOrderAlerts(_alerts);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final work = c.modeWork;
    final cities = _alerts.cities.toList()..sort();
    final full = cities.length >= OrderAlerts.maxCities;

    return SheetFrame(
      title: 'Новые заказы рядом',
      subtitle: 'Пуш, когда в этих городах опубликуют заказ',
      children: [
        const SectionHead('Города'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final city in cities)
              AppChip(
                label: '$city  ✕',
                on: true,
                activeColor: work,
                onTap: () => setState(
                  () => _alerts = _alerts.copyWith(
                    cities: {..._alerts.cities}..remove(city),
                  ),
                ),
              ),
            if (widget.cities != null && !full)
              AppChip(
                label: cities.isEmpty ? 'Выбрать город…' : 'Добавить город…',
                on: false,
                activeColor: work,
                onTap: _addCities,
              ),
          ],
        ),
        if (full)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Не больше ${OrderAlerts.maxCities} городов',
              style: context.text.fieldNote,
            ),
          ),
        const SizedBox(height: 18),
        const SectionHead('Какие заказы'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final kind in OrderKind.values)
              AppChip(
                label: kind.isInspection ? 'Осмотры' : 'Подборы',
                on: _alerts.kinds.contains(kind),
                activeColor: work,
                onTap: () => _toggleKind(kind),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          cities.isEmpty
              ? 'Без городов уведомлений не будет.'
              : 'Ночью (22:00–8:00 по времени города) не беспокоим — '
                    'пуш придёт утром, если заказ ещё свободен.',
          style: context.text.fieldNote,
        ),
        const SizedBox(height: 18),
        CtaPrimary(
          label: 'Сохранить',
          loading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
