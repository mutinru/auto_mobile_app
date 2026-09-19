import 'api_client.dart';
import 'verification_repository.dart';

class ApiVerificationRepository implements VerificationRepository {
  ApiVerificationRepository(this._client);

  final ApiClient _client;

  @override
  Future<VerificationSummary> fetchSummary() async {
    final json = await _client.get('/verification');
    return VerificationSummary.fromJson(json['data'] as Map<String, dynamic>);
  }
}
