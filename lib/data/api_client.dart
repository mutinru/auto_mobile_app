import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_exception.dart';
import 'auth_service.dart';
import 'http_transport.dart';

/// Обёртка над [HttpTransport]: базовый URL, Bearer-токен из
/// [AuthService], декодирование JSON и единая обработка ошибок — в том
/// числе у загрузки файлов ([multipart]). Таймауты — в транспорте.
class ApiClient {
  ApiClient(this._auth);

  final AuthService _auth;

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
  ) async {
    await _auth.ensureUser();
    final response = await HttpTransport.request(
      'PATCH',
      _uri(path),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> post(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    await _auth.ensureUser();
    final response = await HttpTransport.request(
      'POST',
      _uri(path),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> put(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    await _auth.ensureUser();
    final response = await HttpTransport.request(
      'PUT',
      _uri(path),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> delete(String path) async {
    await _auth.ensureUser();
    final response = await HttpTransport.request(
      'DELETE',
      _uri(path),
      headers: _headers,
    );
    return _decode(response);
  }

  /// Загрузка файлов: поля и файлы формой, ответ — JSON, ошибки — как у
  /// [post] (401 стирает сессию, 422 ложатся на поля через
  /// [ApiException.fieldErrors]). Таймаут — [HttpTransport.uploadTimeout].
  Future<Map<String, dynamic>> multipart(
    String path, {
    Map<String, String> fields = const {},
    List<http.MultipartFile> files = const [],
  }) async {
    await _auth.ensureUser();
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers['Accept'] = 'application/json'
      ..fields.addAll(fields)
      ..files.addAll(files);
    if (_auth.token != null) {
      request.headers['Authorization'] = 'Bearer ${_auth.token}';
    }
    return _decode(await HttpTransport.send(request));
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw failure(response.statusCode, response.body);
    }
    if (response.body.isEmpty) return const {};
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}
