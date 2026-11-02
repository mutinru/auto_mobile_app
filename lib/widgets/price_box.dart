import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_ui.dart';

/// .price-box — сумма со степпером ±. Сумму можно вписать по тапу, ± —
/// подстройка: шаг растёт с суммой, удержание кнопки листает дальше.
/// Общий для нового осмотра, отклика и переноса осмотра.
class PriceBox extends StatefulWidget {
  const PriceBox({super.key, required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  /// Границы те же, что на бекенде (`OrderController::MIN_PRICE`/`MAX_PRICE`).
  static const minPrice = 500;
  static const maxPrice = 1000000;

  /// Шаг ±: торг на осмотре идёт сотнями, на подборе — тысячами.
  static int stepFor(int value) {
    if (value < 5000) return 100;
    if (value < 20000) return 500;
    return 1000;
  }

  /// Следующая отметка сетки шага: 4 250 → 4 300, 4 900 → 5 000 → 5 500.
  static int stepUp(int value) {
    final step = stepFor(value);
    return ((value ~/ step) + 1) * step;
  }

  /// Предыдущая отметка: шаг берётся снизу, чтобы 5 000 → 4 900, а 20 000 → 19 500.
  static int stepDown(int value) {
    final step = stepFor(value - 1);
    return ((value - 1) ~/ step) * step;
  }

  /// Проверка перед отправкой; null — сумма в порядке.
  static String? problem(int value) {
    if (value < minPrice) return 'Цена — от ${money(minPrice)} ₽';
    if (value > maxPrice) return 'Цена — до ${money(maxPrice)} ₽';
    return null;
  }

  @override
  State<PriceBox> createState() => _PriceBoxState();
}

class _PriceBoxState extends State<PriceBox> {
  late final _controller = TextEditingController(text: money(widget.value));
  final _focus = FocusNode();
  Timer? _repeat;

  /// Текущее значение: во время удержания оно убегает вперёд от widget.value
  /// на кадр, поэтому держим своё.
  late int _value = widget.value;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      // набор закончен — прижимаем к границам и переписываем красиво
      if (!_focus.hasFocus) {
        _set(_value.clamp(PriceBox.minPrice, PriceBox.maxPrice));
      }
    });
  }

  @override
  void didUpdateWidget(PriceBox old) {
    super.didUpdateWidget(old);
    // снаружи пришла другая сумма (сброс к цене заказчика) — показываем её;
    // своё же число, только что набранное, поле не перетирает
    if (widget.value != _value) {
      _value = widget.value;
      _controller.text = money(_value);
    }
  }

  @override
  void dispose() {
    _repeat?.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _set(int value) {
    _value = value;
    final text = money(value);
    if (_controller.text != text) _controller.text = text;
    widget.onChanged(value);
    setState(() {});
  }

  bool get _canDown => _value > PriceBox.minPrice;
  bool get _canUp => _value < PriceBox.maxPrice;

  void _down() {
    if (!_canDown) return _stopRepeat();
    _set(PriceBox.stepDown(_value).clamp(PriceBox.minPrice, PriceBox.maxPrice));
  }

  void _up() {
    if (!_canUp) return _stopRepeat();
    _set(PriceBox.stepUp(_value).clamp(PriceBox.minPrice, PriceBox.maxPrice));
  }

  void _startRepeat(VoidCallback step) {
    _repeat?.cancel();
    _repeat = Timer.periodic(const Duration(milliseconds: 90), (_) => step());
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  void _typed(String text) {
    final digits = text.replaceAll(' ', '');
    _value = digits.isEmpty ? 0 : int.parse(digits);
    widget.onChanged(_value);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: AppTheme.monoFamily,
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.66,
      color: context.colors.text1,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: context.colors.bg1,
        border: Border.all(color: context.colors.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                // поле по ширине суммы, «₽» сразу за ней, как в макете
                IntrinsicWidth(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [MoneyInputFormatter()],
                    onChanged: _typed,
                    onSubmitted: (_) => _focus.unfocus(),
                    style: style,
                    cursorColor: context.colors.statusDone,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                    ),
                  ),
                ),
                Text(' ₽', style: style),
              ],
            ),
          ),
          _PriceStep(
            icon: Icons.remove,
            onTap: _canDown ? _down : null,
            onHoldStart: () => _startRepeat(_down),
            onHoldEnd: _stopRepeat,
          ),
          const SizedBox(width: 6),
          _PriceStep(
            icon: Icons.add,
            onTap: _canUp ? _up : null,
            onHoldStart: () => _startRepeat(_up),
            onHoldEnd: _stopRepeat,
          ),
        ],
      ),
    );
  }
}

/// Сумма при наборе: только цифры, не больше 7 знаков (до 1 000 000 ₽),
/// с пробелами между разрядами. Курсор — в конец: сумму правят с хвоста.
class MoneyInputFormatter extends TextInputFormatter {
  const MoneyInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    digits = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (digits.length > 7) digits = digits.substring(0, 7);
    final text = digits.isEmpty ? '' : money(int.parse(digits));
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

class _PriceStep extends StatelessWidget {
  const _PriceStep({
    required this.icon,
    required this.onTap,
    required this.onHoldStart,
    required this.onHoldEnd,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback onHoldStart;
  final VoidCallback onHoldEnd;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      // удержание листает сумму, пока палец на кнопке
      onLongPressStart: enabled ? (_) => onHoldStart() : null,
      onLongPressEnd: enabled ? (_) => onHoldEnd() : null,
      onLongPressCancel: enabled ? onHoldEnd : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: context.colors.bg3,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          icon,
          size: 14,
          color: enabled ? context.colors.text1 : context.colors.text3,
        ),
      ),
    );
  }
}

/// «Вернуть цену заказчика · 4 000 ₽» под [PriceBox] — один тап к исходной сумме.
class PriceResetLink extends StatelessWidget {
  const PriceResetLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          child: Text(
            label,
            style: context.text.orderMeta.copyWith(
              color: context.colors.statusDone,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
