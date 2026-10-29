import 'package:flutter/material.dart';

import '../data/api_exception.dart';

/// Текст ошибки запроса для пользователя. Раньше экраны печатали `'$e'` —
/// это сырой `ApiException(422): {json}`.
String apiErrorText(Object error) {
  if (error is ApiException) {
    return switch (error.statusCode) {
      // у 422 и 403 сервер пишет понятную причину — показываем её
      422 || 403 => error.userMessage,
      401 => 'Сессия истекла — войдите заново',
      // бекенд пишет причину по-русски («Новый код можно запросить через
      // 87 с.»); английский дефолт Laravel и пустой ответ — общей фразой
      429 => _isReadable(error.userMessage) && error.userMessage != 'Too Many Attempts.'
          ? error.userMessage
          : 'Слишком много запросов. Подождите немного и повторите',
      503 => _isReadable(error.userMessage)
          ? error.userMessage
          : 'Сервис временно недоступен, попробуйте позже',
      >= 500 => 'Ошибка на сервере, попробуйте позже',
      _ => error.userMessage,
    };
  }
  return 'Нет связи с сервером';
}

/// Сообщение сервера, а не сырое тело ответа.
bool _isReadable(String message) => message.isNotEmpty && !message.startsWith('{');

/// SnackBar с [apiErrorText] — стандартная реакция экрана на упавший запрос.
void showApiError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(apiErrorText(error))),
  );
}
