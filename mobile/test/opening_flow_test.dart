import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taze_kal/app.dart';
import 'package:taze_kal/design/taze_theme.dart';
import 'package:taze_kal/domain/product.dart';
import 'package:taze_kal/screens/product_form.dart';
import 'mobile_flow_test.dart' show MemoryRepository, FakeNotifications;

void main() {
  testWidgets(
    'Opened milk form remains readable with large text on a narrow phone',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = calendarDay(DateTime.now());
      final p = Product(
        id: 'large',
        name: 'Uzun ömürlü süt',
        quantity: '1 L',
        location: 'Buzdolabı',
        purchasedAt: now,
        expiresAt: addCalendarDays(now, 7),
        openingProfileId: 'milk_uht_v1',
        coldStorageConfirmed: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: TazeTheme.create(Brightness.dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: ProductForm(product: p, markOpened: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Mark milk opened without entering days; estimate and unopened comparison are shown',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final today = calendarDay(DateTime.now());
      final repo = MemoryRepository();
      await repo.save(
        Product(
          id: 'milk',
          name: 'Süt',
          quantity: '1 L',
          location: 'Buzdolabı',
          purchasedAt: addCalendarDays(today, -3),
          expiresAt: addCalendarDays(today, 5),
          openingProfileId: 'milk_uht_v1',
          coldStorageConfirmed: true,
        ),
      );
      final notifications = FakeNotifications();
      await tester.pumpWidget(
        TazeKalApp(repository: repo, notifications: notifications),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Bugün açtım'),
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Bugün açtım'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bugün açtım'));
      await tester.pumpAndSettle();
      expect(find.text('Açılmayı kaydet'), findsOneWidget);
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      final saved = repo.rows.values.single;
      expect(saved.afterOpeningDays, isNull);
      expect(saved.openedAt, today);
      expect(saved.daysLeft(today), 2);
      expect(saved.unopenedDaysLeft(today), 5);
      await tester.scrollUntilVisible(
        find.textContaining('Açılmamış olsaydı ambalaj tarihine'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text('Açılmamış olsaydı ambalaj tarihine 5 gün kalacaktı.'),
        findsOneWidget,
      );
      expect(find.textContaining('3 gün önce aldın'), findsOneWidget);
      expect(
        notifications.planned.single.effectiveExpiry,
        addCalendarDays(today, 2),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Milk category and cold condition can be completed without supplying a duration',
    (tester) async {
      final today = calendarDay(DateTime.now());
      final p = Product(
        id: 'plain',
        name: 'Süt',
        quantity: '1 L',
        location: 'Buzdolabı',
        purchasedAt: today,
        expiresAt: addCalendarDays(today, 5),
      );
      await tester.pumpWidget(
        MaterialApp(home: ProductForm(product: p, markOpened: true)),
      );
      await tester.tap(find.text('Diğer / tür belirtilmedi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('UHT / uzun ömürlü süt').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(find.text('Tahmini 2 gün kaldı'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
