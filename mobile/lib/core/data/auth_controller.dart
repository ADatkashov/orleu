import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../api/token_store.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient(
      ref.watch(tokenStoreProvider),
      onSessionExpired: () => ref.read(authControllerProvider.notifier).sessionExpired(),
    ));

class AuthController extends Notifier<AuthStatus> {
  @override
  AuthStatus build() {
    _restore();
    return AuthStatus.unknown;
  }

  Future<void> _restore() async {
    try {
      final refresh = await ref.read(tokenStoreProvider).readRefresh();
      if (refresh == null) {
        state = AuthStatus.unauthenticated;
        return;
      }
      await ref.read(apiClientProvider).run((d) => d.get('/api/v1/me')); // validates / refreshes the session
      state = AuthStatus.authenticated;
    } on ApiError catch (e) {
      // offline at start: keep the session if tokens exist, the data screens show their own error/retry
      state = e.isNetwork ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    }
  }

  Future<void> login(String email, String password) => _authenticate('/api/v1/auth/login', {'email': email, 'password': password});

  Future<void> register(String email, String password, String fullName) =>
      _authenticate('/api/v1/auth/register', {'email': email, 'password': password, 'fullName': fullName});

  Future<void> _authenticate(String path, Map<String, Object> body) async {
    final api = ref.read(apiClientProvider);
    final r = await api.run((d) => d.post(path, data: body, options: _noAuth));
    await ref.read(tokenStoreProvider).save(access: r.data['accessToken'], refresh: r.data['refreshToken']);
    state = AuthStatus.authenticated;
  }

  Future<void> logout() async {
    final store = ref.read(tokenStoreProvider);
    final refresh = await store.readRefresh();
    if (refresh != null) {
      try {
        await ref.read(apiClientProvider).run((d) => d.post('/api/v1/auth/logout', data: {'refreshToken': refresh}, options: _noAuth));
      } catch (_) {/* best effort: the local session is cleared regardless */}
    }
    await store.clear();
    state = AuthStatus.unauthenticated;
  }

  void sessionExpired() => state = AuthStatus.unauthenticated;
}

final authControllerProvider = NotifierProvider<AuthController, AuthStatus>(AuthController.new);

final _noAuth = Options(extra: {'noAuth': true});
