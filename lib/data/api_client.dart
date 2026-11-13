import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_exception.dart';
import 'auth_service.dart';
import 'http_transport.dart';
import 'idempotency_keys.dart';

/// Обёртка над [HttpTransport]: базовый URL, Bearer-токен из
/// [AuthService], декодирование JSON и единая обработка ошибок — в том
/// числе у загрузки файлов ([multipart]). Таймауты — в транспорте.
///
/// Каждая мутация несёт `Idempotency-Key` (ревью №17, [IdempotencyKeys]):
/// повтор после обрыва связи сервер не выполнит второй раз. Вызывающим
/// ничего делать не нужно — ключ подбирается по самому запросу.
class ApiClient {
  ApiClient(this._auth, {IdempotencyKeys? keys})
    : _keys = keys ?? IdempotencyKeys.instance;

  final AuthService _auth;
  final IdempotencyKeys _keys;

  /// Токен для заголовков картинок чата (`ChatRepository.imageHeaders`).
  String? get token => _auth.token;

  Map<String, String> get _headers => {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (_auth.token != null) 'Authorization': 'Bearer ${_auth.token}',
  };

  /// Ошибка ответа; на 401 заодно стирает сессию — корень уведёт на вход.
  ApiException failure(int statusCode, String body) {
    if (statusCode == 401) _auth.expireSession();
    return ApiException(statusCode, body);
  }

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  // ensureUser: после офлайн-старта профиль догружается до запроса экрана,
  // иначе экран не узнает в пользователе исполнителя

  Future<Map<String, dynamic>> get(String path) async {
    await _auth.ensureUser();
    final response = await HttpTransport.request(
      'GET',
      _uri(path),
      headers: _headers,
    );
    return _decode(response);
  }

  /// GET с If-None-Match: null — ресурс не изменился (304), вызывающий
  /// берёт свою копию. Для статичных справочников вроде /defects.
  Future<({Map<String, dynamic> json, String? etag})?> getIfChanged(
    String path, {
    String? etag,
  }) async {
    await _auth.ensureUser();
    final response = await HttpTransport.request(
      'GET',
      _uri(path),
      headers: {..._headers, 'If-None-Match': ?etag},
    );
    if (response.statusCode == 304) return null;
    return (json: _decode(response), etag: response.headers['etag']);
  }

  Future<Map<String, dynamic>> patch(
    String path,
    Map<String, dynamic> body,
  ) => _mutate('PATCH', path, jsonEncode(body));

  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) => _mutate('POST', path, body == null ? null : jsonEncode(body));

  Future<Map<String, dynamic>> put(
    String path, [
    Map<String, dynamic>? body,
  ]) => _mutate('PUT', path, body == null ? null : jsonEncode(body));

  Future<Map<String, dynamic>> delete(String path) =>
      _mutate('DELETE', path, null);

  /// Мутация JSON с ключом повтора ([IdempotencyKeys]): ответ не пришёл —
  /// следующая такая же отправка уйдёт с тем же ключом, и сервер не
  /// выполнит её второй раз. «Ещё выполняется» (409) — ждём и спрашиваем
  /// снова тем же ключом.
  Future<Map<String, dynamic>> _mutate(
    String method,
    String path,
    String? body,
  ) async {
    await _auth.ensureUser();
    final signature = IdempotencyKeys.signature(
      userId: _auth.user?.id,
      method: method,
      path: path,
      body: body,
    );
    final key = await _keys.keyFor(signature);
    for (var attempt = 1; ; attempt++) {
      final response = await HttpTransport.request(
        method,
        _uri(path),
        headers: {..._headers, IdempotencyKeys.header: key},
        body: body,
      );
      if (_inProgress(response) && attempt < inProgressAttempts) {
        await Future<void>.delayed(_retryAfter(response));
        continue;
      }
      await _settle(signature, response);
      return _decode(response);
    }
  }

  /// Загрузка файлов: поля и файлы формой, ответ — JSON, ошибки — как у
  /// [post] (401 стирает сессию, 422 ложатся на поля через
  /// [ApiException.fieldErrors]). Таймаут — [HttpTransport.uploadTimeout].
  /// Ключ повтора — как у [post]; на 409 не ждёт: поток файла не
  /// перечитать, повторит вызывающий (кнопка, очередь осмотра) тем же
  /// ключом.
  Future<Map<String, dynamic>> multipart(
    String path, {
    Map<String, String> fields = const {},
    List<http.MultipartFile> files = const [],
  }) async {
    await _auth.ensureUser();
    final signature = IdempotencyKeys.signature(
      userId: _auth.user?.id,
      method: 'POST',
      path: path,
      fields: fields,
      files: [
        for (final f in files)
          (field: f.field, filename: f.filename, length: f.length),
      ],
    );
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers['Accept'] = 'application/json'
      ..headers[IdempotencyKeys.header] = await _keys.keyFor(signature)
      ..fields.addAll(fields)
      ..files.addAll(files);
    if (_auth.token != null) {
      request.headers['Authorization'] = 'Bearer ${_auth.token}';
    }
    final response = await HttpTransport.send(request);
    await _settle(signature, response);
    return _decode(response);
  }

  /// Сколько раз спросить о запросе, который сервер ещё выполняет.
  static const inProgressAttempts = 5;

  /// Пауза между вопросами, если сервер не назвал свою (`Retry-After`).
  static const _inProgressPause = Duration(seconds: 1);

  /// 409 — только «запрос с этим ключом ещё идёт» (`Idempotent`), других
  /// 409 сервер не отдаёт.
  static bool _inProgress(http.Response r) => r.statusCode == 409;

  static Duration _retryAfter(http.Response r) {
    final seconds = int.tryParse(r.headers['retry-after'] ?? '');
    if (seconds == null || seconds < 0) return _inProgressPause;
    return Duration(seconds: seconds.clamp(0, 5));
  }

  /// Ответ сервера — исход известен, ключ больше не нужен: 2xx сделан
  /// (повтор отдал бы его же), 4xx ничего не изменил. Не забываем ключ
  /// при 5xx (мог упасть после записи), 409 (ещё идёт) и 429 (лимитер
  /// не пустил — повторят тем же ключом). Сеть — исключение до сюда не
  /// доходит, ключ остаётся.
  Future<void> _settle(String signature, http.Response response) async {
    final status = response.statusCode;
    final known =
        status >= 200 && status < 500 && status != 409 && status != 429;
    if (known) await _keys.settle(signature);
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw failure(response.statusCode, response.body);
    }
    if (response.body.isEmpty) return const {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
