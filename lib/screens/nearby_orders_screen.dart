import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../data/verification_repository.dart';
import '../models/nearby_filter.dart';
import '../models/order.dart';
import '../models/order_kind.dart';
import '../state/nearby_filter_store.dart';
import '../state/order_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../util/ru_date.dart';
import '../widgets/app_ui.dart';
import '../widgets/nearby_filter_sheet.dart';
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
    this.onProfile,
    this.filters,
  });

  final OrderStore store;
  final VerificationRepository verification;

  /// Нужен только экрану верификации, на который ведёт гейт.
  final AuthService? auth;

  /// Иконка профиля в шапке. null — иконки нет.
  final VoidCallback? onProfile;

  /// Фильтры шторки. null — свои, без сохранения между запусками.
  final NearbyFilterStore? filters;

  @override
  State<NearbyOrdersScreen> createState() => _NearbyOrdersScreenState();
}

class _NearbyOrdersScreenState extends State<NearbyOrdersScreen> {
  VerificationSummary? _verification;

  /// true — показываем только заказы с малым числом откликов.
  bool _fewResponsesOnly = false;

  late final NearbyFilterStore _filters = widget.filters ?? NearbyFilterStore();

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

  bool get _canRespond => _verification?.canTakeOrders ?? false;

  List<Order> _visible(List<Order> orders, NearbyFilter filter) {
    final filtered = applyNearbyFilter(orders, filter);
    return _fewResponsesOnly
        ? filtered.where((o) => o.responsesCount <= 2).toList()
        : filtered;
  }

  Future<void> _openFilters() async {
    final all = widget.store.availableOrders;
    final next = await showNearbyFilterSheet(
      context,
      current: _filters.filter,
      orders: all,
      countFor: (f) => _visible(all, f).length,
      cities: widget.store.cities,
    );
    if (next != null) _filters.set(next);
  }

  void _resetFilters() {
    setState(() => _fewResponsesOnly = false);
    _filters.set(NearbyFilter(sort: _filters.filter.sort));
  }

  /// Включённые фильтры шторки — чипами с крестиком под шапкой, чтобы было
  /// видно, почему список короткий. Тап снимает фильтр.
  List<(String, NearbyFilter)> _activeChips(NearbyFilter f) => [
    if (f.kind != null)
      (
        f.kind!.isInspection ? 'Осмотр' : 'Подбор',
        f.copyWith(kind: () => null),
      ),
    for (final city in f.cities)
      (city, f.copyWith(cities: {...f.cities}..remove(city))),
    if (f.when != NearbyWhen.any)
      (f.when.label, f.copyWith(when: NearbyWhen.any)),
    if (f.minPrice != null)
      ('от ${money(f.minPrice!)} ₽', f.copyWith(minPrice: () => null)),
    for (final brand in f.brands)
      (brand, f.copyWith(brands: {...f.brands}..remove(brand))),
  ];

  Future<void> _respond(Order order) async {
    final auth = widget.auth;
    // разовый осмотр оплачивается напрямую — без реквизитов сервер вернёт 422
    final requiresPayout = order.isInspection && auth?.user != null && auth!.user!.payout == null;
    final sent = await showRespondSheet(
      context,
      order: order,
      requiresPayout: requiresPayout,
      onSubmit: (price, message, payout) async {
        await widget.store.respondToOrder(
          order.id,
          proposedPrice: price,
          message: message,
          payout: payout,
        );
        // реквизиты легли в профиль — подтягиваем, чтобы больше не спрашивать
        if (payout != null) await auth?.refreshUser();
      },
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Отклик отправлен')));
    }
  }

