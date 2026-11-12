import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';
import '../models/code_channel.dart';
import '../models/current_user.dart';
import 'api_exception.dart';
import 'device_name.dart';
import 'http_transport.dart';

/// Сессия: вход по коду, текущий пользователь (GET /me), выход с долгом
/// `/logout`, протухшая сессия. Профиль правит [ProfileRepository] (ревью
/// №40) — через [ApiClient], который сам зависит отсюда; поэтому мимо
/// клиента здесь ходят только `/me`, вход и `/logout`.
///
/// Хранит Sanctum-токен в защищённом хранилище платформы
/// (Keystore на Android, Keychain на iOS), поэтому вход переживает
/// перезапуск приложения. На вебе flutter_secure_storage кладёт значение
/// в localStorage — для дев-сборки это приемлемо, для прода веб-таргет
/// потребует отдельного решения.
class AuthService extends ChangeNotifier {
  static const _tokenKey = 'auth_token';

  /// Токены вышедших сессий, которые сервер ещё не отозвал (ревью №30):
  /// пока сессия жива, на телефон идут пуши вышедшего аккаунта.
  static const _pendingLogoutsKey = 'pending_logouts';
  static const _storage = FlutterSecureStorage();

  String? _token;
  CurrentUser? _user;

  /// true, пока идёт попытка восстановить сессию при старте.
  bool _restoring = true;
  bool get isRestoring => _restoring;

  /// Сколько ждать /me при старте: дольше заставка висеть не должна.
  static const restoreTimeout = Duration(seconds: 10);

  /// Поднять токен с диска и проверить, что он ещё живой.
  ///
  /// Сессию стирает только 401 — токен отозван. Нет сети, таймаут, 5xx во
  /// время выкатки — не повод разлогинивать: стартуем вошедшими без
  /// профиля, его догрузит [ensureUser] с первым же запросом.
  Future<void> restore() async {
    String? saved;
    try {
      saved = await _storage.read(key: _tokenKey);
    } catch (_) {
      // недоступное хранилище не должно ронять запуск — стартуем гостем
    }
    try {
      if (saved != null) {
        _token = saved;
        if (await _loadUser(timeout: restoreTimeout) == 401) {
          _token = null;
          await _storage.delete(key: _tokenKey);
        }
      }
    } catch (_) {
      // нет сети или сервер молчит — токен остаётся, профиль догрузим позже
    } finally {
      _restoring = false;
      notifyListeners();
    }
    // выход прошлого запуска мог не дойти до сервера
    unawaited(flushPendingLogouts());
  }

  Future<void>? _ensuring;

  /// Догрузить профиль, если вошли, а его нет (офлайн-старт). Зовёт
  /// [ApiClient] перед каждым запросом: экранам нужен `user.id`, чтобы
  /// отличить исполнителя от заказчика. С профилем — ничего не делает;
  /// параллельные вызовы делят один запрос /me.
  Future<void> ensureUser() {
    if (_token == null || _user != null) return Future.value();
    return _ensuring ??= _ensureUser().whenComplete(() => _ensuring = null);
  }

  Future<void> _ensureUser() async {
    try {
      final status = await _loadUser();
      if (status == 401) return expireSession();
      if (_user != null) notifyListeners();
    } catch (_) {
      // связи всё ещё нет — сам запрос экрана покажет ошибку
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
  /// Зовут те, кто ходит в API с токеном: ApiClient (в том числе загрузки)
  /// и запросы самого AuthService. Без токена (гость, уже обработанный 401 от
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

  /// Запросить код входа: звонком, в Telegram или SMS — решает бекенд.
  /// Ошибка — [ApiException] с сырым телом: экрану нужен `retry_after`.
  Future<PhoneCodeSent> requestPhoneCode(String phone) async {
    final response = await HttpTransport.request(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/auth/phone/request'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({'phone': phone}),
    );
    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, response.body);
    }
    return PhoneCodeSent.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Ошибка — [ApiException] с сырым телом, как у [requestPhoneCode].
  /// Имя телефона для «Активных устройств»; в тестах подменяется.
  @visibleForTesting
  static Future<String?> Function() deviceNameSource = deviceName;

  Future<void> verifyPhoneCode(String phone, String code) async {
    final device = await deviceNameSource();
    final response = await HttpTransport.request(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/auth/phone/verify'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'phone': phone,
        'code': code,
        'device_name': ?device,
      }),
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
    // вход прошёл — сеть есть, отзываем сессии, из которых вышли без неё
    unawaited(flushPendingLogouts());
  }

