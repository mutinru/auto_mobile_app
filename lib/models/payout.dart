/// Реквизиты исполнителя для оплаты разового осмотра напрямую: карта и/или
/// телефон+банк для СБП (хотя бы одно). Заказчик видит их только в своём
/// заказе, пока идёт оплата; владелец — в GET /me.
class Payout {
  const Payout({this.card, this.phone, this.bank});

  /// Только цифры, без пробелов.
  final String? card;

  /// +79XXXXXXXXX.
  final String? phone;
  final String? bank;

  bool get hasCard => card != null && card!.isNotEmpty;
  bool get hasSbp => phone != null && phone!.isNotEmpty;

  /// «Карта •• 0009» / «СБП, Т-Банк» — короткая строка для профиля.
  String get shortLabel {
    if (hasCard) return 'Карта •• ${card!.substring(card!.length - 4)}';
    if (hasSbp) return bank != null ? 'СБП, $bank' : 'СБП';
    return 'не указаны';
  }

  /// «2200 7000 0000 0009» — по 4 цифры.
  String? get cardFormatted => card == null ? null : formatCard(card!);

  /// Поля запроса: отклик на осмотр и PATCH /me/payout.
  Map<String, dynamic> toJson() => {
        if (hasCard) 'payout_card': card,
        if (hasSbp) 'payout_phone': phone,
        if (hasSbp) 'payout_bank': bank,
      };

  factory Payout.fromJson(Map<String, dynamic> json) => Payout(
        card: json['card'] as String?,
        phone: json['phone'] as String?,
        bank: json['bank'] as String?,
      );
}

/// Цифры карты группами по 4.
String formatCard(String digits) {
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && i % 4 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return buf.toString();
}

/// Контрольная сумма номера карты (алгоритм Луна) — та же проверка, что на
/// бекенде (App\Support\PayoutDetails), чтобы не гонять заведомо неверный номер.
bool isValidCard(String input) {
  final digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 16 || digits.length > 19) return false;
  var sum = 0;
  for (var i = 0; i < digits.length; i++) {
    var d = int.parse(digits[digits.length - 1 - i]);
    if (i.isOdd) {
      d *= 2;
      if (d > 9) d -= 9;
    }
    sum += d;
  }
  return sum % 10 == 0;
}
