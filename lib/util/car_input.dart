/// Ввод данных машины: форматтеры полей и проверки до отправки — те же
/// границы, что на бекенде.
library;

import 'package:flutter/services.dart';

import 'money.dart';

/// Числовые поля (год, пробег): только цифры — иначе «120.000» молча
/// превратится в null у `int.tryParse` и уйдёт пустым.
final digitsOnly = <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly];

/// Год выпуска — те же границы, что на бекенде (1990 … следующий год).
/// null — год в порядке.
String? yearProblem(int year, {DateTime? now}) {
  final max = (now ?? DateTime.now()).year + 1;
  if (year < 1990 || year > max) return 'Год — от 1990 до $max';
  return null;
}

/// Потолок пробега — ручное зеркало `OrderController::MAX_MILEAGE` на
/// бекенде: и «Пробег до» подбора, и пробег со слов продавца, и одометр.
const maxMileageKm = 2000000;

/// Пробег за потолком сервера — текст ошибки до отправки (QA №19).
String? mileageProblem(int km) =>
    km > maxMileageKm ? 'Пробег — не больше ${money(maxMileageKm)} км' : null;

/// VIN: ровно 17 знаков, только заглавные латинские и цифры.
/// Буквы I, O и Q в VIN не используются — их легко спутать с 1 и 0,
/// поэтому отсекаем сразу, а не ловим потом ошибкой сервера.
class VinFormatter extends TextInputFormatter {
  const VinFormatter();

  static final _allowed = RegExp(r'[A-HJ-NPR-Z0-9]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleaned = newValue.text
        .toUpperCase()
        .split('')
        .where(_allowed.hasMatch)
        .join();
    final capped = cleaned.length > 17 ? cleaned.substring(0, 17) : cleaned;

    return TextEditingValue(
      text: capped,
      selection: TextSelection.collapsed(offset: capped.length),
    );
  }
}

/// Номер кузова: латиница, цифры и дефис, верхний регистр, до 17 знаков.
class BodyNumberFormatter extends TextInputFormatter {
  const BodyNumberFormatter();

  static final _allowed = RegExp(r'[A-Z0-9-]');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final cleaned = newValue.text
        .toUpperCase()
        .split('')
        .where(_allowed.hasMatch)
        .join();
    final capped = cleaned.length > 17 ? cleaned.substring(0, 17) : cleaned;

    return TextEditingValue(
      text: capped,
      selection: TextSelection.collapsed(offset: capped.length),
    );
  }
}
