import 'package:google_sign_in/google_sign_in.dart';
import 'auth_api.dart';

abstract class GoogleIdentityProvider {
  bool get configured;
  Future<String?> idToken();
}

class DeviceGoogleIdentity implements GoogleIdentityProvider {
  static Future<void>? initialization;
  static const webId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const iosId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');
  @override
  bool get configured => webId.isNotEmpty;
  @override
  Future<String?> idToken() async {
    if (!configured) {
      throw const ApiFailure(
        'Google ile giriş henüz kullanıma hazır değil. E-posta ile devam edebilirsin.',
      );
    }
    try {
      initialization ??= GoogleSignIn.instance.initialize(
        serverClientId: webId,
        clientId: iosId.isEmpty ? null : iosId,
      );
      await initialization;
      final account = await GoogleSignIn.instance.authenticate();
      final token = account.authentication.idToken;
      if (token == null) throw const ApiFailure('Google hesabı doğrulanamadı.');
      return token;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw const ApiFailure(
        'Google girişi tamamlanamadı. Başka bir yöntemle devam edebilirsin.',
      );
    }
  }
}
