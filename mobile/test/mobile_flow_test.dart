import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taze_kal/app.dart';
import 'package:taze_kal/data/product_repository.dart';
import 'package:taze_kal/domain/product.dart';
import 'package:taze_kal/services/notification_service.dart';

class MemoryRepository implements ProductRepository {
  final rows = <String, Product>{};
  final settings = <String, String>{};
  @override
  Future<List<Product>> all() async => rows.values.toList();
  @override
  Future<void> save(Product product) async {
    rows[product.id] = product;
  }

  @override
  Future<void> saveAll(List<Product> products) async {
    for (final product in products) {
      rows[product.id] = product;
    }
  }

  @override
  Future<void> delete(String id) async {
    rows.remove(id);
  }

  @override
  Future<String?> setting(String key) async => settings[key];
  @override
  Future<void> setSetting(String key, String value) async {
    settings[key] = value;
  }
}

class FakeNotifications extends NotificationService {
  List<Product> planned = [];
  @override
  Future<bool> reschedule(
    List<Product> products, {
    required bool enabled,
    required int hour,
    required int minute,
  }) async {
    planned = products.where((p) => p.status == 'active').toList();
    return false;
  }

  @override
  Future<bool> requestPermission() async => true;
}

void main() {
  testWidgets('Depolama sekmeleri yalnız kendi stoklarını gösterir', (
    tester,
  ) async {
    final repo = MemoryRepository();
    final now = calendarDay(DateTime.now());
    for (final entry in {
      'Süt': 'Buzdolabı',
      'Pirinç': 'Kiler',
      'Bezelye': 'Dondurucu',
    }.entries) {
      await repo.save(
        Product(
          id: entry.key,
          name: entry.key,
          quantity: '1 paket',
          location: entry.value,
          purchasedAt: now,
          expiresAt: addCalendarDays(now, 10),
        ),
      );
    }
    await tester.pumpWidget(
      TazeKalApp(repository: repo, notifications: FakeNotifications()),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Kiler'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiler'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Pirinç'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Pirinç'), findsOneWidget);
    expect(find.text('Süt'), findsNothing);
    expect(find.text('Bezelye'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final brightness in Brightness.values) {
    testWidgets('Büyük metin ve ${brightness.name} temada taşma yok', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.pumpWidget(
        TazeKalApp(
          repository: MemoryRepository(),
          notifications: FakeNotifications(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Dondurucu'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final size in [const Size(375, 812), const Size(812, 375)]) {
    testWidgets('Ana ekran ${size.width} genişlikte taşmaz', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        TazeKalApp(
          repository: MemoryRepository(),
          notifications: FakeNotifications(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mutfağın,\nkontrol altında.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('Ürün eklenir, açılır, tüketilir ve hatırlatmadan çıkar', (
    tester,
  ) async {
    final repo = MemoryRepository(), notifications = FakeNotifications();
    await tester.pumpWidget(
      TazeKalApp(repository: repo, notifications: notifications),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ürün ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elle ürün ekle'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ürün adı'),
      'Günlük süt',
    );
    await tester.scrollUntilVisible(
      find.text('Son tüketim tarihi'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Son tüketim tarihi')),
      alignment: 0,
    );
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -150),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Son tüketim tarihi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Ambalajda özel talimat varsa'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Ambalajda özel talimat varsa'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Tüketim süresi (gün)'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Tüketim süresi (gün)'),
      '3',
    );
    await tester.scrollUntilVisible(
      find.text('Kaydet'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(repo.rows.values.single.name, 'Günlük süt');
    await tester.scrollUntilVisible(
      find.text('Bugün açtım'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bugün açtım'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bugün açtım'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(repo.rows.values.single.openedAt, isNotNull);
    await tester.ensureVisible(find.text('Tükettim'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tükettim'));
    await tester.pumpAndSettle();
    expect(repo.rows.values.single.status, 'consumed');
    expect(notifications.planned, isEmpty);
    await tester.tap(find.text('Geçmiş'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Tüketilenler (1)'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Tüketilenler (1)')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tüketilenler (1)'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Günlük süt'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Günlük süt'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
