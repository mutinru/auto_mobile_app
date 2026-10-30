import 'package:flutter/foundation.dart';

import '../data/notification_repository.dart';
import '../models/app_notification.dart';
import '../widgets/api_error.dart';
import 'notification_unread.dart';

/// Лента уведомлений экрана: страницы по курсору и отметки прочитанного.
/// Прочитанность и число непрочитанных — только из ответов сервера; число
/// заодно уходит в [unread], чтобы бейдж колокольчика не ждал опроса.
class NotificationStore extends ChangeNotifier {
  NotificationStore(this._repository, {this.unread});

  final NotificationRepository _repository;
  final NotificationUnread? unread;

  final List<AppNotification> _items = [];
  List<AppNotification> get items => List.unmodifiable(_items);

  String? _cursor;
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  bool _loading = false;
  bool get isLoading => _loading;

  String? _error;
  String? get error => _error;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  /// Первая страница заново — pull-to-refresh и после «прочитать все».
  Future<void> refresh() async {
    _items.clear();
    _cursor = null;
    _hasMore = true;
    await loadMore(force: true);
  }

  /// Следующая страница. [force] — даже если уже грузится (refresh).
  Future<void> loadMore({bool force = false}) async {
    if (!_hasMore || (_loading && !force)) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final page = await _repository.fetchPage(cursor: _cursor);
      _items.addAll(page.items);
      _cursor = page.nextCursor;
      _hasMore = page.nextCursor != null;
      _setUnread(page.unreadCount);
    } catch (e) {
      _error = apiErrorText(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Отметить прочитанным; элемент подменяется ответом сервера. Ошибку
  /// пробрасывает — экран покажет её SnackBar'ом.
  Future<void> markRead(AppNotification notification) async {
    if (notification.isRead) return;
    final updated = await _repository.markRead(notification.id);
    final i = _items.indexWhere((n) => n.id == updated.id);
    if (i >= 0) _items[i] = updated;
    notifyListeners();
    // одно прочитано — число спрашиваем у сервера, а не вычитаем
    try {
      _setUnread(await _repository.fetchUnreadCount());
    } catch (_) {
      // бейдж поправит ближайший опрос
    }
  }

  /// Прочитать все и перечитать ленту — read_at придут с сервера.
  Future<void> markAllRead() async {
    _setUnread(await _repository.markAllRead());
    await refresh();
  }

  void _setUnread(int count) {
    _unreadCount = count;
    unread?.report(count);
    notifyListeners();
  }
}
