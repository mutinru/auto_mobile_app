import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../data/verification_repository.dart';
import '../models/order.dart';
import '../state/order_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../util/ru_date.dart';
import '../widgets/app_ui.dart';
import '../widgets/respond_sheet.dart';
import 'available_orders_screen.dart';
import 'verification_screen.dart';

/// Экран 03 макета car-storefront-modes.html — «Беру заказы»: список
/// свободных заказов с гейтом верификации. Кнопка внизу ведёт на карту
/// (экран 04, [AvailableOrdersScreen]).
///
/// Чего в API нет и что не переносится из макета: расстояние в километрах
/// и радиус поиска (координат у заказов нет — показываем город), фильтры
/// «До 10 км» и «От 12 000 ₽», переключатель режимов витрины.
class NearbyOrdersScreen extends StatefulWidget {
  const NearbyOrdersScreen({
    super.key,
    required this.store,
    required this.verification,
    this.auth,
  });

  final OrderStore store;
  final VerificationRepository verification;

  /// Нужен только экрану верификации, на который ведёт гейт.
  final AuthService? auth;

  @override
  State<NearbyOrdersScreen> createState() => _NearbyOrdersScreenState();
}

class _NearbyOrdersScreenState extends State<NearbyOrdersScreen> {
  VerificationSummary? _verification;

  /// true — показываем только заказы с малым числом откликов.
  bool _fewResponsesOnly = false;

  @override
  void initState() {
    super.initState();
    widget.store.loadAvailableOrders();
    _loadVerification();
  }

  /// Ошибку гейта глотаем: без неё список всё равно нужен, а кнопки
  /// отклика без данных верификации остаются закрытыми.
  Future<void> _loadVerification() async {
    try {
      final summary = await widget.verification.fetchSummary();
      if (mounted) setState(() => _verification = summary);
    } catch (_) {
      // молча — гейт просто останется в закрытом состоянии
    }
  }

  bool get _canRespond => _verification?.complete ?? false;

  List<Order> _visible(List<Order> orders) => _fewResponsesOnly
      ? orders.where((o) => o.responses.length <= 2).toList()
      : orders;

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _openVerification() {
    final auth = widget.auth;
    if (auth == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => VerificationScreen(auth: auth)),
    );
  }

  void _openMap() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AvailableOrdersScreen(store: widget.store)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: widget.store,
          builder: (context, _) {
            final all = widget.store.availableOrders;
            final orders = _visible(all);

            return Column(
              children: [
                DetailHead(
                  title: 'Заказы рядом',
                  eyebrow: 'свободные · ${all.length}',
                  onBack: Navigator.of(context).canPop()
                      ? () => Navigator.of(context).pop()
                      : null,
                  trailing: SquareIconButton(icon: Icons.tune, onTap: () {}),
                ),

                // .filter-row — только фильтры, работающие на живых данных
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                  child: Row(
                    children: [
                      AppChip(
                        label: 'Все · ${all.length}',
                        on: !_fewResponsesOnly,
                        activeColor: AppColors.modeWork,
                        onTap: () => setState(() => _fewResponsesOnly = false),
                      ),
                      const SizedBox(width: 6),
                      AppChip(
                        label: 'Мало откликов',
                        on: _fewResponsesOnly,
                        activeColor: AppColors.modeWork,
                        onTap: () => setState(() => _fewResponsesOnly = true),
                      ),
                    ],
                  ),
                ),

                Expanded(child: _body(orders)),

                BottomCta(
                  children: [
                    CtaFlat(
                      label: 'Показать на карте',
                      icon: Icons.location_on_outlined,
                      onPressed: _openMap,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _body(List<Order> orders) {
    final error = widget.store.availableError;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Не удалось загрузить заказы',
              style: TextStyle(fontSize: 14, color: AppColors.text1),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: AppColors.text3),
            ),
            const SizedBox(height: 10),
            CtaGhost(
              label: 'Повторить',
              onPressed: () => widget.store.loadAvailableOrders(),
            ),
          ],
        ),
      );
    }

    if (widget.store.isLoadingAvailable) {
      return const Center(child: CircularProgressIndicator());
    }

    final gate = _verification;
    final showGate = gate == null || !gate.complete;

    return RefreshIndicator(
      onRefresh: () => widget.store.loadAvailableOrders(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 2, 22, 16),
        children: [
          if (showGate)
            _VerificationGate(
              summary: gate,
              onTap: widget.auth == null ? null : _openVerification,
            ),
          if (orders.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(
                child: Text(
                  'Свободных заказов сейчас нет',
                  style: TextStyle(fontSize: 13, color: AppColors.text2),
                ),
              ),
            ),
          for (final order in orders)
            _JobCard(
              order: order,
              canRespond: _canRespond,
              onRespond: () => _respond(order),
            ),
        ],
      ),
    );
  }
}

