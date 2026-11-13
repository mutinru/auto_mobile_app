import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../data/verification_repository.dart';
import '../models/nearby_filter.dart';
import '../models/order.dart';
import '../models/order_kind.dart';
import '../state/nearby_filter_store.dart';
import '../state/notification_scope.dart';
import '../state/order_store.dart';
import '../state/verification_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../util/geo.dart';
import '../util/money.dart';
import '../util/ru_date.dart';
import '../widgets/resumable_inspections.dart';
import '../widgets/app_ui.dart';
import '../widgets/load_more.dart';
import '../widgets/nearby_filter_sheet.dart';
import '../widgets/notification_bell.dart';
import '../widgets/order_alerts_prompt.dart';
import '../widgets/order_alerts_sheet.dart';
import '../widgets/respond_sheet.dart';
import '../widgets/unread_badge.dart';
import 'notifications_screen.dart';
import 'verification_screen.dart';

/// Экран 03 макета car-storefront-modes.html — «Беру заказы»: список
/// свободных заказов с гейтом верификации. Кнопку «Показать на карте»
/// (экран 04, available_orders_screen.dart) пока спрятали: карта там
/// декоративная, настоящую не делаем.
///
/// Чего нет и что не переносится из макета: расстояние только у осмотра
/// (у подбора координат нет — показываем город), радиус поиска, фильтры
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

  /// Статус верификации на всю сессию: повторный вход рисует его сразу.
  final VerificationStatus verification;

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
  /// true — показываем только заказы с малым числом откликов.
  bool _fewResponsesOnly = false;

  late final NearbyFilterStore _filters = widget.filters ?? NearbyFilterStore();

  /// Точка устройства для «· 8 км»; null — без геопозиции, только город.
  (double, double)? _here;

  /// Параметры последнего запроса ленты: стор фильтров уведомляет и без
  /// смены фильтра (загрузка из хранилища, город по GPS) — лишний запрос
  /// не шлём.
  String? _lastQuery;

  @override
  void initState() {
    super.initState();
    _filters.addListener(_reload);
    _reload();
    // кеш рисуется сразу, запрос его освежает
    widget.verification.refresh();
    _locate();
  }

  @override
  void dispose() {
    _filters.removeListener(_reload);
    super.dispose();
  }

  /// «Ближе ко мне», а геопозиции нет — лента пришла «новыми», об этом
  /// строка над списком.
  bool _nearUnavailable = false;

  /// Номер последнего [_reload]: пока он ждал геопозицию, мог начаться
  /// следующий — устаревший не шлёт запрос.
  int _reloadToken = 0;

  /// Фильтрует и листает сервер: сменился фильтр — первая страница заново.
  /// «Ближе ко мне» — с точкой устройства: удачу локатор кеширует, ждём её
  /// только в первый раз.
  Future<void> _reload() async {
    final token = ++_reloadToken;
    var filter = _filters.filter;
    final nearest = filter.sort == NearbySort.nearest;
    if (nearest) {
      final here = _here ?? await widget.store.locator?.position();
      if (!mounted || token != _reloadToken) return;
      if (here != null) _here = here;
      filter = filter.copyWith(near: () => here);
    }
    final unavailable = nearest && filter.near == null;
    if (unavailable != _nearUnavailable) {
      setState(() => _nearUnavailable = unavailable);
    }
    final query = filter.toQuery(fewResponses: _fewResponsesOnly);
    if (query == _lastQuery) return;
    _lastQuery = query;
    widget.store.loadAvailableOrders(
      filter: filter,
      fewResponses: _fewResponsesOnly,
    );
  }

  void _setFewResponses(bool value) {
    setState(() => _fewResponsesOnly = value);
    _reload();
  }

  Future<void> _locate() async {
    final here = await widget.store.locator?.position();
    if (here != null && mounted) setState(() => _here = here);
  }

  /// Пока статус неизвестен, откликаться нельзя: кнопки закрыты, но
  /// плашку «нужна верификация» не рисуем — это была бы неправда.
  bool get _canRespond => widget.verification.summary?.canTakeOrders ?? false;

  Future<void> _openFilters() async {
    final store = widget.store;
    final opened = _filters.filter;
    final next = await showNearbyFilterSheet(
      context,
      current: opened,
      cityOptions: [for (final f in store.cityFacets) f.name],
      brandOptions: [for (final f in store.brandFacets) f.name],
      countFor: (f) =>
          store.countAvailableOrders(f, fewResponses: _fewResponsesOnly),
      cities: store.cities,
      locator: store.locator,
      // при заходе на экран город мог не определиться — пробуем снова;
      // шторка открывается сразу и подставит его, когда придёт
      locateCity: _filters.locate,
      autoCity: !_filters.cityChosen,
      onReset: _resetFilters,
    );
    if (next != null) _filters.set(next, from: opened);
  }

  /// Шторка подписки на новые заказы — с чипа и из карточки под лентой.
  /// Новую подписку начинаем с городов фильтра: обычно они и нужны.
  void _openOrderAlerts() {
    final auth = widget.auth;
    if (auth == null) return;
    showOrderAlertsSheet(
      context,
      auth: auth,
      cities: widget.store.cities,
      locator: widget.store.locator,
      suggested: _filters.filter.cities,
    );
  }

  /// Город по GPS, если ленту опустошил только он, — тогда пустая лента
  /// объясняется городом и предлагает все города, а не «сбросить фильтры».
  String? get _onlyAutoCity {
    final f = _filters.filter;
    if (!_filters.isAutoCity || _fewResponsesOnly) return null;
    if (f.cities.length != 1 || f.activeCount != 1) return null;
    return f.cities.first;
  }

  void _resetFilters() {
    setState(() => _fewResponsesOnly = false);
    _filters.set(
      NearbyFilter(sort: _filters.filter.sort, cities: _filters.gpsCities),
    );
    // фильтр шторки мог и не измениться — «Мало откликов» тоже сброшено
    _reload();
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
    final requiresPayout =
        order.isInspection && auth?.user != null && auth!.user!.payout == null;
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Отклик отправлен')));
    }
  }

  /// С экрана верификации могли вернуться пройдя шаги — перечитываем.
  Future<void> _openVerification() async {
    final auth = widget.auth;
    if (auth == null) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => VerificationScreen(auth: auth)));
    widget.verification.refresh();
  }

  /// Уведомление могло увести в заказ — ленту свободных перечитываем.
  Future<void> _openNotifications() async {
    await openNotifications(context, store: widget.store, auth: widget.auth);
    if (mounted) widget.store.loadAvailableOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([
            widget.store,
            _filters,
            widget.verification,
          ]),
          builder: (context, _) {
            final all = widget.store.availableAll;
            final filter = _filters.filter;
            final orders = widget.store.availableOrders;

            return Column(
              children: [
                DetailHead(
                  title: 'Заказы рядом',
                  eyebrow: 'свободные · $all',
                  onBack: backIfCanPop(context),
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
                      if (NotificationScope.maybeOf(context) != null) ...[
                        const SizedBox(width: 8),
                        NotificationBell(onTap: _openNotifications),
                      ],
                      if (widget.onProfile != null) ...[
                        const SizedBox(width: 8),
                        SupportUnreadBadge(
                          child: SquareIconButton(
                            icon: Icons.person_outline,
                            onTap: widget.onProfile!,
                          ),
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
                          label: 'Все · $all',
                          on: !_fewResponsesOnly,
                          activeColor: context.colors.modeWork,
                          onTap: () => _setFewResponses(false),
                        ),
                        const SizedBox(width: 6),
                        AppChip(
                          label: 'Мало откликов',
                          on: _fewResponsesOnly,
                          activeColor: context.colors.modeWork,
                          onTap: () => _setFewResponses(true),
                        ),
                        // подписка на новые заказы — всегда на виду
                        if (widget.auth != null)
                          ListenableBuilder(
                            listenable: widget.auth!,
                            builder: (context, _) {
                              final alerts = widget.auth!.user?.orderAlerts;
                              if (alerts == null) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: AppChip(
                                  key: const ValueKey('order-alerts-chip'),
                                  label: alerts.isOn
                                      ? 'Уведомления'
                                      : 'Сообщать о новых',
                                  icon: alerts.isOn
                                      ? Icons.notifications_active_outlined
                                      : Icons.notifications_none,
                                  on: alerts.isOn,
                                  activeColor: context.colors.modeWork,
                                  onTap: _openOrderAlerts,
                                ),
                              );
                            },
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

                // осмотр без связи: после перезапуска офлайн иначе к нему
                // не вернуться (ревью №12)
                ResumableInspections(
                  offline: widget.store.availableError != null,
                ),
                Expanded(child: _body(orders, hiddenByFilter: all > 0)),
              ],
            );
          },
        ),
      ),
    );
  }

  /// [hiddenByFilter] — свободные заказы есть, и если список пуст, его
  /// опустошили фильтры.
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

    final store = widget.store;
    // спиннер на весь экран — только пока показывать нечего; при смене
    // фильтра прежний список стоит до ответа, сверху — полоска загрузки
    if (store.isLoadingAvailable && orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final verification = widget.verification;
    final gate = verification.summary;

    final list = RefreshIndicator(
      onRefresh: () => store.loadAvailableOrders(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 2, 22, 16),
        children: [
          // плашка — только по ответу сервера; пока грузится — ничего
          if (gate != null && !gate.canTakeOrders)
            _VerificationGate(
              summary: gate,
              onTap: widget.auth == null ? null : _openVerification,
            )
          else if (gate == null && verification.error != null)
            _VerificationRetry(onRetry: verification.refresh),
          if (_nearUnavailable)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Геопозиция недоступна — показаны новые заказы',
                style: TextStyle(fontSize: 12, color: context.colors.text3),
              ),
            ),
          if (orders.isEmpty && hiddenByFilter && _onlyAutoCity != null)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Column(
                children: [
                  Text(
                    'В городе $_onlyAutoCity свободных заказов нет',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: context.colors.text2),
                  ),
                  const SizedBox(height: 6),
                  CtaGhost(
                    label: 'Показать все города',
                    onPressed: () => _filters.set(
                      _filters.filter.copyWith(cities: const {}),
                    ),
                  ),
                ],
              ),
            )
          else if (orders.isEmpty && hiddenByFilter)
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
              here: _here,
              canRespond: _canRespond,
              onRespond: () => _respond(order),
            ),
          // подписка на города фильтра — под пустой лентой и в конце списка
          if (widget.auth != null && !store.hasMoreAvailable)
            OrderAlertsPrompt(
              auth: widget.auth!,
              cities: _filters.filter.cities,
              emptyFeed: orders.isEmpty,
              onConfigure: _openOrderAlerts,
            ),
          if (store.hasMoreAvailable)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: store.availableMoreError != null
                    ? CtaGhost(
                        label: 'Повторить',
                        onPressed: store.loadMoreAvailable,
                      )
                    : LoadMore(
                        // новый ключ на каждую страницу — иначе State
                        // переиспользуется и initState больше не позовётся
                        key: ValueKey(store.availableVersion),
                        onShown: store.loadMoreAvailable,
                      ),
              ),
            ),
        ],
      ),
    );

    if (!store.isLoadingAvailable) return list;
    return Stack(
      children: [
        list,
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: LinearProgressIndicator(minHeight: 2),
        ),
      ],
    );
  }
}

