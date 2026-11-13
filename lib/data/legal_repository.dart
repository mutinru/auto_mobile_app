import '../models/legal_text.dart';
import 'api_client.dart';

/// Тексты документов (`GET /legal/{код}`). Без токена: документы открывают и
/// с экрана входа — [ApiClient] гостя просто не шлёт `Authorization`.
abstract class LegalRepository {
  Future<LegalText> fetch(LegalDocument doc);
}

class ApiLegalRepository implements LegalRepository {
  ApiLegalRepository(this._client);

  final ApiClient _client;

  @override
  Future<LegalText> fetch(LegalDocument doc) async {
    final json = await _client.get('/legal/${doc.code}');
    return LegalText.fromJson(json['data'] as Map<String, dynamic>);
  }
}
