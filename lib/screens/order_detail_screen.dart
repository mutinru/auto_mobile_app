import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/api_client.dart';
import '../data/api_inspection_repository.dart';
import '../data/auth_service.dart';
import '../data/inspection_repository.dart';
import '../models/inspection_outcome.dart';
import '../models/inspection_verdict.dart';
import '../models/library_inspection.dart';
import '../models/order.dart';
import '../models/order_car.dart';
import '../models/order_response_status.dart';
import '../models/order_status.dart';
import '../models/user_summary.dart';
import '../state/order_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../util/ru_date.dart';
import '../state/inspection_store.dart';
import '../widgets/api_error.dart';
import '../widgets/app_ui.dart';
import '../widgets/confirm_sheet.dart';
import '../widgets/executor_box.dart';
import '../widgets/library_sheet.dart';
import '../widgets/order_review_section.dart';
import '../widgets/order_status_card.dart';
import '../widgets/payment_parts.dart';
import '../widgets/phone_contact.dart';
import '../widgets/phone_input.dart';
import '../widgets/seller_phone_sheet.dart';
import '../widgets/purchase_sheet.dart';
import '../widgets/response_card.dart';
import '../widgets/review_sheet.dart';
import '../widgets/verdict_sheet.dart';
import 'executor_reviews_screen.dart';
import 'auto_refresh.dart';
import 'inspection_overview_screen.dart';
import 'inspection_report_screen.dart';
import 'start_inspection_screen.dart';

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
  Order? _order;
  bool _loading = true;
  String? _error;
  bool _accepting = false;
  bool _completing = false;
  bool _cancelling = false;
  bool _attaching = false;

  /// Сообщение о покупке, ответ «нет» или смена купленной машины.
  bool _purchaseBusy = false;

  /// Идёт отказ исполнителя от подбора.
  bool _releasing = false;

  /// Свои готовые осмотры подборщика для этого подбора; null — не положено
  /// или не загрузилось (кнопки тогда нет: это не главное на экране).
  InspectionLibraryPage? _library;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Без finally любая ошибка (сеть, 500) оставляла карточку на вечном
  /// спиннере — теперь вместо него текст и «Повторить».
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await widget.store.fetchOrder(widget.orderId);
      if (mounted) setState(() => _order = order);
      _loadLibrary(order);
    } catch (e) {
      if (mounted) setState(() => _error = apiErrorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  bool get refreshPaused =>
      _loading ||
      _accepting ||
      _completing ||
      _cancelling ||
      _attaching ||
      _purchaseBusy;

  /// Тихое перечитывание (AutoRefresh): без спиннера, ошибку бросает.
  @override
  Future<void> refresh() async {
    final before = _order;
    final order = await widget.store.fetchOrder(widget.orderId);
    // пока ждали, заказ подменило действие — его ответ свежее
    if (!mounted || refreshPaused || !identical(_order, before)) return;
    setState(() {
      _order = order;
      _error = null;
    });
    widget.store.replaceOrder(order);
    _loadLibrary(order);
  }

  /// Заводить кандидатов может только назначенный исполнитель идущего
  /// подбора: заказчику сервер ответит 403, в закрытый подбор — 422.
  bool _canAddCandidates(Order order) =>
      widget.auth?.user != null &&
      order.executor?.id == widget.auth!.user!.id &&
      (order.status == OrderStatus.sourcing ||
          order.status == OrderStatus.inspecting);

  /// Библиотека осмотров — тихо, без спиннера: сбой лишь прячет кнопку.
  /// Что в неё попадает, решает сервер — список не фильтруем.
  Future<void> _loadLibrary(Order order) async {
    if (!_canAddCandidates(order)) {
      if (_library != null && mounted) setState(() => _library = null);
      return;
    }
    try {
      final page = await widget.store.fetchInspectionLibrary(order.id);
      if (mounted) setState(() => _library = page);
    } catch (_) {
      if (mounted) setState(() => _library = null);
    }
  }

  /// Свой готовый осмотр — кандидатом: выбор, подтверждение «ещё
  /// продаётся», запрос. Отчёт не открываем — он заморожен и исполнителю
  /// знаком; заказ перечитываем, кандидат приходит с сервера.
  Future<void> _attachFromLibrary(Order order) async {
    final library = _library;
    if (library == null || _attaching) return;
    final picked = await pickFromLibrary(context, library);
    if (picked == null || !mounted) return;
    setState(() => _attaching = true);
    try {
      await widget.store.attachFromLibrary(order.id, picked.inspectionId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Кандидат добавлен')),
        );
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
      // правило — у сервера: список мог устареть, перечитываем
      await _loadLibrary(order);
    } finally {
      if (mounted) setState(() => _attaching = false);
    }
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
    final isExecutor =
        _order?.executor != null &&
        _order!.executor!.id == widget.auth?.user?.id;
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
    final store = InspectionStore(repo, readOnly: !isExecutor);
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
    await _load();
    if (finish && mounted && _order != null) {
      await _finishCandidate(_order!, car);
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
    try {
      final updated = await widget.store.completeCandidate(
        order.id,
        car.id,
        verdict: result.$1,
        comment: result.$2,
      );
      if (mounted) setState(() => _order = updated);
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  /// Смотрит назначенный подборщик — ему телефон продавца и его правка.
  bool _isAssignedExecutor(Order order) =>
      !widget.viewerIsCustomer &&
      widget.auth?.user != null &&
      order.executor?.id == widget.auth!.user!.id;

  /// Телефон продавца кандидата: машина — из ответа сервера.
  Future<void> _editSellerPhone(Order order, OrderCar car) async {
    final updated = await showSellerPhoneSheet(
      context,
      car: car,
      onSave: (phone) =>
          widget.store.updateCarSellerPhone(order.id, car.id, phone),
    );
    if (updated == null || !mounted) return;
    final current = _order ?? order;
    final next = current.copyWith(
      cars: [for (final c in current.cars) c.id == updated.id ? updated : c],
    );
    setState(() => _order = next);
    widget.store.replaceOrder(next);
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
    await _load();
    if (mounted && widget.auth != null && car.inspectionId != null) {
      await _openInspection(car);
    }
  }

  Future<void> _accept(int responseId) async {
    if (_accepting) return;
    setState(() => _accepting = true);
    try {
      await widget.store.acceptResponse(widget.orderId, responseId);
      await _load();
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  /// Покупка закрывает подбор; заказ — из ответа сервера, и в нём сразу
  /// can_review, так что блок отзыва появится без перезагрузки. С [reported]
  /// — «Да» на сообщение исполнителя: машина уже выбрана, листа нет.
  Future<void> _completePurchase(Order order, {int? reported}) async {
    final carId = reported ?? await showPurchaseSheet(context, order: order);
    if (carId == null || !mounted) return;
    setState(() => _completing = true);
    try {
      final updated = await widget.store.completeSelection(
        order.id,
        carId: carId,
      );
      if (mounted) setState(() => _order = updated);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  /// Исполнитель: «заказчик купил эту машину». Заказ не закрывается —
  /// ждём ответа заказчика (purchaseReport в ответе сервера).
  Future<void> _reportPurchase(Order order) async {
    final carId = await showReportPurchaseSheet(context, order: order);
    if (carId == null || !mounted) return;
    await _purchaseAction(
      () => widget.store.reportPurchase(order.id, carId: carId),
      done: 'Заказчик получит уведомление',
    );
  }

  /// Исполнитель отказывается от подбора (правило — Order.canRelease с
  /// сервера). Срывом не считается; заказ уходит в ленту — экран закрываем.
  Future<void> _release(Order order) async {
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
    setState(() => _releasing = true);
    try {
      await widget.store.declineOrder(order.id);
      if (mounted) navigator.pop();
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _releasing = false);
    }
  }

  /// Заказчик: «нет, не покупал» на сообщение исполнителя.
  Future<void> _declinePurchaseReport(Order order, OrderCar? car) async {
    final ok = await showConfirmSheet(
      context,
      title: 'Не покупали ${car?.title ?? 'эту машину'}?',
      text:
          'Подборщик узнает, что покупка не подтверждена. Если купите '
          'машину позже — отметьте её кнопкой «Зафиксировать покупку».',
      confirmLabel: 'Нет, не покупал',
    );
    if (!ok || !mounted) return;
    await _purchaseAction(() => widget.store.declinePurchaseReport(order.id));
  }

  /// Заказчик ошибся с купленной машиной — пока сервер пускает.
  Future<void> _changePurchase(Order order) async {
    final carId = await showChangePurchaseSheet(context, order: order);
    if (carId == null || !mounted) return;
    await _purchaseAction(
      () => widget.store.changePurchase(order.id, carId: carId),
      done: 'Покупка изменена',
    );
  }

  Future<void> _purchaseAction(
    Future<Order> Function() action, {
    String? done,
  }) async {
    setState(() => _purchaseBusy = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() => _order = updated);
      if (done != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(done)));
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _purchaseBusy = false);
    }
  }

  /// Сообщение исполнителя о покупке, пока подбор идёт: заказчику — вопрос
  /// с «Да»/«Нет», исполнителю — «ждём подтверждения».
  List<Widget> _purchaseReport(Order order) {
    final report = order.purchaseReport;
    if (report == null ||
        order.isInspection ||
        (order.status != OrderStatus.sourcing &&
            order.status != OrderStatus.inspecting)) {
      return const [];
    }
    final car = order.cars.where((c) => c.id == report.carId).firstOrNull;
    final title = car?.title ?? 'машины';
    if (!widget.viewerIsCustomer) {
      return [
        const SizedBox(height: 22),
        StatusNote(text: 'Ждём подтверждения заказчика: $title.'),
      ];
    }
    final executor = order.executor?.name ?? 'Подборщик';
    return [
      const SizedBox(height: 22),
      StatusNote(
        icon: Icons.key_outlined,
        text:
            '$executor отметил покупку $title. Подтвердите — и сможете '
            'оценить подборщика.',
      ),
      const SizedBox(height: 10),
      CtaPrimary(
        label: 'Да, купил',
        icon: Icons.check,
        loading: _completing,
        onPressed: _purchaseBusy
            ? null
            : () => _completePurchase(order, reported: report.carId),
      ),
      CtaGhost(
        label: 'Нет, не покупал',
        onPressed: _purchaseBusy || _completing
            ? null
            : () => _declinePurchaseReport(order, car),
      ),
    ];
  }

  /// Есть из чего выбрать другую купленную: кандидатов с осмотром больше
  /// одного (без осмотра покупку не отметить — сервер ответит 422).
  bool _hasPurchaseChoice(Order order) =>
      order.cars.where((c) => c.inspectionId != null).length > 1;

  /// Те же условия, что у OrderController::complete на бекенде: заказчик,
  /// подбор в работе и хотя бы один кандидат, чтобы было что выбрать.
  bool _canCompletePurchase(Order order) =>
      widget.viewerIsCustomer &&
      !order.isInspection &&
      (order.status == OrderStatus.sourcing ||
          order.status == OrderStatus.inspecting) &&
      order.cars.isNotEmpty;

  /// Отменить можно, пока сервер отдаёт canCancel; заказ — из ответа.
  Future<void> _cancel(Order order) async {
    final ok = await showConfirmSheet(
      context,
      title: 'Отменить заказ?',
      text: 'Отклики исполнителей будут отклонены. Вернуть заказ нельзя.',
      confirmLabel: 'Отменить заказ',
      cancelLabel: 'Не отменять',
    );
    if (!ok || !mounted) return;
    setState(() => _cancelling = true);
    try {
      final updated = await widget.store.cancelOrder(order.id);
      if (mounted) setState(() => _order = updated);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  /// Новый отзыв или правка; заказ — из ответа сервера, как и рейтинг.
  Future<void> _writeReview(Order order) {
    return showReviewSheet(
      context,
      order: order,
      initial: order.review,
      onSubmit: (rating, text) async {
        final updated = order.review == null
            ? await widget.store.leaveReview(
                order.id,
                rating: rating,
                text: text,
              )
            : await widget.store.updateReview(
                order.id,
                rating: rating,
                text: text,
              );
        if (mounted) setState(() => _order = updated);
      },
    );
  }

  void _showReviews(Order order, UserSummary executor) =>
      openExecutorReviews(context, widget.store.repository, executor);

  @override
  Widget build(BuildContext context) {
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
                      _order != null ? 'Заказ #${_order!.id}' : 'Заказ',
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
              child: _error != null && !_loading
                  ? _buildError(_error!)
                  : _loading || _order == null
                  ? const Center(child: CircularProgressIndicator())
                  : _buildBody(_order!),
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
          CtaGhost(label: 'Повторить', onPressed: _load),
        ],
      ),
    );
  }

  Widget _buildBody(Order order) {
    return RefreshIndicator(
      onRefresh: pullToRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          OrderStatusCard(order: order),
          const SizedBox(height: 14),
          Text(
            order.carTitle,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w600,
              color: context.colors.text1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            [
              if (order.cities.isNotEmpty) order.cities.join(', '),
              if (order.mileageTo != null)
                'пробег до ${money(order.mileageTo!)} км',
              ?budgetRange(order.budgetMin, order.budgetMax),
            ].join(' · '),
            style: TextStyle(fontSize: 12.5, color: context.colors.text2),
          ),
          if (order.requirements.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in order.requirements)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: context.colors.bg1,
                      border: Border.all(color: context.colors.chipEdge),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      r,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.colors.text2,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (order.comment != null && order.comment!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              order.comment!,
              style: TextStyle(fontSize: 13, color: context.colors.text2),
            ),
          ],
          if (order.executor != null) ...[
            const SizedBox(height: 22),
            const SectionHead('Исполнитель'),
            ExecutorBox(
              order: order,
              onShowReviews: () => _showReviews(order, order.executor!),
              // исполнителю сервер отдаёт номер заказчика — он ниже, в «Заказчике»
              phone: widget.viewerIsCustomer ? order.counterpartPhone : null,
            ),
          ],
          if (!widget.viewerIsCustomer && order.counterpartPhone != null) ...[
            const SizedBox(height: 22),
            const SectionHead('Заказчик'),
            _CustomerBox(order: order, phone: order.counterpartPhone!),
          ],
          // сообщение о покупке — главное действие, пока ждёт ответа
          ..._purchaseReport(order),
          // кандидаты — то, ради чего заказчик открывает подбор: сразу под
          // исполнителем, до отзыва и откликов
          if (order.cars.isNotEmpty) ...[
            const SizedBox(height: 22),
            SectionHead('Кандидаты', extra: '${order.cars.length}'),
            for (final car in order.cars)
              _CandidateCard(
                car: car,
                onTap: car.inspectionId != null && _canOpenInspection
                    ? () => _openInspection(car)
                    : null,
                // телефон продавца — заметка подборщика; заказчику сервер
                // его не отдаёт, но и показывать незачем
                showSellerPhone: _isAssignedExecutor(order),
                onEditSellerPhone: order.status == OrderStatus.cancelled
                    ? null
                    : () => _editSellerPhone(order, car),
              ),
          ],
          // при ждущем сообщении исполнителя главная кнопка — «Да, купил»
          // выше; другую машину заказчик всё равно может отметить сам
          if (_canCompletePurchase(order))
            if (order.purchaseReport == null) ...[
              const SizedBox(height: 14),
              CtaPrimary(
                label: 'Зафиксировать покупку',
                icon: Icons.check,
                loading: _completing,
                onPressed: () => _completePurchase(order),
              ),
            ] else if (_hasPurchaseChoice(order))
              CtaGhost(
                label: 'Купил другую машину',
                onPressed: _completing || _purchaseBusy
                    ? null
                    : () => _completePurchase(order),
              ),
          // перевыбор покупки — сутки после закрытия, окно с сервера
          if (widget.viewerIsCustomer &&
              order.status == OrderStatus.completed &&
              order.purchaseEditableUntil != null &&
              _hasPurchaseChoice(order)) ...[
            const SizedBox(height: 14),
            CtaGhost(
              label: 'Изменить покупку',
              onPressed: _purchaseBusy ? null : () => _changePurchase(order),
            ),
          ],
          // Заводить кандидата и стартовать осмотр может только назначенный
          // исполнитель — у заказчика этот вызов вернёт 403; в закрытый подбор
          // нового кандидата не завести (422), начатые — дозавершаются.
          if (_canAddCandidates(order)) ...[
            const SizedBox(height: 14),
            CtaPrimary(
              label: 'Осмотреть новый вариант',
              icon: Icons.add,
              onPressed: () => _startInspection(order),
            ),
            // свои готовые осмотры — только если есть что добавить
            if (_library?.items.isNotEmpty ?? false)
              CtaGhost(
                label: 'Из моих осмотров · ${_library!.items.length}',
                onPressed: _attaching ? null : () => _attachFromLibrary(order),
              ),
          ],
          // заказчик купил, но не отметил — сообщает подборщик (правило с сервера)
          if (!widget.viewerIsCustomer && order.canReportPurchase)
            CtaGhost(
              label: 'Заказчик купил машину',
              onPressed: _purchaseBusy ? null : () => _reportPurchase(order),
            ),
          // выход из подбора — только по правилу с сервера (can_release)
          if (!widget.viewerIsCustomer && order.canRelease)
            CtaGhost(
              label: 'Отказаться от подбора',
              onPressed: _releasing ? null : () => _release(order),
            ),
          OrderReviewSection(
            order: order,
            viewerIsCustomer: widget.viewerIsCustomer,
            onWrite: () => _writeReview(order),
          ),
          if (widget.viewerIsCustomer && order.responses.isNotEmpty) ...[
            const SizedBox(height: 22),
            SectionHead('Отклики', extra: '${order.responses.length}'),
            if (order.status == OrderStatus.awaitingExecutor &&
                order.responses.any(
                  (r) => r.status == OrderResponseStatus.pending,
                ))
              const PhoneExchangeNote(
                'Когда вы выберете исполнителя, вы увидите телефоны друг '
                'друга — сможете созвониться напрямую.',
              ),
            // выбранный — первым, за ним ждущие решения, решённые — в конце
            for (final r in [
              ...order.responses.where(
                (r) => r.status == OrderResponseStatus.accepted,
              ),
              ...order.responses.where(
                (r) => r.status == OrderResponseStatus.pending,
              ),
              ...order.responses.where((r) => !r.status.isActive),
            ])
              ResponseCard(
                response: r,
                askingPrice: order.askingPrice,
                onAccept: r.status == OrderResponseStatus.pending
                    ? () => _accept(r.id)
                    : null,
                onShowReviews: () => _showReviews(order, r.executor),
              ),
          ],
          if (widget.viewerIsCustomer && order.canCancel) ...[
            const SizedBox(height: 14),
            CtaGhost(
              label: 'Отменить заказ',
              onPressed: _cancelling ? null : () => _cancel(order),
            ),
          ],
        ],
      ),
    );
  }
}

