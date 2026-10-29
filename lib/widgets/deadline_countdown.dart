import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// «Осталось 5 ч 12 мин» до [deadline] — 24 часа исполнителя разового
/// осмотра. Сам срок отрабатывает сервер: по нулю тут только надпись.
class DeadlineCountdown extends StatefulWidget {
  const DeadlineCountdown({super.key, required this.deadline, this.prefix = 'Осталось'});

  final DateTime deadline;
  final String prefix;

  /// «5 ч 12 мин» / «12 мин» / null, если срок вышел.
  static String? remainingLabel(DateTime deadline, DateTime now) {
    final left = deadline.difference(now);
    if (left.isNegative || left == Duration.zero) return null;
    final hours = left.inHours;
    // округляем вверх: «0 мин» при оставшихся 40 секундах читается как «уже всё»
    final minutes = (left.inSeconds - hours * 3600 + 59) ~/ 60;
    if (hours == 0) return '$minutes мин';
    return '$hours ч ${minutes.toString().padLeft(2, '0')} мин';
  }

  @override
  State<DeadlineCountdown> createState() => _DeadlineCountdownState();
}

class _DeadlineCountdownState extends State<DeadlineCountdown> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = DeadlineCountdown.remainingLabel(widget.deadline, DateTime.now());
    final urgent = widget.deadline.difference(DateTime.now()) < const Duration(hours: 3);
    final color = label == null || urgent ? context.colors.statusDefect : context.colors.statusProgress;
    final at = widget.deadline;
    final time = '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.timer_outlined, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label == null ? 'Срок осмотра вышел' : '${widget.prefix} $label · до $time',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
