import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/order.dart';
import '../models/payout.dart';
import '../models/report_summary.dart';
import '../theme/app_colors.dart';
import '../util/ru_plural.dart';
import 'app_ui.dart';
import 'support_sheet.dart';

/// Блоки разового осмотра между «отчёт готов» и получением отчёта: сумма и
/// реквизиты, сводка, спор. Рамка — как у InspectionVerdictBox.
class _Box extends StatelessWidget {
  const _Box({required this.child, this.accent});

  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: context.colors.bg1,
        border: Border.all(
          color: accent?.withValues(alpha: 0.35) ?? context.colors.line,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: child,
    );
  }
}

/// Сумма к оплате и реквизиты исполнителя с кнопками «скопировать».
class PayoutBlock extends StatelessWidget {
  const PayoutBlock({super.key, required this.price, required this.payout});

  final int? price;
  final Payout payout;

  @override
  Widget build(BuildContext context) {
    return _Box(
      accent: context.colors.statusProgress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('К ОПЛАТЕ', style: context.text.fieldLabel),
          const SizedBox(height: 4),
          Text(
            price == null ? '—' : '${money(price!)} ₽',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.5,
              color: context.colors.text1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Переведите напрямую исполнителю — платформа деньги не принимает.',
            style: TextStyle(fontSize: 11.5, color: context.colors.text2, height: 1.4),
          ),
          if (payout.hasCard)
            _CopyRow(label: 'Карта', value: payout.cardFormatted!, copy: payout.card!),
          if (payout.hasSbp)
            _CopyRow(
              label: payout.bank == null ? 'СБП' : 'СБП · ${payout.bank}',
              value: payout.phone!,
              copy: payout.phone!,
            ),
        ],
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value, required this.copy});

  final String label;
  final String value;
  final String copy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(), style: context.text.fieldLabel),
                const SizedBox(height: 3),
                Text(value, style: context.text.fieldMono),
              ],
            ),
          ),
          SquareIconButton(
            icon: Icons.copy_rounded,
            onTap: () {
              Clipboard.setData(ClipboardData(text: copy));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label скопирован${label == 'Карта' ? 'а' : ''}')),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// «Осмотрено 13 из 13 деталей · 2 дефекта · 5 фото» — без вердикта.
class ReportSummaryBox extends StatelessWidget {
  const ReportSummaryBox({super.key, required this.summary});

  final ReportSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    return _Box(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, size: 18, color: context.colors.text2),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Осмотрено ${s.panelsInspected} из ${s.panelsTotal} '
                  '${plural(s.panelsTotal, 'детали', 'деталей', 'деталей')} · '
                  '${counted(s.defectsCount, 'дефект', 'дефекта', 'дефектов')} · '
                  '${s.photosCount} фото',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: context.colors.text1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Полный отчёт и вердикт откроются, когда исполнитель подтвердит оплату.',
                  style: TextStyle(fontSize: 11.5, color: context.colors.text2, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Открытый спор: кто, когда, причина, и выход в поддержку.
class DisputeBox extends StatelessWidget {
  const DisputeBox({super.key, required this.order, required this.viewerId});

  final Order order;
  final int? viewerId;

  @override
  Widget build(BuildContext context) {
    final dispute = order.dispute;
    final who = dispute == null
        ? null
        : dispute.openedBy == viewerId
            ? 'Вы открыли спор'
            : dispute.openedBy == order.customer.id
                ? 'Заказчик открыл спор'
                : 'Исполнитель открыл спор';

    return _Box(
      accent: context.colors.statusDefect,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            who ?? 'Открыт спор',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: context.colors.statusDefect,
            ),
          ),
          if (dispute != null && dispute.reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              dispute.reason,
              style: TextStyle(fontSize: 12, color: context.colors.text1, height: 1.4),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Поддержка разберётся с обеими сторонами. Отчёт откроется, если '
            'оплата подтвердится.',
            style: TextStyle(fontSize: 11.5, color: context.colors.text2, height: 1.4),
          ),
          const SizedBox(height: 8),
          CtaFlat(
            label: 'Написать в поддержку',
            icon: Icons.chat_bubble_outline_rounded,
            onPressed: () => showSupportSheet(context),
          ),
        ],
      ),
    );
  }
}

/// Плашка-подсказка в тон статуса: «Ждём, пока исполнитель подтвердит оплату».
class StatusNote extends StatelessWidget {
  const StatusNote({super.key, required this.text, this.icon = Icons.hourglass_empty_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _Box(
      accent: context.colors.statusProgress,
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.colors.statusProgress),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: context.colors.text1, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
