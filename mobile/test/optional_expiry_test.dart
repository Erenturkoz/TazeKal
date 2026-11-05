import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taze_kal/app.dart';
import 'package:taze_kal/domain/product.dart';
import 'package:taze_kal/domain/reminder.dart';
import 'package:taze_kal/domain/shelf_life_profile.dart';
import 'package:taze_kal/data/product_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'mobile_flow_test.dart' show MemoryRepository, FakeNotifications;

void main() {
  test(
    'Only matching refrigerated foods get source-based estimates; ambiguous foods remain unknown',
    () {
      expect(
        ShelfLifeProfile.suggest('Günlük süt', 'Buzdolabı', null)!.days,
        5,
      );
      expect(
        ShelfLifeProfile.suggest('Yumurta 10 adet', 'Buzdolabı', null)!.days,
        21,
      );
      expect(ShelfLifeProfile.suggest('UHT süt', 'Buzdolabı', null), isNull);
      expect(ShelfLifeProfile.suggest('Çiğ süt', 'Buzdolabı', null), isNull);
      expect(
        ShelfLifeProfile.suggest('Tavuk çorbası', 'Buzdolabı', null),
        isNull,
      );
      expect(
        ShelfLifeProfile.suggest('Yumurta salatası', 'Buzdolabı', null),
        isNull,
      );
      expect(ShelfLifeProfile.suggest('Badem sütü', 'Buzdolabı', null), isNull);
      expect(ShelfLifeProfile.suggest('Yumurta', 'Dondurucu', null), isNull);
      expect(ShelfLifeProfile.suggest('Pirinç', 'Kiler', null), isNull);
    },
  );
  test(
    'Unknown dates never produce expiry notifications or become overdue; opening instructions still work',
    () {
      final now = DateTime(2026, 11, 4);
      final p = Product(
        id: 'unknown',
        name: 'Ürün',
        quantity: '1 adet',
        location: 'Kiler',
        purchasedAt: now,
      );
      expect(p.hasTrackingDate, isFalse);
      expect(p.isArchived(addCalendarDays(now, 365)), isFalse);
      expect(buildReminders([p], now, 10, 0), isEmpty);
      final opened = Product(
        id: 'opened',
        name: 'Ürün',
        quantity: '1 adet',
        location: 'Buzdolabı',
        purchasedAt: now,
        openedAt: now,
        afterOpeningDays: 2,
      );
      expect(opened.effectiveExpiry, addCalendarDays(now, 2));
      expect(opened.hasTrackingDate, isTrue);
      expect(buildReminders([opened], now, 10, 0), isNotEmpty);
      expect(Product.fromMap(p.toMap()).expiresAt, isNull);
    },
  );
  test(
    'v4 upgrade preserves old outbox payloads and revisions, then accepts nullable expiry',
    () async {
      sqfliteFfiInit();
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await db.execute(SqliteProductRepository.tableSql('products'));
      await db.execute(
        'CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)',
      );
      await SqliteProductRepository.syncTables(db);
      final repo = SqliteProductRepository(db, 'alice');
      final old = Product(
        id: 'old',
        name: 'Eski ürün',
        quantity: '1 adet',
        location: 'Kiler',
        purchasedAt: DateTime(2026, 11, 1),
        expiresAt: DateTime(2026, 11, 30),
      );
      await repo.save(old);
      final before = (await repo.claimPending()).single;
      await db.transaction(
        (tx) => SqliteProductRepository.upgradeSchema(tx, 4, 5),
      );
      expect((await repo.claimPending()).single.toJson(), before.toJson());
      expect((await repo.all()).single.localRevision, 1);
      await repo.save(
        Product(
          id: 'new',
          name: 'Tarihsiz',
          quantity: '1 adet',
          location: 'Kiler',
          purchasedAt: DateTime(2026, 11, 4),
          expirySource: 'unknown',
        ),
      );
      expect(
        (await repo.all()).where((p) => p.id == 'new').single.expiresAt,
        isNull,
      );
    },
  );
  testWidgets(
    'Main inventory hides expired and consumed products; history separates both and badges overdue',
    (tester) async {
      final now = calendarDay(DateTime.now()), repo = MemoryRepository();
      Product item(String id, {DateTime? expiry, String status = 'active'}) =>
          Product(
            id: id,
            name: id,
            quantity: '1 adet',
            location: 'Buzdolabı',
            purchasedAt: now,
            expiresAt: expiry,
            status: status,
          );
      await repo.saveAll([
        item('Tarihsiz ürün'),
        item('Geçmiş yumurta', expiry: addCalendarDays(now, -1)),
        item(
          'Tüketilmiş süt',
          expiry: addCalendarDays(now, 5),
          status: 'consumed',
        ),
      ]);
      await tester.pumpWidget(
        TazeKalApp(repository: repo, notifications: FakeNotifications()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Geçmiş yumurta'), findsNothing);
      expect(find.text('Tüketilmiş süt'), findsNothing);
      expect(
        tester
            .widgetList<Badge>(find.byType(Badge))
            .any((b) => b.isLabelVisible),
        isTrue,
      );
      await tester.tap(find.text('Geçmiş'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Geçmiş yumurta'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Geçmiş yumurta'), findsOneWidget);
      expect(find.text('Tüketilmiş süt'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Tüketilenler (1)'),
        -250,
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
        find.text('Tüketilmiş süt'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Tüketilmiş süt'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
