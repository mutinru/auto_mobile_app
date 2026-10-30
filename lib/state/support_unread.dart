import '../data/chat_repository.dart';
import 'polled_unread.dart';

/// Число непрочитанных в чате поддержки — для бейджей у входов в чат.
/// Опрос — в [PolledUnread]; здесь только пауза, пока открыт чат.
class SupportUnread extends PolledUnread {
  SupportUnread(
    super.auth,
    this._repository, {
    super.pollInterval,
  });

  final ChatRepository _repository;

  bool _chatOpen = false;

  /// Открыт ли экран чата — пуш об ответе поддержки тогда не показываем.
  bool get chatOpen => _chatOpen;

  /// Пока открыт экран чата, не опрашиваем: он сам отмечает прочитанное.
  /// Закрыли — сразу спрашиваем сервер, бейдж гаснет без ожидания опроса.
  set chatOpen(bool value) {
    _chatOpen = value;
    if (!value) refresh();
    schedule();
  }

  @override
  bool get paused => _chatOpen;

  @override
  Future<int> fetchCount() => _repository.fetchSupportUnread();
}
