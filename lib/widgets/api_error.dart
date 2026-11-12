import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../data/api_exception.dart';
import '../data/http_transport.dart';

const networkErrorText = 'Нет связи с сервером. Проверьте интернет и повторите';
const unexpectedErrorText =
    'Не удалось обработать ответ сервера. Обновите приложение или повторите позже';

/// Сервер отказал, но причину не написал (пустое тело, HTML-страница nginx).
const requestFailedText = 'Не удалось выполнить запрос. Повторите позже';

/// Запрос не дошёл до сервера или ответ не пришёл: обрыв, нет сети, TLS,
/// таймаут ([HttpTransport] — 30 с, загрузки — 3 мин). Распознаём по типу:
/// IOClient заворачивает SocketException в ClientException.
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
      422 || 403 when _isReadable(error.userMessage) => error.userMessage,
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
      // пустой ответ или HTML (nginx 413 до Laravel) — не на экран
      _ =>
        _isReadable(error.userMessage) ? error.userMessage : requestFailedText,
    };
  }
  if (isNetworkError(error)) return networkErrorText;
  // сервер ответил, но приложение ответа не поняло (TypeError при разборе,
  // FormatException…): это не сеть — честно говорим и пишем причину в лог,
  // иначе её ищут не там (так было с годом кандидата строкой, QA №1)
  debugPrint('apiErrorText: ${error.runtimeType}: $error');
  return unexpectedErrorText;
}

/// Сообщение сервера, а не сырое тело ответа: не пустое, не JSON и не HTML.
bool _isReadable(String message) {
  final text = message.trimLeft();
  return text.isNotEmpty && !text.startsWith('{') && !text.startsWith('<');
}

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
