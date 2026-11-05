import 'dart:async';

import 'package:http/http.dart' as http;

/// Единственное место, где приложение ходит в сеть (бэклог №35): у каждого
/// запроса есть таймаут, иначе на плохой сети спиннер висел бесконечно.
/// Над ним — [ApiClient] (базовый адрес, токен, JSON, 401); напрямую
/// транспортом пользуются только те, кому `ApiClient` не подходит:
/// `AuthService` (от него зависит сам клиент) и гостевая витрина.
///
/// Клиент — `http.Client()` на каждый запрос, как у `http.get`: так тесты
/// подменяют сеть через `http.runWithClient`. Закрытие клиента по таймауту
/// обрывает соединение, а не оставляет его висеть.
///
/// Таймаут — `TimeoutException`; экраны показывают его как «Нет связи»
/// (`isNetworkError` в `widgets/api_error.dart`).
abstract final class HttpTransport {
  /// Обычный запрос: JSON туда и обратно.
  static const requestTimeout = Duration(seconds: 30);

  /// Загрузка файлов (multipart): фото до 10 МБ на медленной сети идёт
  /// минуты.
  static const uploadTimeout = Duration(minutes: 3);

  /// Отправить запрос и дочитать ответ — всё под одним таймаутом. Без
  /// [timeout] — [uploadTimeout] у multipart, [requestTimeout] у прочих.
  static Future<http.Response> send(
    http.BaseRequest request, {
    Duration? timeout,
  }) async {
    final limit =
        timeout ??
        (request is http.MultipartRequest ? uploadTimeout : requestTimeout);
    final client = http.Client();
    try {
      return await client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(limit);
    } finally {
      client.close();
    }
  }

  /// JSON-запрос: [body] — уже готовая строка или null. Как `http.post`:
  /// к заданному `Content-Type` добавится `charset=utf-8`.
  static Future<http.Response> request(
    String method,
    Uri uri, {
    Map<String, String> headers = const {},
    String? body,
    Duration? timeout,
  }) {
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = body;
    return send(request, timeout: timeout);
  }
}
