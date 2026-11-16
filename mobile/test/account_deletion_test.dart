import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taze_kal/auth/account_gate.dart';
import 'package:taze_kal/auth/auth_api.dart';
import 'package:taze_kal/auth/auth_controller.dart';
import 'package:taze_kal/auth/auth_screen.dart';
import 'package:taze_kal/auth/google_identity.dart';
import 'package:taze_kal/data/product_repository.dart';
import 'package:taze_kal/design/taze_theme.dart';
import 'package:taze_kal/domain/product.dart';
import 'package:taze_kal/legal/legal_texts.dart';
import 'auth_controller_test.dart' show MemoryVault, FakeGoogle, session, user;
import 'logout_flow_test.dart' show AccountMemoryRepository;
import 'mobile_flow_test.dart' show FakeNotifications;

class CancelledGoogle implements GoogleIdentityProvider {
  @override
  bool get configured => true;
  @override
  Future<String?> idToken() async => null;
}

http.Response json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> googleOnlySession() => {
  ...session('access'),
  'user': {
    ...user,
    'providers': ['google'],
  },
};

Product milk(String id) => Product(
  id: id,
  name: 'Süt',
  quantity: '1 L',
  location: 'Buzdolabı',
  purchasedAt: DateTime(2026, 11, 10),
  expiresAt: DateTime(2026, 11, 20),
);

