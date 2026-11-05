import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taze_kal/data/product_repository.dart';
import 'package:taze_kal/domain/product.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });
  test(
    'v1 guest data survives migration; account queries, deletes and settings are isolated',
    () async {
      final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      addTearDown(db.close);
      await db.execute(
        'CREATE TABLE products (id TEXT PRIMARY KEY,name TEXT NOT NULL,quantity TEXT NOT NULL,location TEXT NOT NULL,purchased_at TEXT NOT NULL,expires_at TEXT NOT NULL,opened_at TEXT,after_opening_days INTEGER,status TEXT NOT NULL)',
      );
      await db.execute(
        'CREATE TABLE settings (key TEXT PRIMARY KEY,value TEXT NOT NULL)',
      );
      final sample = Product(
        id: 'existing',
        name: 'Süt',
        quantity: '1 L',
        location: 'Buzdolabı',
        purchasedAt: DateTime(2026, 10, 20),
        expiresAt: DateTime(2026, 10, 26),
      );
      final legacy = sample.toMap()
        ..remove('opening_profile_id')
        ..remove('cold_storage_confirmed');
      await db.insert('products', legacy);
      await SqliteProductRepository.upgradeSchema(db, 1, 2);
      await SqliteProductRepository.upgradeSchema(db, 2, 3);
      await db.transaction(
        (tx) => SqliteProductRepository.upgradeSchema(tx, 3, 4),
      );
      final guest = SqliteProductRepository(db),
          alice = SqliteProductRepository(db, 'alice'),
          bob = SqliteProductRepository(db, 'bob');
      expect((await guest.all()).single.name, 'Süt');
      expect((await guest.all()).single.openingProfileId, isNull);
      expect((await guest.all()).single.coldStorageConfirmed, isFalse);
      expect(await alice.all(), isEmpty);
      await guest.moveGuestTo('alice');
      expect(await guest.all(), isEmpty);
      expect((await alice.all()).single.id, 'existing');
      expect(await bob.all(), isEmpty);
      await bob.delete('existing');
      expect((await alice.all()).length, 1);
      final aliceProduct = (await alice.all()).single;
      await expectLater(bob.save(aliceProduct), throwsStateError);
      final newProduct = Product(
        id: 'batch-new',
        name: 'Pirinç',
        quantity: '1 kg',
        location: 'Kiler',
        purchasedAt: sample.purchasedAt,
        expiresAt: sample.expiresAt,
      );
      await expectLater(
        bob.saveAll([newProduct, aliceProduct]),
        throwsStateError,
      );
      expect(
        await bob.all(),
        isEmpty,
        reason: 'Failed batch must roll back earlier inserts',
      );
      await bob.saveAll([newProduct]);
      expect((await bob.all()).single.id, 'batch-new');
      expect((await alice.all()).single.id, 'existing');
      await alice.setSetting('notifications', 'true');
      await bob.setSetting('notifications', 'false');
      expect(await alice.setting('notifications'), 'true');
      expect(await bob.setting('notifications'), 'false');
      expect(await guest.setting('notifications'), isNull);
      final milk = Product(
        id: 'estimated',
        name: 'UHT süt',
        quantity: '1 L',
        location: 'Buzdolabı',
        purchasedAt: sample.purchasedAt,
        expiresAt: sample.expiresAt,
        openedAt: sample.purchasedAt,
        openingProfileId: 'milk_uht_v1',
        coldStorageConfirmed: true,
      );
      await alice.save(milk);
      final stored = (await alice.all()).firstWhere((p) => p.id == 'estimated');
      expect(stored.toMap(), milk.toMap());
      expect(stored.openingDays, 2);
      expect((await bob.all()).any((p) => p.id == 'estimated'), isFalse);
    },
  );
}
