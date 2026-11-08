import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'phone_input.dart';

/// Набрать номер: открывает звонилку с подставленным номером. Нет
/// звонилки (планшет, эмулятор без телефонии) — сообщение внизу экрана.
Future<void> callPhone(BuildContext context, String phone) async {
  final messenger = ScaffoldMessenger.of(context);
  var ok = false;
  try {
    ok = await launchUrl(Uri(scheme: 'tel', path: phone));
  } catch (_) {
    ok = false;
  }
  if (!ok) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Не удалось открыть звонилку — ${formatPhone(phone)}'),
      ),
    );
  }
}

/// Строка телефона другой стороны в карточке: подпись, номер и
/// «Позвонить». Сверху — разделитель, как у телефона продавца.
class PhoneCallRow extends StatelessWidget {
  const PhoneCallRow({super.key, required this.label, required this.phone});

  final String label;
  final String phone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        const SizedBox(height: 11),
        Container(height: 1, color: c.line),
        const SizedBox(height: 11),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11.5, color: c.text2)),
                  const SizedBox(height: 2),
                  Text(
                    formatPhone(phone),
                    style: TextStyle(
                      fontFamily: AppTheme.monoFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.text1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              onPressed: () => callPhone(context, phone),
              icon: const Icon(Icons.call, size: 16),
              label: const Text('Позвонить'),
              style: ElevatedButton.styleFrom(
                backgroundColor: c.modeBuy,
                foregroundColor: c.modeBuyInk,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Предупреждение об обмене номерами в подборе: до выбора исполнителя у
/// заказчика и в отклике у исполнителя — номер открывается не молча.
class PhoneExchangeNote extends StatelessWidget {
  const PhoneExchangeNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.infoSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.phone_outlined, size: 16, color: c.infoText),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, height: 1.4, color: c.text1),
            ),
          ),
        ],
      ),
    );
  }
}