/// Заказчик подбора для исполнителя: имя и телефон с «Позвонить» — номер
/// сервер открывает с выбора исполнителя.
class _CustomerBox extends StatelessWidget {
  const _CustomerBox({required this.order, required this.phone});

  final Order order;
  final String phone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: c.bg1,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Avatar(
                initialsOf(order.customer.name),
                size: 36,
                url: order.customer.avatarUrl,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  order.customer.name,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: c.text1,
                  ),
                ),
              ),
            ],
          ),
          PhoneCallRow(label: 'Телефон заказчика', phone: phone),
        ],
      ),
    );
  }
}

/// Кандидат подбора: машина, комментарий к вердикту и плашка — идёт
/// осмотр, исход покупки или вердикт. Купленная — в зелёной рамке, как
/// выбранный отклик: в длинном списке её видно сразу. Тап открывает осмотр.
class _CandidateCard extends StatelessWidget {
  const _CandidateCard({
    required this.car,
    this.onTap,
    this.showSellerPhone = false,
    this.onEditSellerPhone,
  });

  final OrderCar car;
  final VoidCallback? onTap;

  /// Подборщику — строка телефона продавца (или «Добавить»).
  final bool showSellerPhone;

  /// Правка номера; null — заказ отменён, только показ.
  final VoidCallback? onEditSellerPhone;

