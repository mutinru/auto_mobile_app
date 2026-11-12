import 'dart:async';

import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/api_inspection_repository.dart';
import '../data/auth_service.dart';
import '../data/inspection_repository.dart';
import '../models/inspection_verdict.dart';
import '../models/order.dart';
import '../models/order_action.dart';
import '../models/order_car.dart';
import '../models/user_summary.dart';
import '../state/inspection_outbox.dart';
import '../state/inspection_store.dart';
import '../state/order_detail_controller.dart';
import '../state/order_store.dart';
import '../theme/app_colors.dart';
import '../widgets/api_error.dart';
import '../widgets/app_ui.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/executor_box.dart';
import '../widgets/library_sheet.dart';
import '../widgets/order_review_section.dart';
import '../widgets/purchase_sheet.dart';
import '../widgets/review_sheet.dart';
import '../widgets/seller_phone_sheet.dart';
import '../widgets/verdict_sheet.dart';
import 'auto_refresh.dart';
import 'executor_reviews_screen.dart';
import 'inspection_overview_screen.dart';
import 'inspection_report_screen.dart';
import 'order_detail/candidates_section.dart';
import 'order_detail/customer_box.dart';
import 'order_detail/executor_actions_section.dart';
import 'order_detail/purchase_section.dart';
import 'order_detail/responses_section.dart';
import 'order_detail/selection_summary.dart';
import 'start_inspection_screen.dart';