/// .gate — шлагбаум верификации. Клиентский: сам бекенд отклик не
/// проверяет, а на экране карты кнопка «Откликнуться» остаётся живой.
class _VerificationGate extends StatelessWidget {
  const _VerificationGate({required this.summary, required this.onTap});

  final VerificationSummary? summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final progress = summary?.progress ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg1,
        border: Border.all(color: AppColors.modeWork.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.modeWork.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  size: 17,
                  color: AppColors.modeWork,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Смотреть можно, откликаться — нет',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.14,
                        color: AppColors.text1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary == null
                          ? 'Нужна верификация: вход, опыт, тест на дефекты · ~20 минут'
                          : 'Нужна верификация: пройдено ${summary!.passed} из '
                              '${summary!.total} шагов · ~20 минут',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.text2,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          // .gate-prog
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: AppColors.bg0,
              valueColor: const AlwaysStoppedAnimation(AppColors.modeWork),
            ),
          ),
          const SizedBox(height: 11),
          // .gate-btn
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.modeWork,
                foregroundColor: AppColors.modeWorkInk,
                disabledBackgroundColor: AppColors.bg3,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Стать исполнителем',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// .card.job — свободный заказ с гонораром и кнопкой отклика.
class _JobCard extends StatelessWidget {
  const _JobCard({
    required this.order,
    required this.canRespond,
    required this.onRespond,
  });

  final Order order;
  final bool canRespond;
  final VoidCallback onRespond;

  /// У осмотра цену назначает заказчик — показываем её. У подбора её в
  /// API нет: `price` появляется только при принятии отклика, поэтому
  /// там остаётся минимум из откликов или «предлагаете вы».
  (String, String) get _pay {
    if (order.price != null) {
      return ('Гонорар за заказ', '${money(order.price!)} ₽');
    }
    if (order.askingPrice != null) {
      return ('Цена заказчика', '${money(order.askingPrice!)} ₽');
    }
    if (order.responses.isNotEmpty) {
      final min = order.responses
          .map((r) => r.proposedPrice)
          .reduce((a, b) => a < b ? a : b);
      return ('Откликаются от', '${money(min)} ₽');
    }
    return ('Гонорар за заказ', 'предлагаете вы');
  }

  static String _responsesLabel(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return '$n отклик';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return '$n отклика';
    }
    return '$n откликов';
  }

  @override
  Widget build(BuildContext context) {
    final (payCaption, payValue) = _pay;
    // у осмотра вместо бюджета — когда и куда ехать
    final meta = order.isInspection
        ? [
            whenLabel(order.inspectOn, order.timeSlot, order.inspectTime),
            _responsesLabel(order.responses.length),
          ].join(' · ')
        : [
            if (order.budgetMax != null) 'до ${money(order.budgetMax!)} ₽',
            _responsesLabel(order.responses.length),
          ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.modeWork.withValues(alpha: 0.045),
        border: Border.all(color: AppColors.modeWork.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Pill('свободен', color: AppColors.modeWork),
              const SizedBox(width: 8),
              // в макете здесь «Химки · 8 км» — расстояний в API нет.
              // У осмотра вместо города показываем адрес выезда.
              Expanded(
                child: Text(
                  order.isInspection
                      ? (order.address ?? '')
                      : (order.cities.isNotEmpty ? order.cities.first : ''),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.sectionExtra,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(order.carTitle, style: AppText.orderCar),
          const SizedBox(height: 5),
          Text(meta, style: AppText.orderMeta),

          // .pay
          Container(
            margin: const EdgeInsets.only(top: 11),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bg0,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    payCaption,
                    style: const TextStyle(fontSize: 11, color: AppColors.text2),
                  ),
                ),
                Text(
                  payValue,
                  style: const TextStyle(
                    fontFamily: AppTheme.monoFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                    color: AppColors.modeWork,
                  ),
                ),
              ],
            ),
          ),

          // .take — в макете первая кнопка заливная, остальные ghost; это
          // приём статичной картинки, в живом списке заказы равноправны
          const SizedBox(height: 9),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canRespond ? onRespond : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.modeWork,
                foregroundColor: AppColors.modeWorkInk,
                disabledBackgroundColor: AppColors.bg3,
                disabledForegroundColor: AppColors.text3,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Откликнуться',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
