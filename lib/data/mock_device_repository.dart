import 'api_exception.dart';
import 'device_repository.dart';

/// Для тестов PushService: запоминает зарегистрированные токены.
class MockDeviceRepository implements DeviceRepository {
  final List<String> registered = [];

  /// register() падает — нет сети.
  bool fail = false;

  @override
  Future<void> register(String token, String platform) async {
    if (fail) throw ApiException(500, '');
    registered.add(token);
  }
}
