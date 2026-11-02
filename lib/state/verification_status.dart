import 'package:flutter/foundation.dart';

import '../data/verification_repository.dart';
import '../widgets/api_error.dart';

/// Статус верификации исполнителя на всю сессию — один на приложение
/// (см. main.dart), как [CityLocator]. Экраны создаются заново на каждый
/// вход в раздел, а верификацию проходят один раз: без общего статуса
/// каждый вход начинался бы с «не знаем» и гейт мигал.
///
/// Сбой запроса не стирает прежнюю [summary] — только ставит [error].
/// При выходе — [clear]: чужой статус не должен достаться следующему входу.
class VerificationStatus extends ChangeNotifier {
  VerificationStatus(this._repository);

  final VerificationRepository _repository;

  VerificationSummary? _summary;
  Future<void>? _inFlight;
  String? _error;

  /// Номер сессии статуса: [clear] его меняет, и ответ на запрос, ушедший
  /// до выхода, уже не применяется.
  int _generation = 0;

  /// Последний ответ сервера; null — ещё не знаем.
  VerificationSummary? get summary => _summary;
  bool get loading => _inFlight != null;

  /// Текст ошибки последнего запроса; null — всё хорошо.
  String? get error => _error;

  /// Перечитать с сервера. Пока запрос идёт, повторный вызов ждёт его же.
  Future<void> refresh() => _inFlight ??= _load(_generation);

  /// Запросить, только если статуса ещё нет.
  Future<void> ensureLoaded() => _summary != null ? Future.value() : refresh();

  void clear() {
    if (_summary == null && _error == null && _inFlight == null) return;
    _generation++;
    _summary = null;
    _error = null;
    _inFlight = null;
    notifyListeners();
  }

  Future<void> _load(int generation) async {
    // уведомляем после возврата Future: refresh() уже запомнил его в
    // _inFlight, и слушатели видят loading == true
    await null;
    if (generation != _generation) return;
    _error = null;
    notifyListeners();
    try {
      final summary = await _repository.fetchSummary();
      if (generation != _generation) return;
      _summary = summary;
    } catch (e) {
      if (generation != _generation) return;
      _error = apiErrorText(e);
    } finally {
      if (generation == _generation) {
        _inFlight = null;
        notifyListeners();
      }
    }
  }
}
