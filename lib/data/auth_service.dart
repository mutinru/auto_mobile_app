import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/current_user.dart';
import 'api_exception.dart';

/// Хранит Sanctum-токен в защищённом хранилище платформы
/// (Keystore на Android, Keychain на iOS), поэтому вход переживает
/// перезапуск приложения. На вебе flutter_secure_storage кладёт значение
/// в localStorage — для дев-сборки это приемлемо, для прода веб-таргет
/// потребует отдельного решения.
class AuthService extends ChangeNotifier {
  static const _tokenKey = 'auth_token';
  static const _storage = FlutterSecureStorage();

  String? _token;
  CurrentUser? _user;

  /// true, пока идёт попытка восстановить сессию при старте.
  bool _restoring = true;
  bool get isRestoring => _restoring;

  /// Поднять токен с диска и проверить, что он ещё живой.
  Future<void> restore() async {
    try {
      final saved = await _storage.read(key: _tokenKey);
      if (saved != null) {
        _token = saved;
        await _loadUser();
        // сервер мог отозвать токен — тогда _loadUser не заполнит юзера
        if (_user == null) {
          _token = null;
          await _storage.delete(key: _tokenKey);
        }
      }
    } catch (_) {
      // недоступное хранилище не должно ронять запуск
      _token = null;
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  String? get token => _token;
  CurrentUser? get user => _user;
  bool get isAuthenticated => _token != null;

  Future<void> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/login'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, _extractMessage(response.body));
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    await _persist(body['token'] as String);
    notifyListeners();
  }

  /// Запросить код на телефон. Возвращает код, если бекенд в local
  /// режиме его отдал (доставки SMS пока нет) — иначе null.
  Future<String?> requestPhoneCode(String phone) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/phone/request'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, _extractMessage(response.body));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['dev_code'] as String?;
  }

  Future<void> verifyPhoneCode(String phone, String code) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/phone/verify'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'phone': phone, 'code': code}),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, _extractMessage(response.body));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    await _persist(body['token'] as String);
    notifyListeners();
  }

  Future<void> _persist(String token) async {
    _token = token;
    await _storage.write(key: _tokenKey, value: token);
    await _loadUser();
  }

  /// Профилю нужны имя и дата регистрации — их отдаёт GET /me.
  Future<void> _loadUser() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/me'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $_token'},
    );
    if (response.statusCode != 200) return;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    _user = CurrentUser.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> logout() async {
    final token = _token;
    _token = null;
    _user = null;
    await _storage.delete(key: _tokenKey);
    notifyListeners();

    if (token == null) return;
    await http.post(
      Uri.parse('${ApiConfig.baseUrl}/logout'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
  }

  String _extractMessage(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      return decoded['message'] as String? ?? 'Ошибка входа';
    } catch (_) {
      return 'Ошибка входа';
    }
  }
}
