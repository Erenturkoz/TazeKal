import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taze_kal/auth/auth_api.dart';
import 'package:taze_kal/auth/auth_controller.dart';
import 'package:taze_kal/auth/session_vault.dart';
import 'package:taze_kal/auth/google_identity.dart';

class MemoryVault implements SessionVault {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class FakeGoogle implements GoogleIdentityProvider {
  @override
  bool get configured => true;
  @override
  Future<String?> idToken() async => 'verified-by-the-server';
}

const user = {
  'id': 'user-1',
  'email': 'eren@example.com',
  'displayName': 'Eren',
  'emailVerified': false,
  'providers': ['password'],
};
Map<String, dynamic> session(String token) => {
  'accessToken': token,
  'refreshToken': 'refresh-$token',
  'user': user,
};

void main() {
  test(
    'Login persists a session and Google exchanges an ID token with the backend',
    () async {
      final vault = MemoryVault();
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/google')) {
          expect(jsonDecode(request.body)['idToken'], 'verified-by-the-server');
        }
        return http.Response(jsonEncode(session('access-1')), 200);
      });
      final auth = AuthController(
        api: AuthApi(client: client, baseUrl: 'http://localhost:3000/v1'),
        vault: vault,
        google: FakeGoogle(),
      );
      await auth.login('eren@example.com', 'a-strong-password');
      expect(auth.user?.id, 'user-1');
      expect(jsonDecode(vault.value!)['refreshToken'], 'refresh-access-1');
      await auth.loginGoogle();
      expect(auth.user?.email, 'eren@example.com');
      auth.dispose();
    },
  );
  test(
    '401 refreshes once and logout revokes before clearing local credentials',
    () async {
      final vault = MemoryVault()..value = jsonEncode(session('old'));
      var refreshes = 0;
      var revoked = false;
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/refresh')) {
          refreshes++;
          return http.Response(jsonEncode(session('new')), 200);
        }
        if (req.url.path.endsWith('/logout')) {
          revoked = true;
          return http.Response('', 204);
        }
        if (req.headers['Authorization'] == 'Bearer old') {
          return http.Response('{"message":"expired"}', 401);
        }
        return http.Response(jsonEncode(user), 200);
      });
      final auth = AuthController(
        api: AuthApi(client: client, baseUrl: 'http://localhost:3000/v1'),
        vault: vault,
        google: FakeGoogle(),
      );
      await auth.restore();
      expect(refreshes, 1);
      expect(auth.user?.id, 'user-1');
      await auth.logout();
      expect(revoked, true);
      expect(auth.user, isNull);
      expect(vault.value, isNull);
      auth.dispose();
    },
  );
  test(
    'Offline restore keeps cached identity; rejected refresh removes credentials',
    () async {
      final vault = MemoryVault()..value = jsonEncode(session('cached'));
      var reject = false;
      final client = MockClient((_) async {
        if (!reject) throw http.ClientException('offline');
        return http.Response('{"message":"revoked"}', 401);
      });
      final auth = AuthController(
        api: AuthApi(client: client, baseUrl: 'http://localhost:3000/v1'),
        vault: vault,
        google: FakeGoogle(),
      );
      await auth.restore();
      expect(auth.user?.id, 'user-1');
      expect(auth.offline, true);
      reject = true;
      await auth.restore();
      expect(auth.user, isNull);
      expect(vault.value, isNull);
      auth.dispose();
    },
  );
}
