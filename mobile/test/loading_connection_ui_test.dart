import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taze_kal/app.dart';
import 'package:taze_kal/auth/account_gate.dart';
import 'package:taze_kal/auth/auth_api.dart';
import 'package:taze_kal/auth/auth_controller.dart';
import 'package:taze_kal/auth/auth_screen.dart';
import 'package:taze_kal/design/taze_theme.dart';
import 'package:taze_kal/domain/product.dart';
import 'package:taze_kal/screens/home_screen.dart';
import 'package:taze_kal/widgets/connection_status.dart';
import 'package:taze_kal/widgets/loading_skeleton.dart';
import 'auth_controller_test.dart' show MemoryVault, FakeGoogle, session;
import 'logout_flow_test.dart' show AccountMemoryRepository;
import 'mobile_flow_test.dart' show MemoryRepository, FakeNotifications;

class LoadingRepository extends MemoryRepository {
  final ready = Completer<List<Product>>();
  @override
  Future<List<Product>> all() => ready.future;
}

void phone(WidgetTester tester, {Size size = const Size(375, 812)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets(
    'Cached account kitchen opens while server verification is still pending',
    (tester) async {
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
      final restoring = auth.restore();
      await tester.pumpWidget(
        TazeKalApp(
          auth: auth,
          repository: AccountMemoryRepository(),
          notifications: FakeNotifications(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(find.text('Mutfağın,\nkontrol altında.'), findsOneWidget);
      expect(find.byType(KitchenSkeleton), findsNothing);
      expect(auth.validating, true);
      response.completeError(http.ClientException('offline'));
      await restoring;
      await tester.pumpAndSettle();
      expect(
        find.text('Hesap hizmetine şu anda ulaşılamıyor.'),
        findsOneWidget,
      );
      expect(auth.user?.id, 'user-1');
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );

  for (final size in [const Size(375, 812), const Size(812, 375)]) {
    testWidgets('Offline banner remains scrollable with large text at $size', (
      tester,
    ) async {
      phone(tester, size: size);
      final auth = AuthController(
        api: AuthApi(
          baseUrl: 'http://localhost:3000/v1',
          client: MockClient((_) async => http.Response('{}', 503)),
        ),
        vault: MemoryVault(),
        google: FakeGoogle(),
      )..restoring = false;
      auth.api.connection = ApiConnection.unavailable;
      await tester.pumpWidget(
        MaterialApp(
          theme: TazeTheme.create(Brightness.dark),
          builder: (context, child) => AccountConnectionScope(
            auth: auth,
            child: MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
          ),
          home: HomeScreen(
            repository: MemoryRepository(),
            notifications: FakeNotifications(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Hesap hizmetine şu anda ulaşılamıyor.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    });
  }
  testWidgets('Kitchen skeleton is shown only while local data is pending', (
    tester,
  ) async {
    phone(tester);
    final repo = LoadingRepository();
    await tester.pumpWidget(
      TazeKalApp(repository: repo, notifications: FakeNotifications()),
    );
    expect(find.byType(KitchenSkeleton), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    repo.ready.complete([]);
    await tester.pumpAndSettle();
    expect(find.byType(KitchenSkeleton), findsNothing);
    expect(find.text('Mutfağın,\nkontrol altında.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'Reduced motion produces a static, labelled skeleton and no entrance movement',
    (tester) async {
      phone(tester);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const StartupSkeleton(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Mutfağın hazırlanıyor'), findsOneWidget);
      expect(tester.binding.hasScheduledFrame, false);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const MotionReveal(child: Text('Hazır')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final slide = tester.widget<SlideTransition>(
        find.descendant(
          of: find.byType(MotionReveal),
          matching: find.byType(SlideTransition),
        ),
      );
      expect(slide.position.value, Offset.zero);
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    },
  );

  testWidgets(
    'Slow login is single-submit and guest action cancels its late result',
    (tester) async {
      final response = Completer<http.Response>();
      var calls = 0, guest = false;
      final vault = MemoryVault();
      final auth = AuthController(
        api: AuthApi(
          baseUrl: 'http://localhost:3000/v1',
          slowAfter: const Duration(seconds: 1),
          client: MockClient((_) {
            calls++;
            return response.future;
          }),
        ),
        vault: vault,
        google: FakeGoogle(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: TazeTheme.create(Brightness.light),
          home: AuthScreen(auth: auth, onGuest: () => guest = true),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'E-posta'),
        'a@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Şifre'),
        'a-long-password',
      );
      await tester.scrollUntilVisible(
        find.text('Giriş yap'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Giriş yap'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(calls, 1);
      expect(find.textContaining('Tekrar basmana gerek yok'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Giriş yapılıyor…'),
      );
      expect(button.onPressed, isNull);
      await tester.scrollUntilVisible(
        find.text('Hesapsız devam et'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text('Hesapsız devam et'));
      await tester.pumpAndSettle();
      expect(guest, true);
      response.complete(http.Response(jsonEncode(session('late')), 200));
      await tester.pumpAndSettle();
      expect(auth.user, isNull);
      expect(vault.value, isNull);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );

  testWidgets(
    'Unavailable logout offers an explicit device-only exit; products and private notification isolation survive',
    (tester) async {
      phone(tester);
      var online = true, logoutCalls = 0;
      final vault = MemoryVault();
      final auth = AuthController(
        api: AuthApi(
          baseUrl: 'http://localhost:3000/v1',
          client: MockClient((req) async {
            if (req.url.path.endsWith('/logout')) logoutCalls++;
            if (!online) throw http.ClientException('offline');
            return http.Response(jsonEncode(session('access')), 200);
          }),
        ),
        vault: vault,
        google: FakeGoogle(),
      );
      await auth.login('a@example.com', 'a-long-password');
      auth.restoring = false;
      final repo = AccountMemoryRepository(),
          notifications = FakeNotifications();
      final today = calendarDay(DateTime.now());
      await repo.save(
        Product(
          id: 'milk',
          name: 'Süt',
          quantity: '1 L',
          location: 'Buzdolabı',
          purchasedAt: today,
          expiresAt: addCalendarDays(today, 3),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: TazeTheme.create(Brightness.light),
          builder: (_, child) =>
              AccountConnectionScope(auth: auth, child: child!),
          home: AccountGate(
            auth: auth,
            repository: repo,
            notifications: notifications,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Profilim'));
      await tester.pumpAndSettle();
      online = false;
      await tester.tap(find.text('Çıkış yap'));
      await tester.pumpAndSettle();
      expect(find.text('Bu cihazdan çıkış yapılsın mı?'), findsOneWidget);
      expect(
        auth.user,
        isNotNull,
        reason: 'Failed remote logout alone must not claim success',
      );
      await tester.tap(find.text('Bu cihazdan çık'));
      await tester.pumpAndSettle();
      expect(auth.user, isNull);
      expect(vault.value, isNull);
      expect(logoutCalls, 1);
      expect(repo.rows.values.single.name, 'Süt');
      expect(notifications.planned, isEmpty);
      expect(find.text('Yeniden\nhoş geldin.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );

  testWidgets(
    'Health checks stop in background and resume with one read-only check',
    (tester) async {
      var calls = 0;
      final methods = <String>[];
      final auth = AuthController(
        api: AuthApi(
          baseUrl: 'http://localhost:3000/v1',
          client: MockClient((req) async {
            methods.add(req.method);
            calls++;
            return http.Response('{}', 200);
          }),
        ),
        vault: MemoryVault(),
        google: FakeGoogle(),
      )..restoring = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        ConnectionWatch(auth: auth, child: const SizedBox()),
      );
      await tester.pump();
      expect(calls, 1);
      await tester.pump(const Duration(seconds: 31));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(auth.api.busy, false);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(minutes: 1));
      expect(calls, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(calls, 3);
      expect(methods, everyElement('GET'));
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );
}
