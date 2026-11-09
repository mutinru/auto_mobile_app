import 'api_client.dart';
import '../push/push_provider.dart';
import 'device_repository.dart';

class ApiDeviceRepository implements DeviceRepository {
  ApiDeviceRepository(this._client);

  final ApiClient _client;

  @override
  Future<void> register(
    String token,
    String platform,
    PushProvider provider,
  ) async {
    await _client.post('/me/devices', {
      'token': token,
      'platform': platform,
      'provider': provider.apiValue,
    });
  }
}
