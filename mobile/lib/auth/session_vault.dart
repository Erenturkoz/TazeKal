import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SessionVault {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> clear();
}

class SecureSessionVault implements SessionVault {
  const SecureSessionVault();
  static const storage = FlutterSecureStorage();
  static const key = 'taze_kal_session_v1';
  @override
  Future<String?> read() => storage.read(key: key);
  @override
  Future<void> write(String value) => storage.write(key: key, value: value);
  @override
  Future<void> clear() => storage.delete(key: key);
}
