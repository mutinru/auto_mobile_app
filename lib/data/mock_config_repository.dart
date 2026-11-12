import '../models/client_config.dart';
import 'config_repository.dart';
import 'mock_backend.dart';

/// Цены и лимиты для тестов: комиссия размещения — [MockBackend.placementFee].
class MockConfigRepository implements ConfigRepository {
  MockConfigRepository(this.backend);

  final MockBackend backend;

  @override
  Future<ClientConfig> fetchClientConfig() async => ClientConfig(
    inspectionPlacementFee: backend.placementFee,
    vinReportPrice: 299,
  );
}
