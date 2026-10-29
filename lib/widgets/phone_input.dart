import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Отсчёт до повторного запроса: `1:47`.
String formatCountdown(Duration left) {
  final seconds = left.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

/// `+79001234567` → `+7 900 123 45 67`; не российский номер — как есть.
String formatPhone(String phone) {
  final match = RegExp(r'^\+7(\d{3})(\d{3})(\d{2})(\d{2})$').firstMatch(phone);
  if (match == null) return phone;
  return '+7 ${match[1]} ${match[2]} ${match[3]} ${match[4]}';
}

/// .phone-input из макета: «RU +7 | поле» с маской [PhoneMask]. Общий для
/// входа и смены номера в профиле.
class PhoneField extends StatelessWidget {
  const PhoneField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.bg1,
        border: Border.all(color: context.colors.line),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Text(
            'RU +7',
            style: TextStyle(fontSize: 13, color: context.colors.text2),
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 20, color: context.colors.line),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              enabled: enabled,
              autofocus: autofocus,
              inputFormatters: const [PhoneMask()],
              style: TextStyle(
                fontFamily: AppTheme.monoFamily,
                fontSize: 15,
                letterSpacing: 0.6,
                color: context.colors.text1,
              ),
              cursorColor: context.colors.statusDone,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(vertical: 13),
                border: InputBorder.none,
                hintText: '000 000 00 00',
                hintStyle: TextStyle(
                  fontFamily: AppTheme.monoFamily,
                  fontSize: 15,
                  color: context.colors.text3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Маска телефона: цифры складываются в «XXX XXX XX XX» прямо во время
/// ввода и обрезаются на десятой — больше в российский номер не влезает.
class PhoneMask extends TextInputFormatter {
  const PhoneMask();

  static const _groups = [3, 3, 2, 2];

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 10 ? digits.substring(0, 10) : digits;

    // сколько цифр стояло слева от курсора — по ним вернём его на место
    final digitsBeforeCursor = newValue.text
        .substring(0, newValue.selection.baseOffset.clamp(0, newValue.text.length))
        .replaceAll(RegExp(r'\D'), '')
        .length;

    final buf = StringBuffer();
    var consumed = 0;
    var cursor = 0;
    for (final size in _groups) {
      if (consumed >= capped.length) break;
      if (consumed > 0) buf.write(' ');
      final end = (consumed + size).clamp(0, capped.length);
      buf.write(capped.substring(consumed, end));
      consumed = end;
      if (digitsBeforeCursor >= consumed) cursor = buf.length;
    }

    final text = buf.toString();
    final offset = digitsBeforeCursor >= capped.length ? text.length : cursor;

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset.clamp(0, text.length)),
    );
  }
}
