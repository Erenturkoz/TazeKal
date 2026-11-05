import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taze_kal/auth/auth_api.dart';
import 'package:taze_kal/auth/auth_controller.dart';
import 'auth_controller_test.dart' show MemoryVault, FakeGoogle, session, user;

class StreamClient extends http.BaseClient {
  StreamClient(this.respond);
  final Future<http.StreamedResponse> Function(http.BaseRequest) respond;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      respond(request);
}

class DelayedVault extends MemoryVault {
  bool delay = false;
  final started = Completer<void>(), release = Completer<void>();
  @override
  Future<void> write(String value) async {
    if (delay) {
      if (!started.isCompleted) started.complete();
      await release.future;
    }
    await super.write(value);
  }
}

void main() {
  test(
    'Late background profile data cannot overwrite a newer rename',
    () async {
      final oldProfile = Completer<http.Response>();
      final vault = MemoryVault()..value = jsonEncode(session('cached'));
      final auth = AuthController(
        api: AuthApi(
          baseUrl: 'http://localhost:3000/v1',
          client: MockClient((req) async {
            if (req.method == 'GET') return oldProfile.future;
            return http.Response(
              jsonEncode({...user, 'displayName': 'Yeni ad'}),
              200,
            );
          }),
        ),
        vault: vault,
        google: FakeGoogle(),
      );
      addTearDown(auth.dispose);
      final restore = auth.restore();
      await Future<void>.delayed(Duration.zero);
      await auth.rename('Yeni ad');
      oldProfile.complete(http.Response(jsonEncode(user), 200));
      await restore;
      expect(auth.user?.displayName, 'Yeni ad');
      expect(jsonDecode(vault.value!)['user']['displayName'], 'Yeni ad');
    },
  );
  testWidgets(
    'One deadline covers headers plus slow body; aborts and ignores a late response',
    (tester) async {
      final headers = Completer<http.StreamedResponse>();
      final body = StreamController<List<int>>();
      var calls = 0, aborted = false;
      final api = AuthApi(
        baseUrl: 'http://localhost:3000/v1',
        requestTimeout: const Duration(seconds: 2),
        slowAfter: const Duration(seconds: 1),
        client: StreamClient((request) {
          calls++;
          expect(request, isA<http.AbortableRequest>());
          (request as http.AbortableRequest).abortTrigger!.then(
            (_) => aborted = true,
          );
          return headers.future;
        }),
      );
      addTearDown(api.dispose);
      final result = expectLater(
        api.call('POST', '/auth/register'),
        throwsA(
          isA<ApiFailure>()
              .having((e) => e.kind, 'kind', ApiFailureKind.timeout)
              .having((e) => e.mayHaveCompleted, 'uncertain mutation', true),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(api.slow, true);
      headers.complete(http.StreamedResponse(body.stream, 200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1100));
      await result;
      expect(aborted, true);
      expect(calls, 1);
      expect(api.busy, false);
      expect(api.connection, ApiConnection.unavailable);
      body.add(utf8.encode('{}'));
      await body.close();
      await tester.pump();
      expect(
        api.connection,
        ApiConnection.unavailable,
        reason: 'Late response cannot reset the timeout state',
      );
    },
  );

  test(
    'HTML errors retain HTTP status; unauthorized is reachable and malformed success is distinct',
    () async {
      var code = 503;
      final api = AuthApi(
        baseUrl: 'http://localhost:3000/v1',
        client: MockClient(
          (_) async => http.Response('<html>bad gateway</html>', code),
        ),
      );
      addTearDown(api.dispose);
      await expectLater(
        api.call('POST', '/auth/login'),
        throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 503)),
      );
      expect(api.connection, ApiConnection.unavailable);
      code = 401;
      await expectLater(
        api.call('GET', '/users/me'),
        throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 401)),
      );
      expect(api.connection, ApiConnection.available);
      code = 200;
      await expectLater(
        api.call('GET', '/users/me'),
        throwsA(
          isA<ApiFailure>().having(
            (e) => e.kind,
            'kind',
            ApiFailureKind.invalidResponse,
          ),
        ),
      );
    },
  );

  test(
    'Cached kitchen is available before slow account verification finishes',
    () async {
      final response = Completer<http.Response>();
      final vault = MemoryVault()..value = jsonEncode(session('cached'));
      final auth = AuthController(
        api: AuthApi(
          baseUrl: 'http://localhost:3000/v1',
          client: MockClient((_) => response.future),
        ),
        vault: vault,
        google: FakeGoogle(),
      );
      addTearDown(auth.dispose);
      final restoring = auth.restore();
      await Future<void>.delayed(Duration.zero);
      expect(auth.restoring, false);
      expect(auth.validating, true);
      expect(auth.user?.id, 'user-1');
      response.complete(http.Response(jsonEncode(user), 200));
      await restoring;
      expect(auth.offline, false);
    },
  );

  test(
    'Offline keeps local identity; recovery revalidates; rejected sessions are removed',
    () async {
      var online = false, reject = false;
      final vault = MemoryVault()..value = jsonEncode(session('cached'));
      final auth = AuthController(
        api: AuthApi(
          baseUrl: 'http://localhost:3000/v1',
          client: MockClient((_) async {
            if (!online) throw http.ClientException('No route');
            return reject
                ? http.Response('{}', 401)
                : http.Response(jsonEncode(user), 200);
          }),
        ),
        vault: vault,
        google: FakeGoogle(),
      );
      addTearDown(auth.dispose);
      await auth.restore();
      expect(auth.offline, true);
      expect(auth.user?.id, 'user-1');
      online = true;
      await auth.revalidate();
      expect(auth.offline, false);
      expect(auth.user?.id, 'user-1');
      reject = true;
      await auth.revalidate();
      expect(auth.user, isNull);
      expect(vault.value, isNull);
    },
  );

  test('Cancelled login cannot sign in later or persist tokens', () async {
    final response = Completer<http.Response>();
    final vault = MemoryVault();
    final auth = AuthController(
      api: AuthApi(
        baseUrl: 'http://localhost:3000/v1',
        client: MockClient((_) => response.future),
      ),
      vault: vault,
      google: FakeGoogle(),
    );
    addTearDown(auth.dispose);
    final login = expectLater(
      auth.login('a@example.com', 'password-long'),
      throwsA(isA<ApiFailure>().having((e) => e.cancelled, 'cancelled', true)),
    );
    await Future<void>.delayed(Duration.zero);
    await auth.cancelAuthentication();
    await login;
    response.complete(http.Response(jsonEncode(session('late')), 200));
    await Future<void>.delayed(Duration.zero);
    expect(auth.user, isNull);
    expect(vault.value, isNull);
  });

  test(
    'Cancelling during a slow secure-store write clears that write before guest access',
    () async {
      final vault = DelayedVault()..delay = true;
      final auth = AuthController(
        api: AuthApi(
          baseUrl: 'http://localhost:3000/v1',
          client: MockClient(
            (_) async => http.Response(jsonEncode(session('late')), 200),
          ),
        ),
        vault: vault,
        google: FakeGoogle(),
      );
      addTearDown(auth.dispose);
      final login = expectLater(
        auth.login('a@example.com', 'password-long'),
        throwsA(
          isA<ApiFailure>().having((e) => e.cancelled, 'cancelled', true),
        ),
      );
      await vault.started.future;
      final cancelled = auth.cancelAuthentication();
      vault.release.complete();
      await cancelled;
      await login;
      expect(auth.user, isNull);
      expect(vault.value, isNull);
    },
  );

  test(
    'Late profile response cannot restore an old account after local logout and new login',
    () async {
      final oldProfile = Completer<http.Response>();
      final vault = MemoryVault()..value = jsonEncode(session('old'));
      var newLogin = false;
      final auth = AuthController(
        api: AuthApi(
          baseUrl: 'http://localhost:3000/v1',
          client: MockClient((req) async {
            if (req.url.path.endsWith('/users/me')) return oldProfile.future;
            final data = session('new');
            data['user'] = {...user, 'id': 'user-2', 'email': 'b@example.com'};
            newLogin = true;
            return http.Response(jsonEncode(data), 200);
          }),
        ),
        vault: vault,
        google: FakeGoogle(),
      );
      addTearDown(auth.dispose);
      final restore = auth.restore();
      await Future<void>.delayed(Duration.zero);
      await auth.logoutLocally();
      await auth.login('b@example.com', 'long-password');
      oldProfile.complete(http.Response(jsonEncode(user), 200));
      await restore;
      expect(newLogin, true);
      expect(auth.user?.id, 'user-2');
      expect(jsonDecode(vault.value!)['user']['id'], 'user-2');
    },
  );
}
