import 'package:flutter/material.dart';

import '../data/api_client.dart';
import '../data/api_inspection_repository.dart';
import '../data/auth_service.dart';
import '../models/order.dart';
import '../models/order_response_status.dart';
import '../state/order_store.dart';
import '../theme/app_colors.dart';
import '../state/inspection_store.dart';
import '../widgets/app_ui.dart';
import '../widgets/order_status_pill.dart';
import 'inspection_overview_screen.dart';
import 'start_inspection_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.store,
    required this.orderId,
    required this.viewerIsCustomer,
    this.auth,
  });

  final OrderStore store;
  final int orderId;

  /// Экран открыт из "Мои заказы" (customer может принимать отклики) или
  /// из "Заказы рядом"/после отклика (executor, только на просмотр).
  final bool viewerIsCustomer;

  /// Нужен, чтобы открыть осмотр кандидата (ApiInspectionRepository).
  final AuthService? auth;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Order? _order;
  bool _loading = true;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final order = await widget.store.fetchOrder(widget.orderId);
    if (mounted) {
      setState(() {
        _order = order;
        _loading = false;
      });
    }
  }

  Future<void> _openInspection(int inspectionId) async {
    final repo = ApiInspectionRepository(
      ApiClient(widget.auth!),
      inspectionId: inspectionId,
    );
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InspectionOverviewScreen(store: InspectionStore(repo)),
      ),
    );
    await _load();
  }

  Future<void> _startInspection(Order order) async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StartInspectionScreen(
          repository: widget.store.repository,
          order: order,
        ),
      ),
    );
    if (created == true) await _load();
  }

  Future<void> _accept(int responseId) async {
    setState(() => _accepting = true);
    try {
      await widget.store.acceptResponse(widget.orderId, responseId);
      await _load();
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

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
                      backgroundColor: AppColors.bg1,
                      foregroundColor: AppColors.text1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _order != null ? 'Заказ #${_order!.id}' : 'Заказ',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading || _order == null
                  ? const Center(child: CircularProgressIndicator())
                  : _buildBody(_order!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(Order order) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      children: [
        OrderStatusPill(status: order.status),
        const SizedBox(height: 10),
        Text(
          order.carTitle,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600, color: AppColors.text1),
        ),
        const SizedBox(height: 6),
        Text(
          [
            if (order.cities.isNotEmpty) order.cities.join(', '),
            if (order.mileageTo != null) 'пробег до ${order.mileageTo} км',
            if (order.budgetMin != null || order.budgetMax != null)
              '${order.budgetMin ?? 0} — ${order.budgetMax ?? '?'} ₽',
          ].join(' · '),
          style: const TextStyle(fontSize: 12.5, color: AppColors.text2),
        ),
        if (order.requirements.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in order.requirements)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.bg1,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(r, style: const TextStyle(fontSize: 11.5, color: AppColors.text2)),
                ),
            ],
          ),
        ],
        if (order.comment != null && order.comment!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(order.comment!, style: const TextStyle(fontSize: 13, color: AppColors.text2)),
        ],
        if (order.executor != null) ...[
          const SizedBox(height: 22),
          _SectionLabel('Исполнитель'),
          const SizedBox(height: 8),
          _InfoRow(label: order.executor!.name, trailing: order.price != null ? '${order.price} ₽' : null),
        ],
        if (order.cars.isNotEmpty) ...[
          const SizedBox(height: 22),
          _SectionLabel('Кандидаты'),
          const SizedBox(height: 8),
          for (final car in order.cars)
            _InfoRow(
              label: car.title,
              trailing: car.inspectionOutcome ?? car.inspectionStatus ?? 'осмотр не начат',
              onTap: car.inspectionId != null && widget.auth != null
                  ? () => _openInspection(car.inspectionId!)
                  : null,
            ),
        ],
        // Заводить кандидата и стартовать осмотр может только назначенный
        // исполнитель — у заказчика этот вызов вернёт 403.
        if (widget.auth?.user != null &&
            order.executor?.id == widget.auth!.user!.id) ...[
          const SizedBox(height: 14),
          CtaPrimary(
            label: 'Осмотреть новый вариант',
            icon: Icons.add,
            onPressed: () => _startInspection(order),
          ),
        ],
        if (widget.viewerIsCustomer && order.responses.isNotEmpty) ...[
          const SizedBox(height: 22),
          _SectionLabel('Отклики'),
          const SizedBox(height: 8),
          for (final r in order.responses)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: AppColors.bg1, borderRadius: BorderRadius.circular(13)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.executor.name, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text1)),
                        const SizedBox(height: 2),
                        Text('${r.proposedPrice} ₽', style: const TextStyle(fontSize: 12, color: AppColors.text2)),
                        if (r.message != null) ...[
                          const SizedBox(height: 4),
                          Text(r.message!, style: const TextStyle(fontSize: 11.5, color: AppColors.text3)),
                        ],
                      ],
                    ),
                  ),
                  if (r.status == OrderResponseStatus.pending)
                    ElevatedButton(
                      onPressed: _accepting ? null : () => _accept(r.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusDone,
                        foregroundColor: const Color(0xFF07150E),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Принять', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    )
                  else
                    Text(
                      r.status == OrderResponseStatus.accepted ? 'принят' : 'отклонён',
                      style: const TextStyle(fontSize: 11, color: AppColors.text3),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(fontSize: 10, letterSpacing: 1.2, color: AppColors.text3, fontWeight: FontWeight.w600),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, this.trailing, this.onTap});
  final String label;
  final String? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(color: AppColors.bg1, borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.text1)),
          if (trailing != null)
            Text(trailing!, style: const TextStyle(fontSize: 12, color: AppColors.text2)),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, size: 16, color: AppColors.text3),
          ],
        ],
      ),
      ),
    );
  }
}
