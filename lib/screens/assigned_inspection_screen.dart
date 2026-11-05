import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/api_inspection_repository.dart';
import '../data/auth_service.dart';
import '../models/inspection_verdict.dart';
import '../models/order.dart';
import '../models/order_status.dart';
import '../state/inspection_store.dart';
import '../state/order_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/api_error.dart';
import '../widgets/app_ui.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/deadline_countdown.dart';
import '../widgets/dispute_sheet.dart';
import '../widgets/inspection_order_parts.dart';
import '../util/route_link.dart';
import '../widgets/payment_parts.dart';
import '../widgets/route_button.dart';
import '../widgets/support_sheet.dart';
import '../widgets/verdict_sheet.dart';
import 'car_vin_screen.dart';
import 'inspection_overview_screen.dart';
import 'inspection_report_screen.dart';
import 'order_auto_refresh.dart';

/// Разовый осмотр глазами назначенного исполнителя: куда и когда ехать,
/// телефон продавца, старт осмотра по деталям и итоговый вердикт.
///
/// 24 часа с момента выбора — на осмотр или отказ. После вердикта отчёт
/// ждёт оплаты: заказчик переводит напрямую, исполнитель подтверждает
/// «Оплату получил» — с «Я оплатил» заказчика править отчёт уже нельзя.
///
/// Отдельный экран, а не ветка в [InspectionOrderDetailScreen]: у заказчика
/// там выбор исполнителя по откликам, у исполнителя — работа по заказу.
/// Тип осмотра не выбирается — всегда полный (17 пунктов).
class AssignedInspectionScreen extends StatefulWidget {
  const AssignedInspectionScreen({
    super.key,
    required this.store,
    required this.orderId,
    this.auth,
  });

  final OrderStore store;
  final int orderId;

  /// Нужен, чтобы открыть осмотр по деталям через API. Без него (в тестах)
  /// кнопки перехода к осмотру неактивны.
  final AuthService? auth;

  @override
  State<AssignedInspectionScreen> createState() =>
      _AssignedInspectionScreenState();
}

