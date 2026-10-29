import 'package:flutter/material.dart';

import '../models/city.dart';
import '../models/order.dart';
import '../state/order_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import '../widgets/city_map.dart';
import '../widgets/respond_sheet.dart';

/// Экран 04 макета — «заказы рядом»: карта с пинами и нижний лист.
///
/// Карта декоративная: у заказов на бекенде нет координат, поэтому пины
/// расставлены по фиксированным позициям из макета, а цена на них — живая.
class AvailableOrdersScreen extends StatefulWidget {
  const AvailableOrdersScreen({super.key, required this.store});

  final OrderStore store;

  @override
  State<AvailableOrdersScreen> createState() => _AvailableOrdersScreenState();
}

class _AvailableOrdersScreenState extends State<AvailableOrdersScreen> {
  /// Позиции пинов из макета (доли ширины/высоты .map-wrap).
  static const _pinSpots = [
    (0.38, 0.36),
    (0.72, 0.28),
    (0.24, 0.62),
    (0.66, 0.66),
    (0.47, 0.82),
  ];

  /// Город по геопозиции для шапки; null — не определён (или ещё ищем).
  City? _city;
  late bool _locating = widget.store.locator != null;

  @override
  void initState() {
    super.initState();
    widget.store.loadAvailableOrders();
    _detectCity();
  }

  Future<void> _detectCity() async {
    final city = await widget.store.locator?.detect();
    if (mounted) {
      setState(() {
        _city = city;
        _locating = false;
      });
    }
  }

  /// На карте только подборы (осмотры не рисуются) — реквизиты не нужны.
  Future<void> _respond(Order order) async {
    final sent = await showRespondSheet(
      context,
      order: order,
      onSubmit: (price, message, _) =>
          widget.store.respondToOrder(order.id, proposedPrice: price, message: message),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Отклик отправлен')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        // осмотры на карте не рисуем: у них нет ни координат, ни бюджета,
        // из которых собран пин
        final orders =
            widget.store.availableOrders.where((o) => !o.isInspection).toList();

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                DetailHead(
                  title: 'Заказы на карте',
                  eyebrow: 'свободных заказов · ${orders.length}',
                  onBack: () => Navigator.of(context).pop(),
                  trailing: SquareIconButton(icon: Icons.tune, onTap: () {}),
                ),
                // .region-bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _RegionButton(
                          icon: Icons.location_on_outlined,
                          title: _city?.name ??
                              (_locating ? 'Определяем…' : 'Город не определён'),
                          sub: _city?.region ?? 'по геопозиции',
                          chevron: true,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const _RegionButton(title: '25 км', sub: 'радиус'),
                    ],
                  ),
                ),
                // .map-wrap + .sheet
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: CityMapPainter(context.colors.map)),
                      ),
                      // .map-me — точка «вы здесь» (52% / 50% в макете)
                      const Positioned.fill(
                        child: Align(
                          alignment: Alignment(0.04, 0),
                          child: _MeDot(),
                        ),
                      ),
                      for (var i = 0; i < orders.length && i < _pinSpots.length; i++)
                        _Pin(
                          spot: _pinSpots[i],
                          label: orders[i].budgetMax != null
                              ? '${money(orders[i].budgetMax! ~/ 1000)}К'
                              : '#${orders[i].id}',
                          hot: i == 0,
                          onTap: () => _respond(orders[i]),
                        ),
                      // нижний лист
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: _Sheet(
                          orders: orders,
                          loading: widget.store.isLoadingAvailable,
                          onRespond: _respond,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// .region-btn
class _RegionButton extends StatelessWidget {
  const _RegionButton({
    required this.title,
    required this.sub,
    this.icon,
    this.chevron = false,
  });

  final String title;
  final String sub;
  final IconData? icon;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: context.colors.bg1,
        border: Border.all(color: context.colors.line),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: context.colors.text3),
            const SizedBox(width: 8),
          ],
          // длинный регион («Ханты-Мансийский АО – Югра») обрезаем
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.colors.text1,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: context.colors.text3),
                ),
              ],
            ),
          ),
          if (chevron) ...[
            const SizedBox(width: 8),
            Icon(Icons.keyboard_arrow_down, size: 14, color: context.colors.text3),
          ],
        ],
      ),
    );
  }
}

