import 'package:flutter/material.dart';

import '../data/auth_service.dart';
import '../models/order.dart';
import '../state/nearby_feed_controller.dart';
import '../state/nearby_filter_store.dart';
import '../state/notification_scope.dart';
import '../state/order_store.dart';
import '../state/verification_status.dart';
import '../theme/app_colors.dart';
import '../widgets/app_ui.dart';
import '../widgets/load_more.dart';
import '../widgets/nearby_filter_sheet.dart';
import '../widgets/notification_bell.dart';
import '../widgets/order_alerts_prompt.dart';
import '../widgets/order_alerts_sheet.dart';
import '../widgets/respond_sheet.dart';
import '../widgets/resumable_inspections.dart';
import '../widgets/unread_badge.dart';
import 'nearby_orders/feed_states.dart';
import 'nearby_orders/filter_row.dart';
import 'nearby_orders/job_card.dart';
import 'nearby_orders/verification_gate.dart';
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
  /// Запрос ленты: фильтры, «Мало откликов», точка устройства.
  late final _feed = NearbyFeedController(
    widget.store,
    filters: widget.filters,
  );

  @override
  void initState() {
    super.initState();
    _feed.start();
    // кеш рисуется сразу, запрос его освежает
    widget.verification.refresh();
  }

  @override
  void dispose() {
    _feed.dispose();
    super.dispose();
  }

  /// Пока статус неизвестен, откликаться нельзя: кнопки закрыты, но
  /// плашку «нужна верификация» не рисуем — это была бы неправда.
  bool get _canRespond => widget.verification.summary?.canTakeOrders ?? false;

  Future<void> _openFilters() async {
    final store = widget.store;
    final filters = _feed.filters;
    final opened = filters.filter;
    final next = await showNearbyFilterSheet(
      context,
      current: opened,
      cityOptions: [for (final f in store.cityFacets) f.name],
      brandOptions: [for (final f in store.brandFacets) f.name],
      countFor: (f) =>
          store.countAvailableOrders(f, fewResponses: _feed.fewResponsesOnly),
      cities: store.cities,
      locator: store.locator,
      // при заходе на экран город мог не определиться — пробуем снова;
      // шторка открывается сразу и подставит его, когда придёт
      locateCity: filters.locate,
      autoCity: !filters.cityChosen,
      onReset: _feed.resetFilters,
    );
    if (next != null) filters.set(next, from: opened);
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
      suggested: _feed.filters.filter.cities,
    );
  }

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
            _feed.filters,
            _feed,
            widget.verification,
          ]),
          builder: (context, _) {
            final all = widget.store.availableAll;
            return Column(
              children: [
                DetailHead(
                  title: 'Заказы рядом',
                  eyebrow: 'свободные · $all',
                  onBack: backIfCanPop(context),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilterCountBadge(
                        count: _feed.filters.filter.activeCount,
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
                NearbyFilterRow(
                  feed: _feed,
                  all: all,
                  auth: widget.auth,
                  onOrderAlerts: _openOrderAlerts,
                ),
                // осмотр без связи: после перезапуска офлайн иначе к нему
                // не вернуться (ревью №12)
                ResumableInspections(
                  offline: widget.store.availableError != null,
                ),
                Expanded(child: _body(hiddenByFilter: all > 0)),
              ],
            );
          },
        ),
      ),
    );
  }

  /// [hiddenByFilter] — свободные заказы есть, и если список пуст, его
  /// опустошили фильтры.
  Widget _body({required bool hiddenByFilter}) {
    final store = widget.store;
    final orders = store.availableOrders;
    final error = store.availableError;
    if (error != null) {
      return NearbyFeedError(
        error: error,
        onRetry: () => store.loadAvailableOrders(),
      );
    }
    // спиннер на весь экран — только пока показывать нечего; при смене
    // фильтра прежний список стоит до ответа, сверху — полоска загрузки
    if (store.isLoadingAvailable && orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final verification = widget.verification;
    final gate = verification.summary;
    final auth = widget.auth;

    final list = RefreshIndicator(
      onRefresh: () => store.loadAvailableOrders(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 2, 22, 16),
        children: [
          // плашка — только по ответу сервера; пока грузится — ничего
          if (gate != null && !gate.canTakeOrders)
            VerificationGate(
              summary: gate,
              onTap: auth == null ? null : _openVerification,
            )
          else if (gate == null && verification.error != null)
            VerificationRetry(onRetry: verification.refresh),
          if (_feed.nearUnavailable)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Геопозиция недоступна — показаны новые заказы',
                style: TextStyle(fontSize: 12, color: context.colors.text3),
              ),
            ),
          if (orders.isEmpty)
            NearbyFeedEmpty(
              hiddenByFilter: hiddenByFilter,
              onlyAutoCity: _feed.onlyAutoCity,
              onShowAllCities: _feed.showAllCities,
              onResetFilters: _feed.resetFilters,
            ),
          for (final order in orders)
            JobCard(
              order: order,
              here: _feed.here,
              canRespond: _canRespond,
              onRespond: () => _respond(order),
            ),
          // подписка на города фильтра — под пустой лентой и в конце списка
          if (auth != null && !store.hasMoreAvailable)
            OrderAlertsPrompt(
              auth: auth,
              cities: _feed.filters.filter.cities,
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
