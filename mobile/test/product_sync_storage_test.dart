import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taze_kal/data/product_repository.dart';
import 'package:taze_kal/data/sync_models.dart';
import 'package:taze_kal/data/form_draft.dart';
import 'package:taze_kal/domain/product.dart';

Product milk([String name = 'Süt']) => Product(
  id: 'milk',
  name: name,
  quantity: '1 L',
  location: 'Buzdolabı',
  purchasedAt: DateTime(2026, 11, 1),
  expiresAt: DateTime(2026, 11, 10),
);
RemoteProduct remote(int version, {Product? product, bool deleted = false}) =>
    RemoteProduct(
      id: 'milk',
      version: version,
      cursor: version,
      deleted: deleted,
      product: deleted ? null : product ?? milk(),
    );

void main() {
  late Database db;
  late SqliteProductRepository a, b;
  setUpAll(sqfliteFfiInit);
  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await db.execute(SqliteProductRepository.tableSql('products'));
    await db.execute(
      'CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)',
    );
    await SqliteProductRepository.syncTables(db);
    a = SqliteProductRepository(db, 'alice');
    b = a.forOwner('bob');
  });
  tearDown(() => db.close());

  test(
    'v3 migration preserves account and guest products and queues only account records',
    () async {
      final legacy = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(legacy.close);
      await legacy.execute(
        'CREATE TABLE products(id TEXT PRIMARY KEY,name TEXT NOT NULL,quantity TEXT NOT NULL,location TEXT NOT NULL,purchased_at TEXT NOT NULL,expires_at TEXT NOT NULL,opened_at TEXT,after_opening_days INTEGER,status TEXT NOT NULL,owner_id TEXT NOT NULL,opening_profile_id TEXT,cold_storage_confirmed INTEGER NOT NULL DEFAULT 0)',
      );
      await legacy.insert('products', {...milk().toMap(), 'owner_id': 'alice'});
      await legacy.insert('products', {
        ...milk('Misafir sütü').toMap(),
        'id': 'guest-milk',
        'owner_id': 'guest',
      });
      await legacy.transaction(
        (tx) => SqliteProductRepository.upgradeSchema(tx, 3, 4),
      );
      final account = SqliteProductRepository(legacy, 'alice'),
          guest = SqliteProductRepository(legacy);
      expect((await account.all()).single.name, 'Süt');
      expect((await guest.all()).single.name, 'Misafir sütü');
      expect((await account.claimPending()).single.baseVersion, 0);
      expect(await guest.claimPending(), isEmpty);
    },
  );

  test(
    'Lost acknowledgement freezes the original request while later edits survive and rebase',
    () async {
      await a.save(milk());
      final first = (await a.claimPending()).single;
      final edited = (await a.all()).single.copyWith(name: 'Yeni süt');
      await a.save(edited);
      final retried = (await a.claimPending()).single;
      expect(retried.toJson(), first.toJson());
      await a.acknowledge(first, remote(1), conflict: false);
      expect((await a.all()).single.name, 'Yeni süt');
      final next = (await a.claimPending()).single;
      expect(next.mutationId, isNot(first.mutationId));
      expect(next.baseVersion, 1);
      expect(next.product!.name, 'Yeni süt');
      await a.acknowledge(next, remote(2, product: edited), conflict: false);
      await a.applyChanges([remote(2, product: edited)], 2);
      expect(await a.pendingCount(), 0);
      expect(await a.cursor(), 2);
      expect(await b.all(), isEmpty);
    },
  );

  test(
    'Remote changes preserve pending local edits; resolution is explicit and stale-safe',
    () async {
      await a.applyChanges([remote(1)], 1);
      final old = (await a.all()).single;
      await a.save(old.copyWith(name: 'Telefondaki süt'));
      await a.applyChanges([
        remote(2, product: milk('Diğer cihazdaki süt')),
      ], 2);
      expect((await a.all()).single.name, 'Telefondaki süt');
      final conflict = (await a.conflicts()).single;
      expect(conflict.remote!.product!.name, 'Diğer cihazdaki süt');
      expect(await a.claimPending(), isEmpty);
      await a.save((await a.all()).single.copyWith(quantity: '2 L'));
      await expectLater(
        a.resolve(conflict, keepLocal: true),
        throwsA(isA<StaleProductEdit>()),
      );
      await a.resolve((await a.conflicts()).single, keepLocal: true);
      final pending = (await a.claimPending()).single;
      expect(pending.baseVersion, 2);
      expect(pending.product!.quantity, '2 L');
      await expectLater(a.save(old), throwsA(isA<StaleProductEdit>()));
      await expectLater(b.save((await a.all()).single), throwsStateError);
    },
  );

  test(
    'Server deletion can be accepted without resurrecting a product; local tombstones are queued',
    () async {
      await a.applyChanges([remote(1)], 1);
      await a.save((await a.all()).single.copyWith(name: 'Yerel değişiklik'));
      await a.applyChanges([remote(2, deleted: true)], 2);
      await a.resolve((await a.conflicts()).single, keepLocal: false);
      expect(await a.all(), isEmpty);
      expect(await a.pendingCount(), 0);
      await b.save(milk());
      await b.delete('milk');
      expect((await b.claimPending()).single.deleted, isTrue);
      expect(await a.claimPending(), isEmpty);
      await expectLater(a.applyChanges([], 1), throwsStateError);
      expect(await a.cursor(), 2);
    },
  );

  test(
    'Guest products never enter the outbox before an explicit account transfer',
    () async {
      final guest = a.forOwner('guest');
      await guest.save(milk());
      expect(await guest.claimPending(), isEmpty);
      await guest.moveGuestTo('alice');
      expect(await guest.all(), isEmpty);
      expect((await a.claimPending()).single.product!.name, 'Süt');
      expect(await b.claimPending(), isEmpty);
    },
  );

  test(
    'Drafts survive disposal, remain account-local and clear without queued resurrection',
    () async {
      final draft = FormDraft(a, 'draft:product:new');
      draft.schedule({'name': 'Yarım kalan süt'});
      draft.dispose();
      await Future<void>.delayed(Duration.zero);
      final restored = FormDraft(a, 'draft:product:new');
      expect((await restored.read())!['name'], 'Yarım kalan süt');
      final other = FormDraft(b, 'draft:product:new');
      expect(await other.read(), isNull);
      restored.schedule({'name': 'Eski kuyruk'});
      await restored.clear();
      restored.dispose();
      expect(await a.setting('draft:product:new'), '');
      expect(await a.pendingCount(), 0);
      other.dispose();
    },
  );
}