/// Карточка подбора (ревью №16): оболочка — шапка, опрос, ошибка, порядок
/// секций и шторки. Состояние и действия — [OrderDetailController], секции —
/// `order_detail/`. Кнопки — только по `Order.actions` с сервера.
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.store,
    required this.orderId,
    required this.viewerIsCustomer,
    this.auth,
    this.inspectionRepository,
  });

  final OrderStore store;
  final int orderId;

  /// Экран открыт из "Мои заказы" (customer может принимать отклики) или
  /// из "Заказы рядом"/после отклика (executor, только на просмотр).
  final bool viewerIsCustomer;

  /// Нужен, чтобы открыть осмотр кандидата (ApiInspectionRepository).
  final AuthService? auth;

  /// Репозиторий осмотра кандидата по его id; по умолчанию — API через
  /// [auth]. Тесты подставляют мок.
  final InspectionRepository Function(int inspectionId)? inspectionRepository;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen>
    with AutoRefresh<OrderDetailScreen> {
  late final _c = OrderDetailController(
    widget.store,
    orderId: widget.orderId,
    viewerIsCustomerHint: widget.viewerIsCustomer,
  )..addListener(_changed);

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _c.load();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  bool get refreshPaused => _c.busy;

  /// Тихое перечитывание (AutoRefresh): без спиннера, ошибку бросает.
  @override
  Future<void> refresh() => _c.refresh();

  /// Действие контроллера: ошибку — снекбаром, успех — [done], если задан.
  Future<bool> _run(Future<void> Function() action, {String? done}) async {
    try {
      await action();
      if (done != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(done)));
      }
      return true;
    } catch (e) {
      if (mounted) showApiError(context, e);
      return false;
    }
  }

  /// Свой готовый осмотр — кандидатом: выбор, подтверждение «ещё
  /// продаётся», запрос. Отчёт не открываем — он заморожен и исполнителю
  /// знаком.
  Future<void> _attachFromLibrary() async {
    final library = _c.library;
    if (library == null || _c.attaching) return;
    final picked = await pickFromLibrary(context, library);
    if (picked == null || !mounted) return;
    await _run(
      () => _c.attachFromLibrary(picked.inspectionId),
      done: 'Кандидат добавлен',
    );
  }

  /// Открыть осмотр кандидата можно, если есть откуда его грузить.
  bool get _canOpenInspection =>
      widget.auth != null || widget.inspectionRepository != null;

  InspectionRepository _inspectionRepo(int inspectionId) =>
      widget.inspectionRepository?.call(inspectionId) ??
      ApiInspectionRepository(
        ApiClient(widget.auth!),
        inspectionId: inspectionId,
      );

  Future<void> _openInspection(OrderCar car) async {
    final repo = _inspectionRepo(car.inspectionId!);
    // править кандидата может только исполнитель; заказчик смотрит —
    // сервер ему запись всё равно не разрешит (403)
    final order = _c.order;
    final isExecutor =
        order?.executor != null && order!.executor!.id == widget.auth?.user?.id;
    // осмотренный кандидат — отчёт, а не рабочая схема, и у заказчика, и
    // у исполнителя: после вердикта отчёт заморожен (сервер правку не
    // примет), итог с комментарием, балл, VIN, пробег по одометру
    if (car.inspectionStatus == 'completed') {
      await openCandidateReport(context, InspectionStore(repo), car);
      return;
    }
    // сюда доходит только идущий осмотр — исполнитель его и завершает
    final canFinish = isExecutor;
    // стор — до маршрута: builder перезапускается при смене темы
    // очередь осмотра — общая на приложение: действия уходят на сервер и
    // после того, как экран закрыт (ревью №12)
    final store = InspectionStore(
      repo,
      readOnly: !isExecutor,
      outbox: isExecutor
          ? InspectionOutboxes.instance?.forInspection(car.inspectionId!)
          : null,
    );
    if (isExecutor) {
      unawaited(InspectionOutboxes.instance?.markOpened(car.inspectionId!));
    }
    final navigator = Navigator.of(context);
    final ownRoute = ModalRoute.of(context);
    var finish = false;
    await navigator.push(
      MaterialPageRoute(
        builder: (_) => InspectionOverviewScreen(
          store: store,
          sendLabel: 'Завершить осмотр',
          // «Завершить осмотр» в сводке закрывает осмотр до карточки заказа
          // и открывает лист вердикта — как у разового осмотра
          onSendReport: canFinish
              ? () {
                  finish = true;
                  navigator.popUntil((route) => route == ownRoute);
                }
              : null,
        ),
      ),
    );
    await _c.load();
    if (finish && mounted && _c.order != null) {
      await _finishCandidate(_c.order!, car);
    }
  }

  /// Итог осмотра кандидата: вердикт и комментарий. Заказ остаётся в поиске,
  /// заказчик получает итог по машине сразу.
  Future<void> _finishCandidate(Order order, OrderCar car) async {
    final result = await showModalBottomSheet<(InspectionVerdict, String?)>(
      context: context,
      backgroundColor: context.colors.bg0,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => VerdictSheet(
        order: order,
        subject: car.title,
        submitLabel: 'Завершить осмотр',
      ),
    );
    if (result == null || !mounted) return;
    await _run(() => _c.completeCandidate(car, result.$1, result.$2));
  }

  /// Смотрит назначенный подборщик — ему телефон продавца и его правка.
  bool _isAssignedExecutor(Order order) => switch (order.viewerRole) {
    ViewerRole.executor => true,
    ViewerRole.customer => false,
    null =>
      !widget.viewerIsCustomer &&
          widget.auth?.user != null &&
          order.executor?.id == widget.auth!.user!.id,
  };

  /// Телефон продавца кандидата: машина — из ответа сервера.
  Future<void> _editSellerPhone(Order order, OrderCar car) async {
    final updated = await showSellerPhoneSheet(
      context,
      car: car,
      onSave: (phone) =>
          widget.store.updateCarSellerPhone(order.id, car.id, phone),
    );
    if (updated != null && mounted) _c.applyCar(updated);
  }

  /// Новый кандидат приходит с начатым осмотром — открываем его сразу,
  /// как разовый осмотр после «VIN и пробег», а не ищем в списке.
  Future<void> _startInspection(Order order) async {
    final car = await Navigator.of(context).push<OrderCar>(
      MaterialPageRoute(
        builder: (_) => StartInspectionScreen(
          repository: widget.store.repository,
          catalog: widget.store.catalog,
          order: order,
        ),
      ),
    );
    if (!mounted) return;
    if (car == null) {
      // отказ или «назад» — сервер мог успеть завести кандидата (QA №6)
      await refresh().catchError((_) {});
      return;
    }
    await _c.load();
    if (mounted && widget.auth != null && car.inspectionId != null) {
      await _openInspection(car);
    }
  }

  /// Покупка закрывает подбор. С [reported] — «Да» на сообщение
  /// исполнителя: машина уже выбрана, листа нет.
  Future<void> _completePurchase(Order order, {int? reported}) async {
    final carId = reported ?? await showPurchaseSheet(context, order: order);
    if (carId == null || !mounted) return;
    await _run(() => _c.completePurchase(carId));
  }

  /// Исполнитель: «заказчик купил эту машину».
  Future<void> _reportPurchase(Order order) async {
    final carId = await showReportPurchaseSheet(context, order: order);
    if (carId == null || !mounted) return;
    await _run(
      () => _c.reportPurchase(carId),
      done: 'Заказчик получит уведомление',
    );
  }

  /// Исполнитель отказывается от подбора (правило — Order.canRelease с
  /// сервера). Срывом не считается; заказ уходит в ленту — экран закрываем.
  Future<void> _release() async {
    final ok = await showConfirmSheet(
      context,
      title: 'Отказаться от подбора?',
      text:
          'Заказ вернётся в ленту к другим исполнителям, повторно '
          'откликнуться не получится. Готовые отчёты останутся у заказчика, '
          'начатые осмотры удалятся. Срывом это не считается.',
      confirmLabel: 'Отказаться',
    );
    if (!ok || !mounted) return;
    final navigator = Navigator.of(context);
    if (await _run(_c.release) && mounted) navigator.pop();
  }

  /// Заказчик: «нет, не покупал» на сообщение исполнителя.
  Future<void> _declinePurchaseReport(OrderCar? car) async {
    final ok = await showConfirmSheet(
      context,
      title: 'Не покупали ${car?.title ?? 'эту машину'}?',
      text:
          'Подборщик узнает, что покупка не подтверждена. Если купите '
          'машину позже — отметьте её кнопкой «Зафиксировать покупку».',
      confirmLabel: 'Нет, не покупал',
    );
    if (!ok || !mounted) return;
    await _run(_c.declinePurchaseReport);
  }

  /// Заказчик ошибся с купленной машиной — пока сервер пускает.
  Future<void> _changePurchase(Order order) async {
    final carId = await showChangePurchaseSheet(context, order: order);
    if (carId == null || !mounted) return;
    await _run(() => _c.changePurchase(carId), done: 'Покупка изменена');
  }

  /// Отменить можно, пока сервер отдаёт canCancel; заказ — из ответа.
  Future<void> _cancel() async {
    final ok = await showConfirmSheet(
      context,
      title: 'Отменить заказ?',
      text: 'Отклики исполнителей будут отклонены. Вернуть заказ нельзя.',
      confirmLabel: 'Отменить заказ',
      cancelLabel: 'Не отменять',
    );
    if (!ok || !mounted) return;
    await _run(_c.cancel);
  }

  /// Новый отзыв или правка; заказ — из ответа сервера, как и рейтинг.
  Future<void> _writeReview(Order order) => showReviewSheet(
    context,
    order: order,
    initial: order.review,
    onSubmit: (rating, text) => _c.submitReview(order, rating, text),
  );

  void _showReviews(UserSummary executor) =>
      openExecutorReviews(context, widget.store.reviews, executor);

  @override
  Widget build(BuildContext context) {
    final order = _c.order;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 20, 10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    style: IconButton.styleFrom(
                      backgroundColor: context.colors.bg1,
                      foregroundColor: context.colors.text1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      order != null ? 'Заказ #${order.id}' : 'Заказ',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: context.colors.text1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _c.error != null && !_c.loading
                  ? _buildError(_c.error!)
                  : _c.loading || order == null
                  ? const Center(child: CircularProgressIndicator())
                  : _buildBody(order),
            ),
          ],
        ),
      ),
    );
  }

  /// Тот же блок, что у карточки осмотра (InspectionOrderDetailScreen).
  Widget _buildError(String error) {
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
            error,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: context.colors.text3),
          ),
          const SizedBox(height: 10),
          CtaGhost(label: 'Повторить', onPressed: _c.load),
        ],
      ),
    );
  }

  Widget _buildBody(Order order) {
    final customer = _c.viewerIsCustomer;
    return RefreshIndicator(
      onRefresh: pullToRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          SelectionSummary(order: order),
          if (order.executor != null) ...[
            const SizedBox(height: 22),
            const SectionHead('Исполнитель'),
            ExecutorBox(
              order: order,
              onShowReviews: () => _showReviews(order.executor!),
              // исполнителю сервер отдаёт номер заказчика — он ниже, в «Заказчике»
              phone: customer ? order.counterpartPhone : null,
            ),
          ],
          if (!customer && order.counterpartPhone != null) ...[
            const SizedBox(height: 22),
            const SectionHead('Заказчик'),
            CustomerBox(order: order, phone: order.counterpartPhone!),
          ],
          PurchaseReportBlock(
            order: order,
            viewerIsCustomer: customer,
            completing: _c.completing,
            busy: _c.purchaseBusy,
            onConfirm: (carId) => _completePurchase(order, reported: carId),
            onDecline: _declinePurchaseReport,
          ),
          CandidatesSection(
            order: order,
            showSellerPhone: _isAssignedExecutor(order),
            onOpen: _canOpenInspection ? _openInspection : null,
            onEditSellerPhone: (car) => _editSellerPhone(order, car),
          ),
          PurchaseActions(
            order: order,
            viewerIsCustomer: customer,
            completing: _c.completing,
            busy: _c.purchaseBusy,
            onComplete: () => _completePurchase(order),
            onChange: () => _changePurchase(order),
          ),
          ExecutorActionsSection(
            order: order,
            viewerIsCustomer: customer,
            canAddCandidates: _c.canAddCandidates(order),
            library: _c.library,
            attaching: _c.attaching,
            purchaseBusy: _c.purchaseBusy,
            releasing: _c.releasing,
            onStartInspection: () => _startInspection(order),
            onAttachFromLibrary: _attachFromLibrary,
            onReportPurchase: () => _reportPurchase(order),
            onRelease: _release,
          ),
          OrderReviewSection(
            order: order,
            viewerIsCustomer: customer,
            onWrite: () => _writeReview(order),
          ),
          if (customer)
            ResponsesSection(
              order: order,
              onAccept: (id) => _run(() => _c.accept(id)),
              onShowReviews: _showReviews,
            ),
          if (customer && order.canCancel) ...[
            const SizedBox(height: 14),
            CtaGhost(
              label: 'Отменить заказ',
              onPressed: _c.cancelling ? null : _cancel,
            ),
          ],
        ],
      ),
    );
  }
}
