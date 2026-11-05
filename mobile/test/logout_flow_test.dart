import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taze_kal/auth/account_gate.dart';
import 'package:taze_kal/auth/auth_api.dart';
import 'package:taze_kal/auth/auth_controller.dart';
import 'package:taze_kal/data/product_repository.dart';
import 'package:taze_kal/design/taze_theme.dart';
import 'package:taze_kal/domain/product.dart';
import 'auth_controller_test.dart' show MemoryVault, FakeGoogle, session;
import 'mobile_flow_test.dart' show MemoryRepository, FakeNotifications;

class AccountMemoryRepository extends MemoryRepository
    implements AccountProductRepository {
  @override
  AccountProductRepository forOwner(String ownerId) => this;
  @override
  Future<int> guestCount() async => 0;
  @override
  Future<void> moveGuestTo(String ownerId) async {}
}

void main() {
  testWidgets(
    'Top-bar profile exposes logout without scrolling; logout returns to login and preserves products',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var revoked = false;
      final vault = MemoryVault();
      final auth = AuthController(
        api: AuthApi(
          baseUrl: 'http://localhost:3000/v1',
          client: MockClient((request) async {
            if (request.url.path.endsWith('/logout')) {
              revoked = true;
              return http.Response('', 204);
            }
            return http.Response(
              jsonEncode(session('access')),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        ),
        vault: vault,
        google: FakeGoogle(),
      );
      await auth.login('eren@example.com', 'a-strong-password');
      auth.restoring = false;
      addTearDown(auth.dispose);
      final repository = AccountMemoryRepository();
      final today = calendarDay(DateTime.now());
      await repository.save(
        Product(
          id: 'milk',
          name: 'Süt',
          quantity: '1 L',
          location: 'Buzdolabı',
          purchasedAt: today,
          expiresAt: addCalendarDays(today, 3),
        ),
      );
      final notifications = FakeNotifications();
      await tester.pumpWidget(
        MaterialApp(
          theme: TazeTheme.create(Brightness.light),
          home: AccountGate(
            auth: auth,
            repository: repository,
            notifications: notifications,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Profilim'), findsOneWidget);
      await tester.tap(find.byTooltip('Profilim'));
      await tester.pumpAndSettle();
      expect(find.text('Çıkış yap').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Çıkış yap'));
      await tester.pumpAndSettle();
      expect(revoked, true);
      expect(auth.user, isNull);
      expect(vault.value, isNull);
      expect(find.text('Giriş yap'), findsOneWidget);
      expect(repository.rows['milk']?.name, 'Süt');
      expect(notifications.planned, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
