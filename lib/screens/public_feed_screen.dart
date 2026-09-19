import 'package:flutter/material.dart';

import '../data/public_feed_repository.dart';
import '../models/feed_card.dart';
import '../models/order_status.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../widgets/app_ui.dart';
import 'public_order_screen.dart';

/// Экран 01 из car-marketplace-experiment.html — «витрина».
/// Работает до входа: показывает, что происходит в сервисе прямо сейчас.
class PublicFeedScreen extends StatefulWidget {
  const PublicFeedScreen({
    super.key,
    required this.onPlaceOrder,
    required this.onRepeatSelection,
  });

  /// «Разместить заказ» — лист выбора «подбор / осмотр», затем форма.
  final VoidCallback onPlaceOrder;

  /// «Хочу такой же подбор» в карточке заказа.
  final VoidCallback onRepeatSelection;

  @override
  State<PublicFeedScreen> createState() => _PublicFeedScreenState();
}

class _PublicFeedScreenState extends State<PublicFeedScreen> {
  final _repository = PublicFeedRepository();

  FeedStats? _stats;
  List<FeedCard> _cards = const [];
  bool _loading = true;
  String? _error;
  int _tab = 0;

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
      final (stats, cards) = await _repository.fetchFeed();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _cards = cards;
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
    final visible = _cards.where((c) {
      if (_tab == 1) return c.status != OrderStatus.completed;
      if (_tab == 2) return c.status == OrderStatus.completed;
      return true;
    }).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            DetailHead(
              title: 'Что происходит сейчас',
              eyebrow: 'без регистрации',
              // витрина открывается поверх вопроса о намерении — стрелка
              // возвращает к нему
              onBack: Navigator.of(context).canPop()
                  ? () => Navigator.of(context).pop()
                  : null,
            ),
            // .feed-stats
            if (_stats != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                child: Row(
                  children: [
                    _FStat('${_stats!.completed}', 'заказов выполнено'),
                    const SizedBox(width: 8),
                    _FStat(
                      '${_stats!.inProgress}',
                      'в работе сейчас',
                      color: AppColors.statusProgress,
                    ),
                    const SizedBox(width: 8),
                    _FStat(
                      '${_stats!.inspections}',
                      'осмотров проведено',
                      color: AppColors.statusDone,
                    ),
                  ],
                ),
              ),
            AppToggle(
              labels: const ['Все', 'В работе', 'Выполнены'],
              activeIndex: _tab,
              onChanged: (i) => setState(() => _tab = i),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(22),
                            child: Text(
                              'Не удалось загрузить ленту:\n$_error',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.text3,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        )
                      : visible.isEmpty
                          ? const Center(
                              child: Text(
                                'Пока ничего не происходит',
                                style: TextStyle(
                                  color: AppColors.text3,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _load,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
                                itemCount: visible.length,
                                itemBuilder: (context, i) => _FeedCardView(
                                  card: visible[i],
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => PublicOrderScreen(
                                        orderId: visible[i].id,
                                        onRepeatSelection: widget.onRepeatSelection,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
            ),
            // .join-bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Column(
                children: [
                  CtaPrimary(label: 'Разместить заказ', onPressed: widget.onPlaceOrder),
                  const SizedBox(height: 9),
                  const Text(
                    'Вход по номеру телефона · бесплатно, оплата только за результат',
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
}

/// .fstat
class _FStat extends StatelessWidget {
  const _FStat(this.value, this.caption, {this.color});

  final String value;
  final String caption;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.bg1,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: AppTheme.monoFamily,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.34,
                color: color ?? AppColors.text1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              caption,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9.5, color: AppColors.text3),
            ),
          ],
        ),
      ),
    );
  }
}

/// .feed-card
class _FeedCardView extends StatelessWidget {
  const _FeedCardView({required this.card, required this.onTap});

  final FeedCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final done = card.status == OrderStatus.completed;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bg1,
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Pill(
                card.status.label,
                color: done ? AppColors.statusDone : card.status.pillColor,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(card.car, style: AppText.orderCar),
          const SizedBox(height: 5),
          Text(
            [
              if (card.city != null) card.city!,
              if (card.budgetMax != null) 'до ${money(card.budgetMax!)} ₽',
            ].join(' · '),
            style: AppText.orderMeta,
          ),
          // .feed-progress
          if (card.hasProgress) ...[
            const SizedBox(height: 11),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: card.progressFraction,
                minHeight: 4,
                backgroundColor: AppColors.bg0,
                valueColor: const AlwaysStoppedAnimation(AppColors.statusProgress),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Проверено ${card.assessed} из ${card.total} деталей',
                  style: const TextStyle(fontSize: 11, color: AppColors.text3),
                ),
                Text(
                  '${card.carIndex}-й вариант',
                  style: const TextStyle(fontSize: 11, color: AppColors.text3),
                ),
              ],
            ),
          ],
          // .feed-foot
          if (card.executorName != null) ...[
            const SizedBox(height: 12),
            Container(height: 1, color: AppColors.line),
            const SizedBox(height: 11),
            Row(
              children: [
                Avatar(initialsOf(card.executorName!)),
                const SizedBox(width: 9),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: card.executorName,
                          style: const TextStyle(
                            color: AppColors.text1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if ((card.executorCompleted ?? 0) > 0)
                          TextSpan(text: ' · ${card.executorCompleted} заказов'),
                      ],
                    ),
                    style: AppText.orderExec,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      ),
    );
  }
}
