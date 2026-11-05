import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the refresh/access tokens live. Production uses the platform keystore (Keychain / EncryptedSharedPreferences).
abstract class TokenStore {
  Future<String?> readAccess();
  Future<String?> readRefresh();
  Future<void> save({required String access, required String refresh});
  Future<void> clear();
}

class SecureTokenStore implements TokenStore {
  static const _a = 'orleu.access', _r = 'orleu.refresh';
  final FlutterSecureStorage _s = const FlutterSecureStorage();
  @override
  Future<String?> readAccess() => _s.read(key: _a);
  @override
  Future<String?> readRefresh() => _s.read(key: _r);
  @override
  Future<void> save({required String access, required String refresh}) async {
    await _s.write(key: _a, value: access);
    await _s.write(key: _r, value: refresh);
  }

  @override
  Future<void> clear() async {
    await _s.delete(key: _a);
    await _s.delete(key: _r);
  }
}

class MemoryTokenStore implements TokenStore {
  String? access, refresh;
  @override
  Future<String?> readAccess() async => access;
  @override
  Future<String?> readRefresh() async => refresh;
  @override
  Future<void> save({required String access, required String refresh}) async {
    this.access = access;
    this.refresh = refresh;
  }

  @override
  Future<void> clear() async {
    access = null;
    refresh = null;
  }
}
