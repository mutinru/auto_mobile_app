import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/current_user.dart';
import '../models/notification_category.dart';
import '../models/order_alerts.dart';
import '../models/payout.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// Профиль вошедшего (ревью №40): имя, аватар, номер, реквизиты, пуши,
/// подписка на заказы, удаление аккаунта. Запросы — через [ApiClient], как
/// у остальных репозиториев: 401 там же стирает сессию, ошибка —
/// [ApiException] с телом ответа (экран берёт `apiErrorText`, форма —
/// `fieldErrors`). Сессия (токен, вход, `/me`, выход) — в [AuthService].
///
/// Ответ правки — профиль в форме GET /me: он целиком уходит в
/// [AuthService.applyUser], шапки и экраны, слушающие сессию, обновятся
/// сами. Класс конкретный: в тестах подменяется наследником.
class ProfileRepository {
  ProfileRepository(this._auth, {ApiClient? client})
    : _client = client ?? ApiClient(_auth);

  /// Репозиторий для экранов профиля, настроек и подписки. Тесты
  /// подменяют [factory] (как `PaymentFlow.sdk`) и возвращают её в
  /// `tearDown`: экраны с ним глубоко в навигации, параметр пришлось бы
  /// протаскивать через «Заказы рядом» и настройки.
  static ProfileRepository of(AuthService auth) => factory(auth);

  @visibleForTesting
  static ProfileRepository Function(AuthService auth) factory =
      ProfileRepository.new;

  final AuthService _auth;
  final ApiClient _client;

  void _apply(Map<String, dynamic> json) => _auth.applyUser(
    CurrentUser.fromJson(json['data'] as Map<String, dynamic>),
  );

  /// Сменить имя (PATCH /me).
  Future<void> updateName(String name) async =>
      _apply(await _client.patch('/me', {'name': name}));

  /// Загрузить или заменить аватар (POST /me/avatar). [path] — уже
  /// обрезанный квадрат; сервер всё равно режет центр и пережимает в
  /// JPEG 512×512.
  Future<void> uploadAvatar(String path) async => _apply(
    await _client.multipart(
      '/me/avatar',
      files: [await http.MultipartFile.fromPath('avatar', path)],
    ),
  );

  /// Удалить аватар (DELETE /me/avatar) — снова инициалы.
  Future<void> deleteAvatar() async =>
      _apply(await _client.delete('/me/avatar'));

  /// Запросить код на новый номер (POST /me/phone/request). Ответ — как у
  /// [AuthService.requestPhoneCode]; листу из ошибки нужны `retry_after` и
  /// текст 422.
  Future<PhoneCodeSent> requestPhoneChange(String phone) async =>
      PhoneCodeSent.fromJson(
        await _client.post('/me/phone/request', {'phone': phone}),
      );

  /// Подтвердить новый номер кодом (POST /me/phone/verify). Сервер отзывает
  /// остальные токены — текущий живёт.
  Future<void> confirmPhoneChange(String phone, String code) async => _apply(
    await _client.post('/me/phone/verify', {'phone': phone, 'code': code}),
  );

  /// Реквизиты для оплаты разового осмотра (PATCH /me/payout). Ошибки по
  /// полям — [ApiException.fieldErrors].
  Future<void> updatePayout(Payout payout) async =>
      _apply(await _client.patch('/me/payout', payout.toJson()));

  /// Заглушённые категории пушей (PATCH /me/notifications) — полный список.
  Future<void> updatePushMuted(Set<NotificationCategory> muted) async => _apply(
    await _client.patch('/me/notifications', {
      'push_muted': [for (final c in muted) c.apiValue],
    }),
  );

  /// Подписка на новые заказы (PUT /me/order-alerts) — целиком.
  Future<void> updateOrderAlerts(OrderAlerts alerts) async =>
      _apply(await _client.put('/me/order-alerts', alerts.toJson()));

  /// Удалить аккаунт (DELETE /me). Сервер обезличивает его, а не стирает:
  /// закрытые заказы и отзывы остаются без имени. Успех — сессия стирается
  /// ([AuthService.endSession]: токен на сервере уже отозван, `/logout` не
  /// нужен). 422 — идут заказы или ждёт выплата: [ApiException] с текстом
  /// сервера, пользователь остаётся вошедшим.
  Future<void> deleteAccount() async {
    await _client.delete('/me');
    await _auth.endSession();
  }
}
