import 'dart:ui';

import 'package:flutter/material.dart';

import '../data/public_feed_repository.dart';
import '../models/order_status.dart';
import '../models/public_order.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';

/// Экран 02 из car-marketplace-experiment.html — «заказ · открытый просмотр».
/// Ход работы виден всем, фото и контакты закрыты до входа.
class PublicOrderScreen extends StatefulWidget {
  const PublicOrderScreen({
    super.key,
    required this.orderId,
    required this.onRepeatSelection,
  });

  final int orderId;

  /// «Хочу такой же подбор» — сразу форма подбора (через вход для гостя).
  final VoidCallback onRepeatSelection;

  @override
  State<PublicOrderScreen> createState() => _PublicOrderScreenState();
}

class _PublicOrderScreenState extends State<PublicOrderScreen> {
  final _repository = PublicFeedRepository();

  PublicOrder? _order;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final order = await _repository.fetchOrder(widget.orderId);
      if (!mounted) return;
      setState(() {
        _order = order;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            DetailHead(
              title: order?.car ?? 'Заказ',
              eyebrow: order != null
                  ? 'заказ #${order.id} · ${order.status.label}'
                  : null,
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: Text(
                              'Не удалось загрузить заказ:\n$_error',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.text3,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                      : _body(order!),
            ),
            // .join-bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Column(
                children: [
                  CtaPrimary(label: 'Хочу такой же подбор', onPressed: widget.onRepeatSelection),
                  const SizedBox(height: 9),
                  const Text(
                    'Или войдите, чтобы открыть отчёт целиком '
                    'и написать исполнителю',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.text3,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(PublicOrder order) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
      children: [
        // .hero-block
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.bg1,
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Hero(
                    label: 'Бюджет заказчика',
                    value: order.budgetMax != null
                        ? '${money(order.budgetMax!)} ₽'
                        : '—',
                    mono: true,
                  ),
                  _Hero(
                    label: 'Город',
                    value: order.city ?? '—',
                    alignEnd: true,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Container(height: 1, color: AppColors.line),
              const SizedBox(height: 13),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Hero(label: 'Осмотрено', value: '${order.carsInspected} авто'),
                  _Hero(
                    label: 'Отклонено',
                    value: '${order.carsRejected}',
                    color: order.carsRejected > 0 ? AppColors.statusDefect : null,
                    alignEnd: true,
                  ),
                ],
              ),
            ],
          ),
        ),

        if (order.requirements.isNotEmpty) ...[
          const SizedBox(height: 22),
          const SectionHead('Требования заказчика'),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in order.requirements)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.bg1,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    r,
                    style: const TextStyle(fontSize: 12, color: AppColors.text2),
                  ),
                ),
            ],
          ),
        ],

        const SizedBox(height: 22),
        const SectionHead('Как шла работа'),
        for (var i = 0; i < order.timeline.length; i++)
          _TimelineItem(
            step: order.timeline[i],
            last: i == order.timeline.length - 1,
          ),

        const SizedBox(height: 22),
        const SectionHead('Фото осмотра', extra: 'после входа'),
        // .locked — размытая заглушка вместо фото
        Stack(
          alignment: Alignment.center,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 4.5, sigmaY: 4.5),
              child: Opacity(
                opacity: 0.5,
                child: Row(
                  children: [
                    for (final c in const [
                      [Color(0xFF5A6470), Color(0xFF2C3138)],
                      [Color(0xFF4A5260), Color(0xFF1F242C)],
                      [Color(0xFF667080), Color(0xFF23282F)],
                    ]) ...[
                      Expanded(
                        child: Container(
                          height: 62,
                          margin: const EdgeInsets.only(right: 7),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(11),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: c,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.bg3,
                    border: Border.all(color: AppColors.line),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    size: 15,
                    color: AppColors.text2,
                  ),
                ),
                const SizedBox(height: 7),
                const Text(
                  'Полный отчёт и фото — после входа',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.text2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),

        if (order.executorName != null) ...[
          const SizedBox(height: 22),
          const SectionHead('Исполнитель'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.bg1,
              border: Border.all(color: AppColors.line),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Avatar(initialsOf(order.executorName!), size: 54),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.executorName!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.32,
                          color: AppColors.text1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${order.executorCompleted ?? 0} заказов выполнено',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.text2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// .hero-label + .hero-val
class _Hero extends StatelessWidget {
  const _Hero({
    required this.label,
    required this.value,
    this.mono = false,
    this.color,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool mono;
  final Color? color;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.text3)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontFamily: mono ? AppTheme.monoFamily : null,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.15,
            color: color ?? AppColors.text1,
          ),
        ),
      ],
    );
  }
}

/// .tl-item — шаг таймлайна с точкой и линией.
class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.step, required this.last});

  final TimelineStep step;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 17,
                height: 17,
                decoration: BoxDecoration(
                  color: step.done ? AppColors.statusDone : AppColors.bg3,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.bg0, width: 2),
                ),
                child: step.done
                    ? const Icon(Icons.check, size: 9, color: Color(0xFF07150E))
                    : null,
              ),
              if (!last)
                Expanded(
                  child: Container(width: 1.5, color: AppColors.line),
                ),
            ],
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text1,
                    ),
                  ),
                  if (step.at != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      '${step.at!.day}.${step.at!.month.toString().padLeft(2, '0')}.${step.at!.year}',
                      style: const TextStyle(
                        fontFamily: AppTheme.monoFamily,
                        fontSize: 10.5,
                        color: AppColors.text3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
