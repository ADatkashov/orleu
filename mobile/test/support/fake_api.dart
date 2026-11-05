import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:orleu_mobile/core/api/api_client.dart';
import 'package:orleu_mobile/core/api/token_store.dart';
import 'package:orleu_mobile/core/data/auth_controller.dart';

typedef Handler = ({int status, Object? body}) Function(RequestOptions o);

/// In-memory HTTP adapter: lets widget tests run the real ApiClient/interceptors without a network.
class FakeAdapter implements HttpClientAdapter {
  final Map<String, Handler> routes;
  final List<RequestOptions> calls = [];
  FakeAdapter(this.routes);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? body, Future<void>? cancel) async {
    calls.add(o);
    final h = routes['${o.method} ${o.path}'];
    final r = h == null ? (status: 404, body: {'code': 'NOT_FOUND', 'message': 'x'}) : h(o);
    return ResponseBody.fromString(jsonEncode(r.body), r.status, headers: {Headers.contentTypeHeader: ['application/json']});
  }

  @override
  void close({bool force = false}) {}
}

({int status, Object? body}) ok(Object? body) => (status: 200, body: body);
({int status, Object? body}) err(int status, String code) => (status: status, body: {'code': code, 'message': 'srv'});

final tokenJson = {'accessToken': 'access-1', 'refreshToken': 'refresh-1', 'expiresInSeconds': 900, 'tokenType': 'Bearer'};

List<Override> overridesFor(FakeAdapter adapter, MemoryTokenStore store) => [
      tokenStoreProvider.overrideWithValue(store),
      apiClientProvider.overrideWith((ref) => ApiClient(store, adapter: adapter, baseUrl: 'http://test',
          onSessionExpired: () => ref.read(authControllerProvider.notifier).sessionExpired())),
    ];

/// Routes for a signed-in user that owns one business with a single booking today.
Map<String, Handler> businessRoutes({List<Map<String, Object?>> bookings = const []}) => {
      'GET /api/v1/me': (_) => ok({'id': 'u1', 'email': 'a@b.kz', 'fullName': 'Aigerim Sadykova', 'locale': 'en', 'memberships': []}),
      'GET /api/v1/businesses': (_) => ok([
            {'id': 'b1', 'name': 'Studio Almaty', 'slug': 'studio', 'currency': 'KZT', 'planCode': 'FREE', 'published': true}
          ]),
      'GET /api/v1/businesses/b1/bookings': (_) => ok(bookings),
      'GET /api/v1/businesses/b1/analytics/summary': (_) => ok({
            'totalBookings': bookings.length, 'bookedValue': 20000, 'collected': 6000, 'refunded': 0, 'netCollected': 6000,
            'outstanding': 14000, 'cancellationRate': 0.0, 'noShowRate': 0.0
          }),
      'GET /api/v1/businesses/b1/subscription': (_) => ok({'planCode': 'FREE', 'employees': 1, 'maxEmployees': 3}),
      'GET /api/v1/businesses/b1/customers': (_) => ok({'items': [], 'page': 0, 'size': 50, 'total': 0}),
    };
