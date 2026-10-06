/// Shared customer API address. Override for another server with API_BASE_URL.
abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.45.123:8000',
  );
}