  void _openVerification() {
    final auth = widget.auth;
    if (auth == null) return;
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => VerificationScreen(auth: auth)));
  }

  void _openMap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AvailableOrdersScreen(store: widget.store),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([widget.store, _filters]),
          builder: (context, _) {
            final all = widget.store.availableOrders;
            final filter = _filters.filter;
            final orders = _visible(all, filter);

            return Column(
              children: [
                DetailHead(
                  title: 'Заказы рядом',
                  eyebrow: 'свободные · ${all.length}',
                  onBack: Navigator.of(context).canPop()
                      ? () => Navigator.of(context).pop()
                      : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _BadgeIcon(
                        count: filter.activeCount,
                        child: SquareIconButton(
                          icon: Icons.tune,
                          onTap: _openFilters,
                        ),
                      ),
                      if (widget.onProfile != null) ...[
                        const SizedBox(width: 8),
                        SquareIconButton(
                          icon: Icons.person_outline,
                          onTap: widget.onProfile!,
                        ),
                      ],
                    ],
                  ),
                ),

                // .filter-row — быстрые фильтры и включённые из шторки.
                // Align — иначе короткий ряд встаёт по центру колонки
                Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                    child: Row(
                      children: [
                        AppChip(
                          label: 'Все · ${all.length}',
                          on: !_fewResponsesOnly,
                          activeColor: context.colors.modeWork,
                          onTap: () =>
                              setState(() => _fewResponsesOnly = false),
                        ),
                        const SizedBox(width: 6),
                        AppChip(
                          label: 'Мало откликов',
                          on: _fewResponsesOnly,
                          activeColor: context.colors.modeWork,
                          onTap: () => setState(() => _fewResponsesOnly = true),
                        ),
                        for (final (label, without) in _activeChips(
                          filter,
                        )) ...[
                          const SizedBox(width: 6),
                          AppChip(
                            label: '$label  ✕',
                            on: true,
                            activeColor: context.colors.modeWork,
                            onTap: () => _filters.set(without),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                Expanded(child: _body(orders, hiddenByFilter: all.isNotEmpty)),

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

  /// [hiddenByFilter] — заказы есть, и если список пуст, его опустошили
  /// фильтры, а не сервер.
  Widget _body(List<Order> orders, {required bool hiddenByFilter}) {
    final error = widget.store.availableError;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Не удалось загрузить заказы',
              style: TextStyle(fontSize: 14, color: context.colors.text1),
            ),
            const SizedBox(height: 6),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: context.colors.text3),
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
    final showGate = gate == null || !gate.canTakeOrders;

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
          if (orders.isEmpty && hiddenByFilter)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Column(
                children: [
                  Text(
                    'Под фильтр ничего не подошло',
                    style: TextStyle(fontSize: 13, color: context.colors.text2),
                  ),
                  const SizedBox(height: 6),
                  CtaGhost(label: 'Сбросить фильтры', onPressed: _resetFilters),
                ],
              ),
            )
          else if (orders.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(
                child: Text(
                  'Свободных заказов сейчас нет',
                  style: TextStyle(fontSize: 13, color: context.colors.text2),
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

/// .gate — шлагбаум верификации. Клиентский; сервер проверяет её при
/// отклике, только если включён EXECUTOR_VERIFICATION_REQUIRED, а на
/// экране карты кнопка «Откликнуться» гейтом не гасится.
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
        color: context.colors.bg1,
        border: Border.all(
          color: context.colors.modeWork.withValues(alpha: 0.35),
        ),
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
                  color: context.colors.modeWork.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.lock_outline,
                  size: 17,
                  color: context.colors.modeWork,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Смотреть можно, откликаться — нет',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.14,
                        color: context.colors.text1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary == null
                          ? 'Нужна верификация: вход, опыт, тест на дефекты · ~20 минут'
                          : 'Нужна верификация: пройдено ${summary!.passed} из '
                                '${summary!.total} шагов · ~20 минут',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.colors.text2,
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
              backgroundColor: context.colors.bg0,
              valueColor: AlwaysStoppedAnimation(context.colors.modeWork),
            ),
          ),
          const SizedBox(height: 11),
          // .gate-btn
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.modeWork,
                foregroundColor: context.colors.modeWorkInk,
                disabledBackgroundColor: context.colors.bg3,
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
  /// там остаётся свой отклик или «предлагаете вы». Чужие цены сервер
  /// исполнителю не отдаёт — минимум по ним не посчитать.
  (String, String) get _pay {
    if (order.price != null) {
      return ('Гонорар за заказ', '${money(order.price!)} ₽');
    }
    if (order.askingPrice != null) {
      return ('Цена заказчика', '${money(order.askingPrice!)} ₽');
    }
    if (order.responses.isNotEmpty) {
      return ('Ваш отклик', '${money(order.responses.first.proposedPrice)} ₽');
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
            _responsesLabel(order.responsesCount),
          ].join(' · ')
        : [
            if (order.budgetMax != null) 'до ${money(order.budgetMax!)} ₽',
            _responsesLabel(order.responsesCount),
          ].join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colors.modeWork.withValues(alpha: 0.045),
        border: Border.all(
          color: context.colors.modeWork.withValues(alpha: 0.35),
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Pill('свободен', color: context.colors.modeWork),
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
                  style: context.text.sectionExtra,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(order.carTitle, style: context.text.orderCar),
          const SizedBox(height: 5),
          Text(meta, style: context.text.orderMeta),

          // .pay
          Container(
            margin: const EdgeInsets.only(top: 11),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.colors.bg0,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    payCaption,
                    style: TextStyle(fontSize: 11, color: context.colors.text2),
                  ),
                ),
                Text(
                  payValue,
                  style: TextStyle(
                    fontFamily: AppTheme.monoFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                    color: context.colors.modeWork,
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
              onPressed: canRespond && !order.hasViewerResponse ? onRespond : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.modeWork,
                foregroundColor: context.colors.modeWorkInk,
                disabledBackgroundColor: context.colors.bg3,
                disabledForegroundColor: context.colors.text3,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
                elevation: 0,
              ),
              child: Text(
                order.hasViewerResponse ? 'Вы откликнулись' : 'Откликнуться',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Число включённых фильтров поверх кнопки шапки. 0 — без бейджа.
class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({required this.count, required this.child});

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