/// .gate — шлагбаум верификации. Клиентский; сервер проверяет её при
/// отклике, только если включён EXECUTOR_VERIFICATION_REQUIRED, а на
/// экране карты кнопка «Откликнуться» гейтом не гасится.
class _VerificationGate extends StatelessWidget {
  const _VerificationGate({required this.summary, required this.onTap});

  final VerificationSummary summary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final progress = summary.progress;

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
                  color: context.colors.progressText,
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
                      'Нужна верификация: пройдено ${summary.passed} из '
                      '${summary.total} шагов · ~20 минут',
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

/// Статус верификации не загрузился: без него откликаться нельзя, но и
/// говорить «нужна верификация» верифицированному — неправда.
class _VerificationRetry extends StatelessWidget {
  const _VerificationRetry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 16, color: context.colors.text3),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Не удалось проверить верификацию',
              style: TextStyle(fontSize: 12.5, color: context.colors.text2),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Повторить')),
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
    this.here,
  });

  final Order order;
  final (double, double)? here;
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
    if (order.hasViewerResponse) {
      return ('Ваш отклик', '${money(order.viewerResponse!.proposedPrice)} ₽');
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

  String get _place {
    final (lat, lon, at) = (order.lat, order.lon, here);
    return [
      if (order.cities.isNotEmpty) order.cities.first,
      if (lat != null && lon != null && at != null)
        distanceLabel(distanceKm(at.$1, at.$2, lat, lon)),
    ].join(' · ');
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
            ?budgetShort(order.budgetMin, order.budgetMax),
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
              // «Химки · 8 км» из макета; у подбора точки нет — только город.
              // Улицу сервер до выбора исполнителя не отдаёт.
              Expanded(
                child: Text(
                  _place,
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
                    color: context.colors.progressText,
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
              onPressed: canRespond && order.canViewerRespond
                  ? onRespond
                  : null,
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
                order.respondLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
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
