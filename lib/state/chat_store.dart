import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/api_exception.dart';
import '../data/chat_repository.dart';
import '../models/chat_message.dart';
import '../models/conversation.dart';
import '../widgets/api_error.dart';

/// Чат с поддержкой. Realtime на бекенде нет: пока экран открыт, раз в
/// [pollInterval] спрашиваем новые сообщения через after_id. Сообщения
/// сливаются по id, поэтому ответ на отправку и опрос не дают дублей.
class ChatStore extends ChangeNotifier {
  ChatStore(this.repository, {this.pollInterval = const Duration(seconds: 4)});

  final ChatRepository repository;
  final Duration pollInterval;

  /// Размер страницы сервера (MessageController::PAGE).
  static const pageSize = 50;

  Conversation? _conversation;
  List<ChatMessage> _messages = const [];
  bool _loading = false;
  bool _loadingOlder = false;
  bool _hasMore = false;
  bool _sending = false;
  String? _error;
  String? _sendError;

  Timer? _timer;
  bool _polling = false;
  int? _readSent;
  bool _disposed = false;

  Conversation? get conversation => _conversation;

  /// По возрастанию id — экран сам разворачивает для reverse-списка.
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isLoading => _loading;
  bool get isLoadingOlder => _loadingOlder;
  bool get hasMore => _hasMore;
  bool get isSending => _sending;

  /// Ошибка загрузки чата — экран показывает её с «Повторить».
  String? get error => _error;

  /// Ошибка последней отправки; текст в поле при этом не стирается.
  String? get sendError => _sendError;

  Future<void> open() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final conversation = await repository.openSupport();
      final page = await repository.fetchMessages(conversation.id);
      _conversation = conversation;
      _messages = page;
      _hasMore = page.length == pageSize;
      _markRead();
      _startPolling();
    } catch (e) {
      _error = apiErrorText(e);
    } finally {
      _loading = false;
      _notify();
    }
  }

  Future<void> loadOlder() async {
    final conversation = _conversation;
    if (conversation == null || _loadingOlder || !_hasMore || _messages.isEmpty) return;
    _loadingOlder = true;
    _notify();
    try {
      final page = await repository.fetchMessages(conversation.id, beforeId: _messages.first.id);
      _merge(page);
      _hasMore = page.length == pageSize;
    } catch (_) {
      // история подгрузится при следующей прокрутке
    } finally {
      _loadingOlder = false;
      _notify();
    }
  }

  /// true — отправлено, экран очищает поле и выбранные фото.
  Future<bool> send(String text, List<String> photoPaths) async {
    final conversation = _conversation;
    final body = text.trim();
    if (conversation == null || _sending || (body.isEmpty && photoPaths.isEmpty)) return false;

    _sending = true;
    _sendError = null;
    _notify();
    try {
      final message = await repository.send(
        conversation.id,
        body: body.isEmpty ? null : body,
        photoPaths: photoPaths,
      );
      _merge([message]);
      return true;
    } catch (e) {
      _sendError = apiErrorText(e);
      return false;
    } finally {
      _sending = false;
      _notify();
    }
  }

  /// Приложение ушло в фон — не опрашиваем.
  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  /// Вернулись — сразу проверяем новые и продолжаем опрос.
  void resume() {
    if (_conversation == null || _timer != null) return;
    _startPolling();
    poll();
  }

  @visibleForTesting
  Future<void> poll() async {
    final conversation = _conversation;
    // предыдущий запрос ещё в полёте — тик пропускаем
    if (conversation == null || _polling) return;
    _polling = true;
    try {
      final fresh = await repository.fetchMessages(
        conversation.id,
        afterId: _messages.isEmpty ? 0 : _messages.last.id,
      );
      if (fresh.isNotEmpty) {
        _merge(fresh);
        _markRead();
        _notify();
      }
    } on ApiException catch (e) {
      // сессия истекла — опрашивать дальше бессмысленно
      if (e.statusCode == 401) {
        pause();
        _error = apiErrorText(e);
        _notify();
      }
    } catch (_) {
      // нет сети — попробуем на следующем тике
    } finally {
      _polling = false;
    }
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(pollInterval, (_) => poll());
  }

  void _merge(List<ChatMessage> incoming) {
    final byId = {for (final m in _messages) m.id: m, for (final m in incoming) m.id: m};
    _messages = byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));
  }

  /// Прочитано до последнего чужого сообщения. Ошибку глотаем: счётчик
  /// поправится следующей отметкой.
  void _markRead() {
    final conversation = _conversation;
    final last = _messages.lastWhere((m) => !m.isMine, orElse: () => _none);
    if (conversation == null || identical(last, _none) || last.id == _readSent) return;
    _readSent = last.id;
    repository.markRead(conversation.id, last.id).catchError((_) {});
  }

  static final _none = ChatMessage(id: -1, createdAt: DateTime(0));

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    pause();
    super.dispose();
  }
}
