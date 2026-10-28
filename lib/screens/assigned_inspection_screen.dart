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
import '../widgets/app_ui.dart';
import '../widgets/inspection_order_parts.dart';
import '../widgets/verdict_sheet.dart';
import 'inspection_overview_screen.dart';
import 'inspection_report_screen.dart';

/// Разовый осмотр глазами назначенного исполнителя: куда и когда ехать,
/// телефон продавца, старт осмотра по деталям и итоговый вердикт.
///
/// Отдельный экран, а не ветка в [InspectionOrderDetailScreen]: у заказчика
/// там выбор исполнителя по откликам, у исполнителя — работа по заказу.
/// Тип осмотра не выбирается — всегда полный (13 деталей).
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

class _AssignedInspectionScreenState extends State<AssignedInspectionScreen> {
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
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Ошибки действий — SnackBar'ом, экран при этом остаётся рабочим.
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Бекенд создаёт осмотр с 13 деталями и переводит заказ в «на осмотре»;
  /// сразу открываем осмотр, чтобы не искать его вторым нажатием.
  Future<void> _start(Order order) async {
    int? inspectionId;
    await _run(() async {
      inspectionId = await widget.store.repository.startInspection(
        order.id,
        order.cars.first.id,
      );
      await _load();
    });
    if (mounted && inspectionId != null && widget.auth != null) {
      await _openInspection(inspectionId!);
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
      children: [
        InspectionOrderSummary(
          order: order,
          // гонорар — цена из принятого отклика; до принятия её нет
          priceLabel: 'Ваш гонорар',
          price: order.price ?? order.askingPrice,
        ),
        if (order.verdict != null) ...[
          const SizedBox(height: 22),
          const SectionHead('Итог осмотра'),
          InspectionVerdictBox(order: order),
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
    );
  }

  /// Кнопки внизу по статусу: назначен → начать, на осмотре → продолжить
  /// и завершить. У завершённого действий нет.
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
            const SizedBox(height: 4),
            CtaGhost(
              label: 'Завершить осмотр',
              onPressed: _busy ? null : () => _complete(order),
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