class _AssignedInspectionScreenState extends State<AssignedInspectionScreen>
    with OrderAutoRefresh<AssignedInspectionScreen> {
  Order? _order;
  bool _loading = true;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await widget.store.fetchOrder(widget.orderId);
      if (mounted) setState(() => _order = order);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  bool get refreshPaused => _loading || _busy;

  /// Тихое перечитывание (OrderAutoRefresh): без спиннера, ошибку бросает.
  @override
  Future<void> refreshOrder() async {
    final before = _order;
    final order = await widget.store.fetchOrder(widget.orderId);
    // пока ждали, заказ подменило действие — его ответ свежее
    if (!mounted || refreshPaused || !identical(_order, before)) return;
    setState(() {
      _order = order;
      _error = null;
    });
    widget.store.replaceOrder(order);
  }

  /// Ошибки действий — SnackBar'ом, экран при этом остаётся рабочим.
  /// После отказа сервера перечитываем заказ: «Срок осмотра истёк» и
  /// похожие 422 значат, что статус уже не тот, что на экране.
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        showApiError(context, e);
        await _load();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline(Order order) async {
    final ok = await showConfirmSheet(
      context,
      title: 'Отказаться от заказа?',
      text:
          'Заказ вернётся к другим исполнителям, повторно откликнуться на '
          'него не получится. Начатый осмотр будет удалён из вашего списка.',
      confirmLabel: 'Отказаться',
    );
    if (!ok || !mounted) return;
    final navigator = Navigator.of(context);
    var done = false;
    await _run(() async {
      await widget.store.declineOrder(order.id);
      done = true;
    });
    // заказ больше не наш — экран закрываем
    if (done && mounted) navigator.pop();
  }

  Future<void> _confirmPayment(Order order) async {
    final ok = await showConfirmSheet(
      context,
      title: 'Оплата пришла?',
      text:
          'Проверьте поступление ${order.price == null ? '' : '${money(order.price!)} ₽ '}'
          'в банке. После подтверждения заказчик получит полный отчёт.',
      confirmLabel: 'Да, оплату получил',
    );
    if (!ok || !mounted) return;
    await _run(() async {
      final updated = await widget.store.confirmPayment(order.id);
      if (mounted) setState(() => _order = updated);
    });
  }

  Future<void> _openDispute(Order order) {
    return showDisputeSheet(
      context,
      onSubmit: (reason) async {
        final updated = await widget.store.openDispute(
          order.id,
          reason: reason,
        );
        if (mounted) setState(() => _order = updated);
      },
    );
  }

  /// Осмотр начинается с таблички VIN (`CarVinScreen`): бекенд записывает
  /// снятый VIN, создаёт осмотр со всеми пунктами и переводит заказ в «на
  /// осмотре»; сразу открываем осмотр, чтобы не искать его вторым нажатием.
  Future<void> _start(Order order) async {
    final inspectionId = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) =>
            CarVinScreen(repository: widget.store.repository, order: order),
      ),
    );
    if (!mounted) return;
    // и при отказе («Срок осмотра истёк») статус мог уйти — перечитываем
    await _load();
    if (mounted && inspectionId != null && widget.auth != null) {
      await _openInspection(inspectionId);
    }
  }

  /// «Отправить отчёт клиенту» в сводке осмотра закрывает осмотр до этого
  /// экрана и открывает шторку вердикта: отчёт заказчику — это и есть вердикт.
  Future<void> _openInspection(int inspectionId) async {
    final repo = ApiInspectionRepository(
      ApiClient(widget.auth!),
      inspectionId: inspectionId,
    );
    // стор — до маршрута: builder перезапускается при смене темы
    final store = InspectionStore(repo);
    final navigator = Navigator.of(context);
    final ownRoute = ModalRoute.of(context);
    var sendReport = false;
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => InspectionOverviewScreen(
          store: store,
          onSendReport: () {
            sendReport = true;
            navigator.popUntil((route) => route == ownRoute);
          },
        ),
      ),
    );
    await _load();
    final order = _order;
    if (sendReport && mounted && order?.status == OrderStatus.inspecting) {
      await _complete(order!);
    }
  }

  Future<void> _complete(Order order) async {
    final result = await showModalBottomSheet<(InspectionVerdict, String?)>(
      context: context,
      backgroundColor: context.colors.bg0,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => VerdictSheet(order: order),
    );
    if (result == null || !mounted) return;
    await _run(() async {
      final updated = await widget.store.completeInspection(
        order.id,
        verdict: result.$1,
        comment: result.$2,
      );
      if (mounted) setState(() => _order = updated);
    });
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            DetailHead(
              title: order?.carTitle ?? 'Осмотр',
              eyebrow: 'осмотр #${widget.orderId}',
              onBack: () => Navigator.of(context).pop(),
              trailing: order == null
                  ? null
                  : Pill(
                      order.status.labelFor(order.kind),
                      color: order.status.pillColor(context.colors),
                    ),
            ),
            Expanded(child: _body(order)),
            if (order != null && !_loading) ..._actions(order),
          ],
        ),
      ),
    );
  }

  Widget _body(Order? order) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Не удалось загрузить заказ',
              style: TextStyle(fontSize: 14, color: context.colors.text1),
            ),
            const SizedBox(height: 6),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: context.colors.text3),
            ),
            const SizedBox(height: 10),
            CtaGhost(label: 'Повторить', onPressed: _load),
          ],
        ),
      );
    }

    if (_loading || order == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: pullToRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
        children: [
          InspectionOrderSummary(
            order: order,
            // гонорар — цена из принятого отклика; до принятия её нет
            priceLabel: 'Ваш гонорар',
            price: order.price ?? order.askingPrice,
          ),
          // до осмотра и во время него — путь до машины во внешнем навигаторе
          if ((order.status == OrderStatus.scheduled ||
                  order.status == OrderStatus.inspecting) &&
              routeLinks(order).isNotEmpty) ...[
            const SizedBox(height: 10),
            RouteButton(order: order),
          ],
          if (order.executorDeadlineAt != null &&
              (order.status == OrderStatus.scheduled ||
                  order.status == OrderStatus.inspecting)) ...[
            const SizedBox(height: 10),
            DeadlineCountdown(deadline: order.executorDeadlineAt!),
          ],
          ..._payment(order),
          if (order.verdict != null) ...[
            const SizedBox(height: 22),
            const SectionHead('Итог осмотра'),
            InspectionVerdictBox.forOrder(order),
            if (widget.auth != null && hasInspectionReport(order)) ...[
              const SizedBox(height: 8),
              CtaGhost(
                label: 'Полный отчёт',
                onPressed: () =>
                    openInspectionReport(context, widget.auth!, order),
              ),
            ],
          ],
          const SizedBox(height: 22),
          const SectionHead('Заказчик'),
          _CustomerBox(order: order),
        ],
      ),
    );
  }

  /// Отчёт готов: ждём оплату, подтверждаем её или разбираемся в споре.
  List<Widget> _payment(Order order) {
    final price = order.price == null ? '' : ' ${money(order.price!)} ₽';
    return switch (order.status) {
      OrderStatus.reportReady => [
        const SizedBox(height: 22),
        const SectionHead('Оплата'),
        StatusNote(
          text:
              'Отчёт отправлен. Ждём оплату от заказчика:$price. Изменить '
              'отчёт уже нельзя — заказчик платит за то, что видел.',
        ),
        DisputeWindowNote(order: order, ifSilent: 'заказчик так и не оплатит'),
      ],
      OrderStatus.paymentSent => [
        const SizedBox(height: 22),
        const SectionHead('Оплата'),
        StatusNote(
          icon: Icons.payments_outlined,
          text:
              'Заказчик отметил оплату$price. Проверьте поступление и '
              'подтвердите — тогда он получит отчёт.',
        ),
      ],
      OrderStatus.disputed => [
        const SizedBox(height: 22),
        const SectionHead('Спор'),
        DisputeBox(order: order, viewerId: order.executor?.id),
      ],
      _ => const [],
    };
  }

  /// Кнопки внизу по статусу: назначен → начать, на осмотре → продолжить,
  /// отчёт готов → ждать оплату (отчёт заморожен, смотреть — «Полный
  /// отчёт»), оплачен → подтвердить. Отчёт с вердиктом
  /// отправляется только из сводки осмотра, когда оценены все пункты.
  /// Отказаться можно до готовности отчёта.
  List<Widget> _actions(Order order) {
    final inspectionId = order.cars.isEmpty
        ? null
        : order.cars.first.inspectionId;
    final canOpen = widget.auth != null && !_busy;

    return switch (order.status) {
      OrderStatus.scheduled when order.cars.isNotEmpty => [
        BottomCta(
          children: [
            CtaPrimary(
              label: 'Начать осмотр',
              icon: Icons.play_arrow_rounded,
              loading: _busy,
              onPressed: () => _start(order),
            ),
            CtaGhost(
              label: 'Отказаться от заказа',
              onPressed: _busy ? null : () => _decline(order),
            ),
          ],
        ),
      ],
      OrderStatus.inspecting => [
        BottomCta(
          children: [
            CtaPrimary(
              label: 'Продолжить осмотр',
              onPressed: canOpen && inspectionId != null
                  ? () => _openInspection(inspectionId)
                  : null,
            ),
            CtaGhost(
              label: 'Отказаться от заказа',
              onPressed: _busy ? null : () => _decline(order),
            ),
          ],
        ),
      ],
      // спор — только когда сервер открыл окно (сутки без оплаты);
      // до того срок виден в подсказке над кнопками
      OrderStatus.reportReady when order.canDispute => [
        BottomCta(
          children: [
            CtaGhost(
              label: 'Заказчик не платит — открыть спор',
              onPressed: _busy ? null : () => _openDispute(order),
            ),
          ],
        ),
      ],
      OrderStatus.paymentSent => [
        BottomCta(
          children: [
            CtaPrimary(
              label: 'Оплату получил',
              icon: Icons.check_rounded,
              loading: _busy,
              onPressed: () => _confirmPayment(order),
            ),
            // «деньги не пришли» — не спор: не подтверждаем и пишем в
            // поддержку, через сутки спор откроется заказчику
            CtaGhost(
              label: 'Деньги не пришли — написать в поддержку',
              onPressed: _busy ? null : () => showSupportSheet(context),
            ),
          ],
        ),
      ],
      _ => const [],
    };
  }
}

/// Заказчик и телефон продавца — телефон бекенд отдаёт только заказчику
/// и выбранному исполнителю.
class _CustomerBox extends StatelessWidget {
  const _CustomerBox({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    final phone = order.sellerPhone;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: context.colors.bg1,
        border: Border.all(color: context.colors.line),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Avatar(initialsOf(order.customer.name), size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  order.customer.name,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.colors.text1,
                  ),
                ),
              ),
            ],
          ),
          if (phone != null && phone.isNotEmpty) ...[
            const SizedBox(height: 11),
            Container(height: 1, color: context.colors.line),
            const SizedBox(height: 11),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Телефон продавца',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: context.colors.text2,
                    ),
                  ),
                ),
                Text(
                  phone,
                  style: TextStyle(
                    fontFamily: AppTheme.monoFamily,
                    fontSize: 13,
                    color: context.colors.text1,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
