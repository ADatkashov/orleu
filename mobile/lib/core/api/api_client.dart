import 'package:dio/dio.dart';

import 'token_store.dart';

const apiBaseUrl = String.fromEnvironment('ORLEU_API_URL', defaultValue: 'http://localhost:8080');

/// Error envelope returned by the backend: {code, message, correlationId}.
class ApiError implements Exception {
  final int? status;
  final String code;
  final String message;
  const ApiError(this.status, this.code, this.message);
  bool get isNetwork => status == null;
  @override
  String toString() => 'ApiError($status, $code)';

  factory ApiError.from(Object e) {
    if (e is ApiError) return e;
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['code'] is String) {
        return ApiError(e.response?.statusCode, data['code'] as String, (data['message'] ?? '') as String);
      }
      if (e.response != null) return ApiError(e.response!.statusCode, 'HTTP_${e.response!.statusCode}', '');
      return const ApiError(null, 'NETWORK', 'network');
    }
    return const ApiError(null, 'UNKNOWN', 'unknown');
  }
}

/// Dio wrapper: adds the bearer token and transparently refreshes it once on 401 (single-flight).
class ApiClient {
  final Dio dio;
  final TokenStore tokens;
  final void Function()? onSessionExpired;
  Future<bool>? _refreshing;

  ApiClient(this.tokens, {String? baseUrl, this.onSessionExpired, HttpClientAdapter? adapter})
      : dio = Dio(BaseOptions(
            baseUrl: baseUrl ?? apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 20),
            headers: {'Accept': 'application/json'})) {
    if (adapter != null) dio.httpClientAdapter = adapter;
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (o, h) async {
        final t = await tokens.readAccess();
        if (t != null && o.extra['noAuth'] != true) o.headers['Authorization'] = 'Bearer $t';
        h.next(o);
      },
      onError: (e, h) async {
        final req = e.requestOptions;
        if (e.response?.statusCode == 401 && req.extra['noAuth'] != true && req.extra['retried'] != true) {
          final ok = await (_refreshing ??= _refresh().whenComplete(() => _refreshing = null));
          if (ok) {
            req.extra['retried'] = true;
            req.headers['Authorization'] = 'Bearer ${await tokens.readAccess()}';
            try {
              return h.resolve(await dio.fetch(req));
            } on DioException catch (e2) {
              return h.next(e2);
            }
          }
          onSessionExpired?.call();
        }
        h.next(e);
      },
    ));
  }

  Future<bool> _refresh() async {
    final refresh = await tokens.readRefresh();
    if (refresh == null) return false;
    try {
      final r = await dio.post('/api/v1/auth/refresh',
          data: {'refreshToken': refresh}, options: Options(extra: {'noAuth': true}));
      await tokens.save(access: r.data['accessToken'] as String, refresh: r.data['refreshToken'] as String);
      return true;
    } catch (_) {
      await tokens.clear();
      return false;
    }
  }

  Future<T> run<T>(Future<T> Function(Dio dio) call) async {
    try {
      return await call(dio);
    } catch (e) {
      throw ApiError.from(e);
    }
  }
}

/// Provider retry policy. Riverpod 3 retries every failed provider up to 10 times by default, which keeps a screen on its
/// skeleton for about a minute when the failure is permanent (403/404/500). Only short network blips are retried, briefly;
/// everything else shows the error with its Retry button at once.
Duration? appRetry(int retryCount, Object error) =>
    retryCount < 3 && ApiError.from(error).isNetwork ? Duration(seconds: retryCount + 1) : null;
