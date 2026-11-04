import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../data/api_exception.dart';

const networkErrorText = 'Нет связи с сервером. Проверьте интернет и повторите';
const unexpectedErrorText =
    'Не удалось обработать ответ сервера. Обновите приложение или повторите позже';

/// Запрос не дошёл до сервера или ответ не пришёл: обрыв, нет сети, TLS,
/// таймаут. Распознаём по типу — транспорт в приложении не один
/// (ApiClient, прямые http.*, multipart), а экраны все идут через
/// [apiErrorText]. IOClient заворачивает SocketException в ClientException.
bool isNetworkError(Object error) =>
    error is http.ClientException ||
    error is SocketException ||
    error is HandshakeException ||
    error is TimeoutException;

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
      429 =>
        _isReadable(error.userMessage) &&
                error.userMessage != 'Too Many Attempts.'
            ? error.userMessage
            : 'Слишком много запросов. Подождите немного и повторите',
      503 =>
        _isReadable(error.userMessage)
            ? error.userMessage
            : 'Сервис временно недоступен, попробуйте позже',
      >= 500 => 'Ошибка на сервере, попробуйте позже',
      _ => error.userMessage,
    };
  }
  if (isNetworkError(error)) return networkErrorText;
  // сервер ответил, но приложение ответа не поняло (TypeError при разборе,
  // FormatException…): это не сеть — честно говорим и пишем причину в лог,
  // иначе её ищут не там (так было с годом кандидата строкой, QA №1)
  debugPrint('apiErrorText: ${error.runtimeType}: $error');
  return unexpectedErrorText;
}

/// Сообщение сервера, а не сырое тело ответа.
bool _isReadable(String message) =>
    message.isNotEmpty && !message.startsWith('{');

/// SnackBar с [apiErrorText] — стандартная реакция экрана на упавший запрос.
void showApiError(BuildContext context, Object error) {
  // дольше стандартных 4 с и с крестиком — ошибку успевают прочитать
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(apiErrorText(error)),
      duration: const Duration(seconds: 6),
      showCloseIcon: true,
    ),
  );
}
