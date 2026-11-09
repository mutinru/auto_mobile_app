import '../push/push_provider.dart';
import 'api_exception.dart';
import 'device_repository.dart';

/// Для тестов PushService: запоминает зарегистрированные токены.
class MockDeviceRepository implements DeviceRepository {
  final List<String> registered = [];

  /// Сервис каждого токена из [registered], в том же порядке.
  final List<PushProvider> providers = [];

  /// register() падает — нет сети.
  bool fail = false;

  @override
  Future<void> register(
    String token,
    String platform,
    PushProvider provider,
  ) async {
    if (fail) throw ApiException(500, '');
    registered.add(token);
    providers.add(provider);
  }
}
