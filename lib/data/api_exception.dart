import 'dart:convert';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);

  final int statusCode;

  /// Сырое тело ответа — у Laravel это JSON, показывать его как есть нельзя.
  final String message;

  /// Строка для пользователя: первая ошибка валидации (`errors.<поле>[0]`),
  /// иначе `message` из JSON, иначе тело как есть.
  String get userMessage {
    try {
      final json = jsonDecode(message);
      if (json is Map<String, dynamic>) {
        final errors = json['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final first = errors.values.first;
          if (first is List && first.isNotEmpty) return '${first.first}';
        }
        final text = json['message'];
        if (text is String && text.isNotEmpty) return text;
      }
    } on FormatException {
      // не JSON — отдаём как есть
    }
    return message;
  }

  /// Ошибки валидации 422 по полям: `{payout_card: 'Проверьте номер карты.'}`.
  /// Пусто, если ответ не 422 или не JSON.
  Map<String, String> get fieldErrors {
    try {
      final json = jsonDecode(message);
      final errors = json is Map<String, dynamic> ? json['errors'] : null;
      if (errors is Map) {
        return {
          for (final e in errors.entries)
            if (e.value is List && (e.value as List).isNotEmpty) '${e.key}': '${(e.value as List).first}',
        };
      }
    } on FormatException {
      // не JSON — ошибок по полям нет
    }
    return const {};
  }

  /// Через сколько секунд повторить — `retry_after` у ответа 429 (и отказ
  /// лимита кода входа, и любой лимитер бекенда). null, если поля нет.
  int? get retryAfter {
    try {
      final json = jsonDecode(message);
      final value = json is Map<String, dynamic> ? json['retry_after'] : null;
      return value is num ? value.toInt() : null;
    } on FormatException {
      return null;
    }
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}