void main() {
  setUpAll(sqfliteFfiInit);

  group('AuthController.deleteAccount', () {
    test(
      'password accounts send the password, then clear local credentials',
      () async {
        final requests = <http.Request>[];
        final vault = MemoryVault();
        final auth = AuthController(
          api: AuthApi(
            baseUrl: 'http://localhost:3000/v1',
            client: MockClient((request) async {
              requests.add(request);
              if (request.method == 'DELETE') {
                final body = jsonDecode(request.body);
                if (body['password'] != 'a-strong-password') {
                  return json({
                    'message': 'Şifre hatalı. Hesabın silinmedi.',
                  }, 403);
                }
                return http.Response('', 204);
              }
              return json(session('access'));
            }),
          ),
          vault: vault,
          google: FakeGoogle(),
        );
        addTearDown(auth.dispose);
        await auth.login('eren@example.com', 'a-strong-password');

        await expectLater(auth.deleteAccount(), throwsA(isA<ApiFailure>()));
        expect(requests.where((r) => r.method == 'DELETE'), isEmpty);

        // A wrong password is a 403: the session must stay and no refresh happens.
        await expectLater(
          auth.deleteAccount(password: 'wrong'),
          throwsA(isA<ApiFailure>().having((e) => e.status, 'status', 403)),
        );
        expect(auth.user, isNotNull);
        expect(vault.value, isNotNull);
        expect(requests.where((r) => r.url.path.endsWith('/refresh')), isEmpty);

        await auth.deleteAccount(password: 'a-strong-password');
        final delete = requests.last;
        expect(delete.method, 'DELETE');
        expect(delete.url.path, '/v1/users/me');
        expect(delete.headers['Authorization'], 'Bearer access');
        expect(auth.user, isNull);
        expect(vault.value, isNull);
      },
    );

    test(
      'Google-only accounts re-authenticate with Google and a dismissed prompt deletes nothing',
      () async {
        Map<String, dynamic>? deleted;
        final vault = MemoryVault()..value = jsonEncode(googleOnlySession());
        AuthController build(GoogleIdentityProvider google) => AuthController(
          api: AuthApi(
            baseUrl: 'http://localhost:3000/v1',
            client: MockClient((request) async {
              if (request.method == 'DELETE') {
                deleted = jsonDecode(request.body) as Map<String, dynamic>;
                return http.Response('', 204);
              }
              return json(googleOnlySession()['user'] as Object);
            }),
          ),
          vault: vault,
          google: google,
        );
        final cancelled = build(CancelledGoogle());
        addTearDown(cancelled.dispose);
        await cancelled.restore();
        await expectLater(
          cancelled.deleteAccount(),
          throwsA(
            isA<ApiFailure>().having((e) => e.cancelled, 'cancelled', true),
          ),
        );
        expect(deleted, isNull);
        expect(cancelled.user, isNotNull);

        final auth = build(FakeGoogle());
        addTearDown(auth.dispose);
        await auth.restore();
        await auth.deleteAccount();
        expect(deleted, {'idToken': 'verified-by-the-server'});
        expect(auth.user, isNull);
        expect(vault.value, isNull);
      },
    );
  });

  test(
    'deleteOwnerData erases only the deleted account, never guest or other accounts',
    () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await db.execute(SqliteProductRepository.tableSql('products'));
      await db.execute(
        'CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)',
      );
      await SqliteProductRepository.syncTables(db);
      final guest = SqliteProductRepository(db),
          gone = guest.forOwner('user_1'),
          other = guest.forOwner('user11');
      for (final repo in [guest, gone, other]) {
        await repo.save(milk('milk'));
        await repo.setSetting('reminder_hour', '9');
      }
      await db.insert('product_sync_state', {
        'owner_id': 'user_1',
        'cursor': 3,
      });
      await db.insert('product_sync_state', {
        'owner_id': 'user11',
        'cursor': 4,
      });

      await guest.deleteOwnerData('user_1');
      await guest.deleteOwnerData('guest'); // must be a no-op

      expect(await gone.all(), isEmpty);
      expect(await gone.setting('reminder_hour'), isNull);
      expect(await gone.pendingCount(), 0);
      expect(await gone.cursor(), 0);
      expect(
        await db.query('products', where: 'owner_id=?', whereArgs: ['user_1']),
        isEmpty,
      );
      // `_` in the id must not act as a LIKE wildcard for user11's settings.
      expect((await other.all()).single.id, 'milk');
      expect(await other.setting('reminder_hour'), '9');
      expect(await other.pendingCount(), 1);
      expect(await other.cursor(), 4);
      expect((await guest.all()).single.id, 'milk');
      expect(await guest.setting('reminder_hour'), '9');
    },
  );

  testWidgets(
    'Profile deletion needs confirmation, then removes local account data and returns to login',
    (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var deletes = 0;
      final vault = MemoryVault();
      final auth = AuthController(
        api: AuthApi(
          baseUrl: 'http://localhost:3000/v1',
          client: MockClient((request) async {
            if (request.method == 'DELETE') {
              deletes++;
              return http.Response('', 204);
            }
            return json(session('access'));
          }),
        ),
        vault: vault,
        google: FakeGoogle(),
      );
      await auth.login('eren@example.com', 'a-strong-password');
      auth.restoring = false;
      addTearDown(auth.dispose);
      final repository = AccountMemoryRepository();
      await repository.save(milk('milk'));
      await tester.pumpWidget(
        MaterialApp(
          theme: TazeTheme.create(Brightness.light),
          home: AccountGate(
            auth: auth,
            repository: repository,
            notifications: FakeNotifications(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Profilim'));
      await tester.pumpAndSettle();

      final open = find.text('Hesabımı sil');
      await tester.scrollUntilVisible(
        open,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(open);
      await tester.pumpAndSettle();

      final confirm = find.widgetWithText(
        FilledButton,
        'Hesabımı kalıcı olarak sil',
      );
      FilledButton button() => tester.widget<FilledButton>(confirm);
      expect(button().onPressed, isNull);
      await tester.enterText(find.byKey(const Key('delete-password')), 'pw');
      await tester.pump();
      expect(button().onPressed, isNull, reason: 'checkbox still unticked');

      // Cancelling keeps everything.
      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();
      expect(deletes, 0);
      expect(repository.rows, isNotEmpty);

      await tester.tap(open);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('delete-password')),
        'a-strong-password',
      );
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      expect(button().onPressed, isNotNull);
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(deletes, 1);
      expect(auth.user, isNull);
      expect(vault.value, isNull);
      expect(repository.deletedOwners, ['user-1']);
      expect(repository.rows, isEmpty);
      expect(find.byType(AuthScreen), findsOneWidget);
      expect(find.text('Hesabın ve verilerin silindi.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Sign-up is blocked until the Terms are accepted and sends the accepted version',
    (tester) async {
      Map<String, dynamic>? sent;
      final auth = AuthController(
        api: AuthApi(
          baseUrl: 'http://localhost:3000/v1',
          client: MockClient((request) async {
            sent = jsonDecode(request.body) as Map<String, dynamic>;
            return json(session('access'), 201);
          }),
        ),
        vault: MemoryVault(),
        google: FakeGoogle(),
      );
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: TazeTheme.create(Brightness.light),
          home: AuthScreen(auth: auth),
        ),
      );
      final scroll = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Hesabım yok · Kayıt ol'),
        200,
        scrollable: scroll,
      );
      await tester.tap(find.text('Hesabım yok · Kayıt ol'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Adın'),
        'Eren',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-posta'),
        'eren@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Şifre'),
        'a-strong-password',
      );
      final submit = find.widgetWithText(FilledButton, 'Hesap oluştur');
      await tester.scrollUntilVisible(submit, 150, scrollable: scroll);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(sent, isNull);
      expect(
        find.text('Hesap oluşturmak için koşulları kabul etmelisin.'),
        findsOneWidget,
      );

      // The linked documents open from the consent line.
      await tester.ensureVisible(find.byKey(const Key('accept-terms')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kullanım Koşulları').first);
      await tester.pumpAndSettle();
      expect(find.text('1. Taraflar ve kapsam'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('accept-terms')));
      await tester.pump();
      await tester.ensureVisible(submit);
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(sent?['acceptedTermsVersion'], termsVersion);
      expect(auth.user?.id, 'user-1');
    },
  );
}