  /// Цвет плашки: идущий осмотр — синий, покупка — зелёный, дальше вердикт
  /// (и у некупленных после покупки); «осмотрена» и «осмотр не начат» —
  /// нейтральные.
  Color? _pillColor(AppColors c) {
    if (car.inspectionStatus == 'in_progress') return c.statusInfo;
    if (car.inspectionOutcome == InspectionOutcome.purchased) {
      return c.statusDone;
    }
    return car.verdict?.color(c);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final comment = car.verdictComment;
    final bought = car.inspectionOutcome == InspectionOutcome.purchased;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: bought ? Color.alphaBlend(c.buySoft, c.bg1) : c.bg1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
          side: bought
              ? BorderSide(color: c.buyEdge, width: 1.5)
              : BorderSide(color: c.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            car.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: c.text1,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Pill(car.inspectionLabel, color: _pillColor(c)),
                          // осмотр из библиотеки сделан раньше — когда
                          if (car.fromLibrary &&
                              car.inspectionCompletedAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: Text(
                                inspectedAgo(car.inspectionCompletedAt!),
                                style: TextStyle(fontSize: 12, color: c.text2),
                              ),
                            ),
                          if (comment != null && comment.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: Text(
                                comment,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: c.text2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (onTap != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right, size: 20, color: c.text2),
                    ],
                  ],
                ),
                if (showSellerPhone)
                  _SellerPhoneLine(
                    phone: car.sellerPhone,
                    onEdit: onEditSellerPhone,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Телефон продавца в карточке кандидата — только подборщику: номер с
/// «Скопировать» и «Позвонить», тап по номеру — правка. Номера нет —
/// «Добавить телефон продавца».
class _SellerPhoneLine extends StatelessWidget {
  const _SellerPhoneLine({required this.phone, this.onEdit});

  final String? phone;
  final VoidCallback? onEdit;

  void _copy(BuildContext context, String phone) {
    Clipboard.setData(ClipboardData(text: formatPhone(phone)));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Номер продавца скопирован')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final phone = this.phone;
    if (phone == null) {
      if (onEdit == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: TextButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Телефон продавца · только для вас'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 11),
        Container(height: 1, color: c.line),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Продавец · только для вас',
                        style: TextStyle(fontSize: 11.5, color: c.text2),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              formatPhone(phone),
                              style: TextStyle(
                                fontFamily: AppTheme.monoFamily,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: c.text1,
                              ),
                            ),
                          ),
                          if (onEdit != null) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.edit_outlined, size: 14, color: c.text2),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Скопировать',
              onPressed: () => _copy(context, phone),
              icon: Icon(Icons.copy_rounded, size: 19, color: c.text1),
            ),
            IconButton.filled(
              tooltip: 'Позвонить',
              onPressed: () => callPhone(context, phone),
              style: IconButton.styleFrom(
                backgroundColor: c.modeBuy,
                foregroundColor: c.modeBuyInk,
              ),
              icon: const Icon(Icons.call, size: 19),
            ),
          ],
        ),
      ],
    );
  }
}