/// .map-me
class _MeDot extends StatelessWidget {
  const _MeDot();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 14,
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.statusInfo,
          shape: BoxShape.circle,
          border: Border.all(color: context.colors.bg0, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: context.colors.statusInfo.withValues(alpha: 0.16),
              spreadRadius: 8,
            ),
          ],
        ),
      ),
    );
  }
}

/// .map-pin
class _Pin extends StatelessWidget {
  const _Pin({
    required this.spot,
    required this.label,
    required this.hot,
    required this.onTap,
  });

  final (double, double) spot;
  final String label;
  final bool hot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Alignment принимает -1..1, а доли из макета заданы 0..1
    return Positioned.fill(
      child: Align(
        alignment: Alignment(spot.$1 * 2 - 1, spot.$2 * 2 - 1),
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: hot ? context.colors.statusDone : context.colors.bg3,
              border: Border.all(
                color: hot ? context.colors.statusDone : context.colors.line,
              ),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: context.colors.sheetShadow,
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.monoFamily,
                fontSize: 11,
                fontWeight: hot ? FontWeight.w700 : FontWeight.w500,
                color: hot ? context.colors.modeBuyInk : context.colors.text1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// .sheet — нижний лист со списком заказов.
class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.orders,
    required this.loading,
    required this.onRespond,
  });

  final List<Order> orders;
  final bool loading;
  final ValueChanged<Order> onRespond;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.42,
      ),
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
      decoration: BoxDecoration(
        color: context.colors.bg0,
        border: Border(top: BorderSide(color: context.colors.line)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(color: context.colors.sheetShadow, blurRadius: 40, offset: Offset(0, -18)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // .sheet-handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: context.colors.bg3,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // .sheet-head
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Рядом с вами',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.14,
                  color: context.colors.text1,
                ),
              ),
              Text(
                '${orders.length} заказов',
                style: TextStyle(
                  fontFamily: AppTheme.monoFamily,
                  fontSize: 11,
                  color: context.colors.text3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Flexible(
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  )
                : orders.isEmpty
                    ? Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Рядом пока пусто',
                          style: TextStyle(color: context.colors.text3, fontSize: 12),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: orders.length,
                        itemBuilder: (context, i) => _JobCard(
                          order: orders[i],
                          first: i == 0,
                          onRespond: () => onRespond(orders[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

/// .job-card
class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.order,
    required this.first,
    required this.onRespond,
  });

  final Order order;
  final bool first;
  final VoidCallback onRespond;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      if (order.cities.isNotEmpty) order.cities.first,
      if (order.budgetMax != null) 'до ${money(order.budgetMax!)} ₽',
      '${order.responsesCount} откл.',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: context.colors.bg1,
        border: Border.all(color: context.colors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // .job-top
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  order.carTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.14,
                    color: context.colors.text1,
                  ),
                ),
              ),
              if (order.budgetMax != null)
                Text(
                  '${money(order.budgetMax!)} ₽',
                  style: TextStyle(
                    fontFamily: AppTheme.monoFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.colors.statusDone,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            meta.join('   '),
            style: TextStyle(fontSize: 11.5, color: context.colors.text2),
          ),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: order.hasViewerResponse ? null : onRespond,
              style: ElevatedButton.styleFrom(
                backgroundColor: first ? context.colors.statusDone : context.colors.bg3,
                foregroundColor: first ? context.colors.modeBuyInk : context.colors.text1,
                disabledBackgroundColor: context.colors.bg3,
                disabledForegroundColor: context.colors.text3,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                order.hasViewerResponse ? 'Вы откликнулись' : 'Откликнуться',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
