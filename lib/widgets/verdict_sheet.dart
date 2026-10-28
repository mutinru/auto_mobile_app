import 'package:flutter/material.dart';

import '../models/inspection_verdict.dart';
import '../models/order.dart';
import '../theme/app_colors.dart';
import 'app_ui.dart';

/// Лист завершения разового осмотра: вердикт и комментарий. Возвращает через
/// Navigator.pop пару (вердикт, комментарий?) или null, если лист закрыли.
class VerdictSheet extends StatefulWidget {
  const VerdictSheet({super.key, required this.order});
  final Order order;

  @override
  State<VerdictSheet> createState() => _VerdictSheetState();
}

class _VerdictSheetState extends State<VerdictSheet> {
  final _commentController = TextEditingController();
  InspectionVerdict? _verdict;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 22,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Итог осмотра',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.colors.text1,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${widget.order.carTitle} · отчёт увидит заказчик',
              style: TextStyle(fontSize: 11.5, color: context.colors.text2),
            ),
          ),
          const SizedBox(height: 14),
          for (final v in InspectionVerdict.values)
            _VerdictOption(
              verdict: v,
              selected: _verdict == v,
              onTap: () => setState(() => _verdict = v),
            ),
          const SizedBox(height: 4),
          FieldBoxInput(
            label: 'Комментарий',
            controller: _commentController,
            hint: 'Что нашли, на что обратить внимание',
            maxLines: 3,
            minHeight: 72,
          ),
          const SizedBox(height: 6),
          CtaPrimary(
            label: 'Отправить отчёт',
            onPressed: _verdict == null
                ? null
                : () {
                    final comment = _commentController.text.trim();
                    Navigator.of(
                      context,
                    ).pop((_verdict!, comment.isEmpty ? null : comment));
                  },
          ),
        ],
      ),
    );
  }
}

/// Строка выбора вердикта — иконка и цвет из [InspectionVerdictX].
class _VerdictOption extends StatelessWidget {
  const _VerdictOption({
    required this.verdict,
    required this.selected,
    required this.onTap,
  });

  final InspectionVerdict verdict;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = verdict.color(context.colors);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.10)
                : context.colors.bg1,
            border: Border.all(
              color: selected
                  ? color.withValues(alpha: 0.55)
                  : context.colors.line,
            ),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(verdict.icon, size: 15, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  verdict.label,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? color : context.colors.text1,
                  ),
                ),
              ),
              if (selected) Icon(Icons.check, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
