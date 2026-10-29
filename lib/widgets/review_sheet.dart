import 'package:flutter/material.dart';

import '../models/order.dart';
import '../models/review.dart';
import '../theme/app_colors.dart';
import '../util/ru_date.dart';
import 'api_error.dart';
import 'app_ui.dart';

/// Лист отзыва об исполнителе. Макета под него нет — собран из тех же
/// кирпичей, что лист смены имени. Отправка передаётся снаружи (в
/// приложении это OrderStore.leaveReview / updateReview), чтобы лист
/// можно было проверить без сети. [initial] — правка существующего отзыва.
Future<void> showReviewSheet(
  BuildContext context, {
  required Order order,
  Review? initial,
  required Future<void> Function(int rating, String? text) onSubmit,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.colors.bg0,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (context) =>
        ReviewSheet(order: order, initial: initial, onSubmit: onSubmit),
  );
}

class ReviewSheet extends StatefulWidget {
  const ReviewSheet({
    super.key,
    required this.order,
    required this.onSubmit,
    this.initial,
  });

  final Order order;
  final Review? initial;
  final Future<void> Function(int rating, String? text) onSubmit;

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  /// Совпадают с правилами бекенда (ReviewController::validated).
  static const _maxLength = 2000;
  static const _minLowText = 10;

  late final _controller = TextEditingController(text: widget.initial?.text ?? '');
  late int _rating = widget.initial?.rating ?? 0;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _trimmed => _controller.text.trim();

  /// При оценке 1–2 без объяснения отзыв бесполезен — сервер требует текст.
  bool get _needsText => _rating > 0 && _rating <= 2;

  bool get _canSave =>
      _rating > 0 && (!_needsText || _trimmed.length >= _minLowText);

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSubmit(_rating, _trimmed.isEmpty ? null : _trimmed);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      // лист не закрываем, чтобы не потерять ввод; без сети apiErrorText
      // отдаст «Нет связи с сервером»
      if (mounted) setState(() => _error = apiErrorText(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.initial != null;
    final executor = widget.order.executor;

    return Padding(
      // лист поднимается над клавиатурой
      padding: EdgeInsets.fromLTRB(
        22,
        12,
        22,
        22 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // .sheet-handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: context.colors.bg3,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            editing ? 'Изменить отзыв' : 'Оцените исполнителя',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.34,
              color: context.colors.text1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            [
              if (executor != null) executor.name,
              widget.order.carTitle,
            ].join(' · '),
            style: TextStyle(fontSize: 12, color: context.colors.text2),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  key: ValueKey('review-star-$i'),
                  onPressed: _saving ? null : () => setState(() => _rating = i),
                  iconSize: 36,
                  icon: Icon(
                    i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: i <= _rating
                        ? context.colors.statusProgress
                        : context.colors.text3,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          FieldBoxInput(
            label: 'Отзыв',
            controller: _controller,
            hint: _needsText ? 'Что пошло не так' : 'Что понравилось — по желанию',
            maxLines: 4,
            minHeight: 96,
            maxLength: _maxLength,
          ),
          if (_needsText && _error == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'При оценке 1–2 опишите, что пошло не так',
                style: TextStyle(fontSize: 12, color: context.colors.text2),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                _error!,
                style: TextStyle(fontSize: 12, color: context.colors.statusDefect),
              ),
            ),
          const SizedBox(height: 4),
          CtaPrimary(
            label: editing ? 'Сохранить' : 'Отправить',
            loading: _saving,
            onPressed: _canSave ? _save : null,
          ),
          if (editing)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Изменить можно до ${editableUntilLabel(widget.initial!)}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11.5, color: context.colors.text3),
              ),
            ),
        ],
      ),
    );
  }
}

/// «29 октября, 14:05».
String editableUntilLabel(Review review) {
  final t = review.editableUntil;
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '${dayMonth(t)}, $hh:$mm';
}
