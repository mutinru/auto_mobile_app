import '../models/client_config.dart';
import 'api_client.dart';
import 'config_repository.dart';

/// Цены и лимиты клиента (GET /config).
class ApiConfigRepository implements ConfigRepository {
  ApiConfigRepository(this._client);

  final ApiClient _client;

  @override
  Future<ClientConfig> fetchClientConfig() async {
    final json = await _client.get('/config');
    return ClientConfig.fromJson(json['data'] as Map<String, dynamic>);
  }
}
