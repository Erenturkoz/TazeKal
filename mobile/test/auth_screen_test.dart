import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taze_kal/auth/auth_api.dart';
import 'package:taze_kal/auth/auth_controller.dart';
import 'package:taze_kal/auth/auth_screen.dart';
import 'package:taze_kal/design/taze_theme.dart';
import 'auth_controller_test.dart' show MemoryVault, FakeGoogle, session;

void main() {
  testWidgets(
    'Email form validates, signs in, and reports API failures inline',
    (tester) async {
      var fail = true;
      var calls = 0;
      final auth = AuthController(
        api: AuthApi(
          baseUrl: 'http://localhost:3000/v1',
          client: MockClient((request) async {
            calls++;
            expect(request.url.path, '/v1/auth/login');
            return fail
                ? http.Response(
                    '{"message":"E-posta veya şifre hatalı."}',
                    401,
                    headers: {
                      'content-type': 'application/json; charset=utf-8',
                    },
                  )
                : http.Response(
                    jsonEncode(session('access')),
                    200,
                    headers: {
                      'content-type': 'application/json; charset=utf-8',
                    },
                  );
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
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-posta'),
        'eren@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Şifre'),
        'a-strong-password',
      );
      await tester.scrollUntilVisible(
        find.text('Giriş yap'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giriş yap'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('E-posta veya şifre hatalı.'), findsOneWidget);
      expect(auth.user, isNull);
      fail = false;
      await tester.ensureVisible(find.text('Giriş yap'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giriş yap'));
      await tester.pumpAndSettle();
      expect(auth.user?.id, 'user-1');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Large-text login screen keeps Google and guest actions reachable',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      var guest = false;
      final auth = AuthController(
        api: AuthApi(client: MockClient((_) async => http.Response('{}', 500))),
        vault: MemoryVault(),
        google: FakeGoogle(),
      );
      addTearDown(auth.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: TazeTheme.create(Brightness.dark),
          home: AuthScreen(auth: auth, onGuest: () => guest = true),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Hesapsız devam et'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hesapsız devam et'));
      expect(guest, true);
      expect(tester.takeException(), isNull);
    },
  );
}
