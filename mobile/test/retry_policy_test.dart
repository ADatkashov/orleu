import 'package:flutter_test/flutter_test.dart';
import 'package:orleu_mobile/core/api/api_client.dart';

void main() {
  test('only brief network blips are retried; server errors surface immediately', () {
    const network = ApiError(null, 'NETWORK', '');
    expect(appRetry(0, network), const Duration(seconds: 1));
    expect(appRetry(2, network), const Duration(seconds: 3));
    expect(appRetry(3, network), isNull, reason: 'bounded');
    expect(appRetry(0, const ApiError(500, 'X', '')), isNull);
    expect(appRetry(0, const ApiError(403, 'FORBIDDEN', '')), isNull);
  });
}
