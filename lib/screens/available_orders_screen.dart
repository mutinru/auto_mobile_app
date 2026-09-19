import 'package:flutter/material.dart';

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

  @override
  void initState() {
    super.initState();
    widget.store.loadAvailableOrders();
  }

  Future<void> _respond(Order order) async {
    final result = await showModalBottomSheet<(int, String?)>(
      context: context,
      backgroundColor: AppColors.bg0,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => RespondSheet(order: order),
    );
    if (result == null) return;

    try {
      await widget.store
          .respondToOrder(order.id, proposedPrice: result.$1, message: result.$2);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Отклик отправлен')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не получилось откликнуться: $e')),
        );
      }
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
                      const Expanded(
                        child: _RegionButton(
                          icon: Icons.location_on_outlined,
                          title: 'Москва',
                          sub: 'Центральный ФО',
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
                        child: CustomPaint(painter: const CityMapPainter()),
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
        color: AppColors.bg1,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: AppColors.text3),
            const SizedBox(width: 8),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.text1,
                ),
              ),
              const SizedBox(height: 1),
              Text(sub, style: const TextStyle(fontSize: 10, color: AppColors.text3)),
            ],
          ),
          if (chevron) ...[
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.text3),
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
          color: AppColors.statusInfo,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.bg0, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.statusInfo.withValues(alpha: 0.16),
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
              color: hot ? AppColors.statusDone : AppColors.bg3,
              border: Border.all(
                color: hot ? AppColors.statusDone : AppColors.line,
              ),
              borderRadius: BorderRadius.circular(999),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x80000000),
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
                color: hot ? const Color(0xFF07150E) : AppColors.text1,
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
      decoration: const BoxDecoration(
        color: AppColors.bg0,
        border: Border(top: BorderSide(color: AppColors.line)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(color: Color(0x8C000000), blurRadius: 40, offset: Offset(0, -18)),
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
              color: AppColors.bg3,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // .sheet-head
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Рядом с вами',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.14,
                  color: AppColors.text1,
                ),
              ),
              Text(
                '${orders.length} заказов',
                style: const TextStyle(
                  fontFamily: AppTheme.monoFamily,
                  fontSize: 11,
                  color: AppColors.text3,
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
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Рядом пока пусто',
                          style: TextStyle(color: AppColors.text3, fontSize: 12),
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
      '${order.responses.length} откл.',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.bg1,
        border: Border.all(color: AppColors.line),
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
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.14,
                    color: AppColors.text1,
                  ),
                ),
              ),
              if (order.budgetMax != null)
                Text(
                  '${money(order.budgetMax!)} ₽',
                  style: const TextStyle(
                    fontFamily: AppTheme.monoFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.statusDone,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            meta.join('   '),
            style: const TextStyle(fontSize: 11.5, color: AppColors.text2),
          ),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onRespond,
              style: ElevatedButton.styleFrom(
                backgroundColor: first ? AppColors.statusDone : AppColors.bg3,
                foregroundColor: first ? const Color(0xFF07150E) : AppColors.text1,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Откликнуться',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
