import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../models/code_channel.dart';
import '../models/current_user.dart';
import '../models/payout.dart';
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

  /// Перечитать /me: рейтинг исполнителя меняется, пока приложение открыто
  /// (заказчики оставляют отзывы). Ошибку глотаем — в профиле останется
  /// прежний пользователь.
  Future<void> refreshUser() async {
    if (_token == null) return;
    try {
      // токен отозван, пока приложение было открыто, — это и есть
      // протухшая сессия; при старте то же самое тихо разбирает restore()
      if (await _loadUser() == 401) return expireSession();
      notifyListeners();
    } catch (_) {
      // нет сети — показываем то, что было
    }
  }

  /// Тесты профиля работают без сети и токена.
  @visibleForTesting
  void debugSetUser(CurrentUser user) {
    _user = user;
    notifyListeners();
  }

  /// «Вошёл» без сети — для шторки поддержки, которая смотрит на токен.
  @visibleForTesting
  void debugSetToken(String token) {
    _token = token;
    notifyListeners();
  }

  bool get isAuthenticated => _token != null;

  bool _sessionExpired = false;

  /// Сессию стёр ответ 401, а не кнопка «Выйти». Корень приложения
  /// ([_RootGate] в main.dart) по нему уводит на вход и сбрасывает флаг.
  bool get sessionExpired => _sessionExpired;

  void consumeSessionExpired() => _sessionExpired = false;

  /// Сервер ответил 401 на запрос с токеном: токен отозван или протух.
  /// Зовут все, кто ходит в API с токеном, — ApiClient, multipart-запросы,
  /// экраны с прямым http. Без токена (гость, уже обработанный 401 от
  /// параллельного запроса) — ничего не делает.
  void expireSession() {
    if (_token == null) return;
    _token = null;
    _user = null;
    _sessionExpired = true;
    notifyListeners();
    // хранилище недоступно в тестах и может сбоить — сессия в памяти
    // уже стёрта, этого достаточно до следующего запуска
    _storage.delete(key: _tokenKey).catchError((_) {});
  }

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

  /// Запросить код входа: звонком, в Telegram или SMS — решает бекенд.
  /// Ошибка — [ApiException] с сырым телом: экрану нужен `retry_after`.
  Future<PhoneCodeSent> requestPhoneCode(String phone) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/phone/request'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'phone': phone}),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return PhoneCodeSent(
      devCode: body['dev_code'] as String?,
      resendIn: (body['resend_in'] as num?)?.toInt() ?? 0,
      channel: codeChannelFromApi(body['channel'] as String?),
    );
  }

  /// Ошибка — [ApiException] с сырым телом, как у [requestPhoneCode].
  Future<void> verifyPhoneCode(String phone, String code) async {
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/auth/phone/verify'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'phone': phone, 'code': code}),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
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

  /// Профилю нужны имя и дата регистрации — их отдаёт GET /me. Код ответа —
  /// вызывающему: restore() и refreshUser() по-разному реагируют на 401.
  Future<int> _loadUser() async {
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/me'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $_token'},
    );
    if (response.statusCode != 200) return response.statusCode;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    _user = CurrentUser.fromJson(body['data'] as Map<String, dynamic>);
    return response.statusCode;
  }

  /// Сменить имя (PATCH /me). Сервер отдаёт профиль в той же форме, что
  /// GET /me, — подменяем юзера целиком, шапка профиля обновится сама.
  Future<void> updateName(String name) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/me'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode != 200) {
      if (response.statusCode == 401) expireSession();
      throw ApiException(
        response.statusCode,
        _extractMessage(response.body, fallback: 'Не удалось сохранить имя'),
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    _user = CurrentUser.fromJson(body['data'] as Map<String, dynamic>);
    notifyListeners();
  }

  /// Реквизиты для оплаты разового осмотра (PATCH /me/payout). Ошибку
  /// бросаем с сырым телом: форме нужны ошибки по полям
  /// ([ApiException.fieldErrors]).
  Future<void> updatePayout(Payout payout) async {
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/me/payout'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode(payout.toJson()),
    );
    if (response.statusCode != 200) {
      if (response.statusCode == 401) expireSession();
      throw ApiException(response.statusCode, response.body);
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    _user = CurrentUser.fromJson(body['data'] as Map<String, dynamic>);
    notifyListeners();
  }

  Future<void> logout() async {
    final token = _token;
    _token = null;
    _user = null;
    await _storage.delete(key: _tokenKey);
    notifyListeners();

    if (token == null) return;
    // локальная сессия уже стёрта — без сети выход не должен падать,
    // токен на сервере тогда просто доживёт своё
    try {
      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/logout'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      );
    } catch (_) {}
  }

  /// Первая ошибка валидации, иначе `message`, иначе [fallback] — как
  /// [ApiException.userMessage], но без сырого тела в худшем случае.
  String _extractMessage(String body, {String fallback = 'Ошибка входа'}) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final errors = decoded['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return '${first.first}';
      }
      return decoded['message'] as String? ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}

/// Ответ на запрос кода входа.
class PhoneCodeSent {
  const PhoneCodeSent({this.devCode, this.resendIn = 0, this.channel});

  /// Код прямо в ответе — только local-бекенд с драйвером log.
  final String? devCode;

  /// Через сколько секунд можно запросить код снова.
  final int resendIn;
  final CodeChannel? channel;
}
