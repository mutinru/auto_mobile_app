import '../models/session.dart';
import 'api_client.dart';
import 'json_list.dart';

/// «Активные устройства»: где пользователь вошёл, и выход на чужом
/// устройстве. Сервер вместе с сессией удаляет её пуш-устройство.
abstract class SessionRepository {
  Future<List<Session>> fetchSessions();

  /// Выйти на устройстве (не на этом — для этого «Выйти» в профиле).
  Future<void> revoke(int sessionId);

  /// Выйти на всех устройствах, кроме этого.
  Future<void> revokeOthers();
}

class ApiSessionRepository implements SessionRepository {
  ApiSessionRepository(this._client);

  final ApiClient _client;

  @override
  Future<List<Session>> fetchSessions() async {
    final json = await _client.get('/me/sessions');
    return parseList(json['data'], Session.fromJson, what: 'сессия');
  }

  @override
  Future<void> revoke(int sessionId) =>
      _client.delete('/me/sessions/$sessionId');

  @override
  Future<void> revokeOthers() => _client.delete('/me/sessions');
}
