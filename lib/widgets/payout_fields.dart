import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/payout.dart';
import '../theme/app_colors.dart';
import 'app_sheet.dart';
import 'app_ui.dart';

/// Состояние формы реквизитов: способ (карта / СБП), поля и ошибки —
/// свои и пришедшие с сервера. Общий для формы отклика и листа в профиле.
class PayoutFormController extends ChangeNotifier {
  PayoutFormController({Payout? initial})
      : useCard = initial == null || initial.hasCard || !initial.hasSbp,
        card = TextEditingController(text: initial?.cardFormatted ?? ''),
        phone = TextEditingController(text: initial?.phone ?? ''),
        bank = TextEditingController(text: initial?.bank ?? '');

  bool useCard;
  final TextEditingController card;
  final TextEditingController phone;
  final TextEditingController bank;

  /// Ключи — имена полей бекенда (payout_card, payout_phone, payout_bank).
  Map<String, String> errors = const {};

  void setMode({required bool card}) {
    useCard = card;
    errors = const {};
    notifyListeners();
  }

  /// Ошибки 422 с сервера ([ApiException.fieldErrors]) — только payout_*.
  void setServerErrors(Map<String, String> fieldErrors) {
    errors = {
      for (final e in fieldErrors.entries)
        if (e.key.startsWith('payout_')) e.key: e.value,
    };
    notifyListeners();
  }

  /// Реквизиты из полей или null, если что-то не так (ошибки — в [errors]).
  /// Проверки те же, что на бекенде: карта — 16–19 цифр и Луна, СБП —
  /// мобильный +79 и банк.
  Payout? validate() {
    final found = <String, String>{};
    Payout? result;
    if (useCard) {
      final digits = card.text.replaceAll(RegExp(r'\D'), '');
      if (!isValidCard(digits)) {
        found['payout_card'] = 'Проверьте номер карты';
      } else {
        result = Payout(card: digits);
      }
    } else {
      final normalized = _normalizePhone(phone.text);
      if (!RegExp(r'^\+79\d{9}$').hasMatch(normalized)) {
        found['payout_phone'] = 'Введите номер в формате +7 9XX XXX XX XX';
      }
      if (bank.text.trim().isEmpty) {
        found['payout_bank'] = 'Укажите банк для СБП';
      }
      if (found.isEmpty) result = Payout(phone: normalized, bank: bank.text.trim());
    }
    errors = found;
    notifyListeners();
    return result;
  }

  @override
  void dispose() {
    card.dispose();
    phone.dispose();
    bank.dispose();
    super.dispose();
  }

  /// 8 900… и 9 00… → +79…, как App\Support\Phone::normalize на бекенде.
  static String _normalizePhone(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('8')) digits = '7${digits.substring(1)}';
    if (!digits.startsWith('7')) digits = '7$digits';
    return '+$digits';
  }
}

/// Поля реквизитов: переключатель «Карта / СБП» и нужные поля под ним.
class PayoutFields extends StatelessWidget {
  const PayoutFields({super.key, required this.controller});

  final PayoutFormController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                AppChip(
                  label: 'Карта',
                  on: controller.useCard,
                  onTap: () => controller.setMode(card: true),
                ),
                const SizedBox(width: 8),
                AppChip(
                  label: 'СБП по телефону',
                  on: !controller.useCard,
                  onTap: () => controller.setMode(card: false),
                ),
              ],
            ),
          ),
          if (controller.useCard) ...[
            FieldBoxInput(
              label: 'Номер карты',
              controller: controller.card,
              hint: '2200 0000 0000 0000',
              mono: true,
              keyboardType: TextInputType.number,
              inputFormatters: const [CardNumberFormatter()],
            ),
            SheetError(controller.errors['payout_card']),
          ] else ...[
            FieldBoxInput(
              label: 'Телефон для СБП',
              controller: controller.phone,
              hint: '+7 900 000-00-00',
              mono: true,
              keyboardType: TextInputType.phone,
              maxLength: 18,
            ),
            SheetError(controller.errors['payout_phone']),
            FieldBoxInput(
              label: 'Банк',
              controller: controller.bank,
              hint: 'Т-Банк, Сбербанк…',
              maxLength: 100,
            ),
            SheetError(controller.errors['payout_bank']),
          ],
          Text(
            'Заказчик увидит реквизиты только после того, как вы закончите осмотр.',
            style: TextStyle(fontSize: 11.5, color: context.colors.text3, height: 1.4),
          ),
        ],
      ),
    );
  }
}

/// Цифры карты группами по 4, не больше 19 цифр.
class CardNumberFormatter extends TextInputFormatter {
  const CardNumberFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 19) digits = digits.substring(0, 19);
    final text = formatCard(digits);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