  /// Профилю нужны имя и дата регистрации — их отдаёт GET /me. Код ответа —
  /// вызывающему: restore() и refreshUser() по-разному реагируют на 401.
  Future<int> _loadUser({Duration? timeout}) async {
    final response = await HttpTransport.request(
      'GET',
      Uri.parse('${ApiConfig.baseUrl}/me'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      // при запуске — короче обычного: заставка не ждёт молчащий сервер
      timeout: timeout,
    );
    if (response.statusCode != 200) return response.statusCode;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    _user = CurrentUser.fromJson(body['data'] as Map<String, dynamic>);
    return response.statusCode;
  }

  /// Профиль из ответа правки ([ProfileRepository]): сервер отдаёт его в
  /// форме GET /me — подменяем целиком. Без сессии — ничего: ответ, пришедший
  /// после выхода, вернул бы на экран профиль вышедшего.
  void applyUser(CurrentUser user) {
    if (_token == null) return;
    _user = user;
    notifyListeners();
  }

  /// Сессии больше нет на сервере, и он это подтвердил — удаление аккаунта
  /// ([ProfileRepository.deleteAccount]): токен уже отозван, поэтому без
  /// долга `/logout`, в отличие от [logout].
  Future<void> endSession() async {
    _token = null;
    _user = null;
    notifyListeners();
    // хранилище может сбоить — сессия в памяти уже стёрта
    await _storage.delete(key: _tokenKey).catchError((_) {});
  }

  /// Выход. Сессия на телефоне стирается сразу, экран сети не ждёт; токен
  /// уходит в долг ([flushPendingLogouts]), пока сервер его не отзовёт:
  /// вместе с сессией сервер удаляет и устройство для пушей. Иначе вышедший
  /// без сети продолжал бы получать пуши своего аккаунта.
  Future<void> logout() async {
    final token = _token;
    _token = null;
    _user = null;
    if (token != null) await _addPendingLogout(token);
    // хранилище может сбоить — сессия в памяти уже стёрта
    await _storage.delete(key: _tokenKey).catchError((_) {});
    notifyListeners();
    if (token != null) unawaited(flushPendingLogouts());
  }

  final _logoutFallbacks = <Future<void> Function()>[];

  /// Что сделать, если сервер выход не подтвердил: `PushService` делает
  /// пуш-токен недействительным, и сервер удалит устройство по ответу
  /// FCM или RuStore.
  void addLogoutFallback(Future<void> Function() fallback) =>
      _logoutFallbacks.add(fallback);

  Future<void>? _flushing;

  /// Отозвать на сервере сессии, из которых вышли (`POST /logout`). 2xx и
  /// 401 (сессии уже нет) снимают долг; сбой сети, 5xx, 426 — оставляют до
  /// следующего раза (запуск, вход) и зовут [addLogoutFallback].
  /// Параллельные вызовы делят один проход.
  Future<void> flushPendingLogouts() =>
      _flushing ??= _flush().whenComplete(() => _flushing = null);

  Future<void> _flush() async {
    final pending = await _readPendingLogouts();
    var failed = false;
    for (final token in pending) {
      int? status;
      try {
        final response = await HttpTransport.request(
          'POST',
          Uri.parse('${ApiConfig.baseUrl}/logout'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );
        status = response.statusCode;
      } catch (_) {
        status = null;
      }
      final revoked =
          status != null && (status == 401 || (status >= 200 && status < 300));
      if (!revoked) {
        failed = true;
        break; // сети нет или сервер лежит — остальные тоже не пройдут
      }
      await _removePendingLogout(token);
    }
    // вошли снова — пуш-токен уже переехал к новой сессии (сервер переносит
    // его при регистрации), гасить его нельзя
    if (!failed || _token != null) return;
    for (final fallback in _logoutFallbacks) {
      try {
        await fallback();
      } catch (_) {}
    }
  }

  /// Долг, который не удалось записать (хранилище сбоит): хотя бы до
  /// конца запуска.
  List<String>? _unsavedPendingLogouts;

  Future<List<String>> _readPendingLogouts() async {
    final unsaved = _unsavedPendingLogouts;
    if (unsaved != null) return unsaved;
    try {
      final raw = await _storage.read(key: _pendingLogoutsKey);
      if (raw == null) return [];
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writePendingLogouts(List<String> tokens) async {
    try {
      if (tokens.isEmpty) {
        await _storage.delete(key: _pendingLogoutsKey);
      } else {
        await _storage.write(
          key: _pendingLogoutsKey,
          value: jsonEncode(tokens),
        );
      }
      _unsavedPendingLogouts = null;
    } catch (_) {
      _unsavedPendingLogouts = tokens;
    }
  }

  Future<void> _addPendingLogout(String token) async {
    final tokens = await _readPendingLogouts();
    if (!tokens.contains(token)) await _writePendingLogouts([...tokens, token]);
  }

  Future<void> _removePendingLogout(String token) async {
    final tokens = await _readPendingLogouts();
    await _writePendingLogouts([...tokens.where((t) => t != token)]);
  }
}

/// Ответ на запрос кода — входа или смены номера.
class PhoneCodeSent {
  const PhoneCodeSent({this.devCode, this.resendIn = 0, this.channel});

  factory PhoneCodeSent.fromJson(Map<String, dynamic> json) => PhoneCodeSent(
    devCode: json['dev_code'] as String?,
    resendIn: (json['resend_in'] as num?)?.toInt() ?? 0,
    channel: codeChannelFromApi(json['channel'] as String?),
  );

  /// Код прямо в ответе — только local-бекенд с драйвером log.
  final String? devCode;

  /// Через сколько секунд можно запросить код снова.
  final int resendIn;
  final CodeChannel? channel;
}
