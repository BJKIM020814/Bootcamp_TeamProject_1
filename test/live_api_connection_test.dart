import 'package:flutter_test/flutter_test.dart';
import '../lib/services/api_client.dart';
import '../lib/services/api_config.dart';
import '../lib/services/fitpick_api_service.dart';
import '../lib/discover/discover_api.dart';

void main() {
  const live = bool.fromEnvironment('RUN_LIVE_API_TESTS');
  const password = String.fromEnvironment('DEMO_TEST_PASSWORD');
  test('demo customer logs in and reads protected profile', () async {
    final api = FitpickApiService();
    await api.login('fitpick.customer.demo@example.com', password);
    expect(api.hasSession, isTrue);
    final profile = await api.me();
    expect(profile['email'], 'fitpick.customer.demo@example.com');
    await api.logout();
    expect(api.hasSession, isFalse);
  }, skip: !live || password.isEmpty);
  test('customer clients use one server and query actual products', () async {
    expect(ApiClient.baseUrl, ApiConfig.baseUrl);
    expect(FitpickApiService.baseUrl, ApiConfig.baseUrl);
    final health = await ApiClient.get('/health');
    expect(health['status'], 'ok');
    final products = await DiscoverApi().products();
    expect(products, isA<List<DiscoverProduct>>());
    await expectLater(FitpickApiService.instance.me(), throwsA(isA<FitpickApiException>()));
  }, skip: !live);
}
