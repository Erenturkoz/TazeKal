import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../domain/product.dart';
import 'sync_models.dart';

String newMutationId() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

abstract class ProductRepository {
  Future<List<Product>> all();
  Future<void> save(Product product);
  Future<void> saveAll(List<Product> products);
  Future<void> delete(String id);
  Future<String?> setting(String key);
  Future<void> setSetting(String key, String value);
}

abstract class AccountProductRepository implements ProductRepository {
  AccountProductRepository forOwner(String ownerId);
  Future<int> guestCount();
  Future<void> moveGuestTo(String ownerId);
}

class ProductChange {
  const ProductChange(this.owner, this.local);
  final String owner;
  final bool local;
}

class RepositoryEvents extends ChangeNotifier {
  ProductChange? last;
  void changed(String owner, {required bool local}) {
    last = ProductChange(owner, local);
    notifyListeners();
  }
}

class StaleProductEdit implements Exception {
  const StaleProductEdit();
  @override
  String toString() =>
      'Bu ürün başka bir işlemde değişti. Girdiğin bilgiler korunuyor; güncel ürünü kontrol et.';
}

class SqliteProductRepository implements AccountProductRepository {
  SqliteProductRepository(
    this.db, [
    this.ownerId = 'guest',
    RepositoryEvents? events,
  ]) : events = events ?? RepositoryEvents();
  final Database db;
  final String ownerId;
  final RepositoryEvents events;
  String scopedKey(String key) =>
      ownerId == 'guest' ? key : 'account:$ownerId:$key';
  @override
  SqliteProductRepository forOwner(String ownerId) =>
      SqliteProductRepository(db, ownerId, events);
  static const columns =
      'id,name,quantity,location,purchased_at,expires_at,opened_at,after_opening_days,status,owner_id,opening_profile_id,cold_storage_confirmed';
  static String tableSql(String table) => '''CREATE TABLE $table (
    id TEXT NOT NULL,name TEXT NOT NULL,quantity TEXT NOT NULL,location TEXT NOT NULL,
    purchased_at TEXT NOT NULL,expires_at TEXT,opened_at TEXT,after_opening_days INTEGER,status TEXT NOT NULL,
    owner_id TEXT NOT NULL DEFAULT 'guest',opening_profile_id TEXT,cold_storage_confirmed INTEGER NOT NULL DEFAULT 0,
    sync_version INTEGER NOT NULL DEFAULT 0,local_revision INTEGER NOT NULL DEFAULT 0,
    deleted INTEGER NOT NULL DEFAULT 0,conflict_json TEXT,expiry_source TEXT,shelf_life_profile_id TEXT,PRIMARY KEY(owner_id,id))''';
  static Future<void> syncTables(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE product_outbox (
      owner_id TEXT NOT NULL,mutation_id TEXT NOT NULL,product_id TEXT NOT NULL,local_revision INTEGER NOT NULL,
      base_version INTEGER NOT NULL,deleted INTEGER NOT NULL,product_json TEXT,attempted INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY(owner_id,mutation_id))''');
    await db.execute(
      'CREATE INDEX product_outbox_order ON product_outbox(owner_id,product_id,local_revision)',
    );
    await db.execute(
      'CREATE TABLE product_sync_state(owner_id TEXT PRIMARY KEY,cursor INTEGER NOT NULL DEFAULT 0,last_success TEXT)',
    );
  }

  static Future<void> upgradeSchema(
    DatabaseExecutor db,
    int old,
    int version,
  ) async {
    if (old < 2 && version >= 2) {
      await db.execute(
        "ALTER TABLE products ADD COLUMN owner_id TEXT NOT NULL DEFAULT 'guest'",
      );
    }
    if (old < 3 && version >= 3) {
      await db.execute(
        'ALTER TABLE products ADD COLUMN opening_profile_id TEXT',
      );
      await db.execute(
        'ALTER TABLE products ADD COLUMN cold_storage_confirmed INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (old < 4 && version >= 4) {
      // sqflite runs onUpgrade inside one transaction. Validate the copy before replacing the table.
      await db.execute(tableSql('products_v4'));
      await db.execute(
        'INSERT INTO products_v4($columns) SELECT $columns FROM products',
      );
      final before = Sqflite.firstIntValue(
        await db.rawQuery('SELECT count(*) FROM products'),
      );
      final after = Sqflite.firstIntValue(
        await db.rawQuery('SELECT count(*) FROM products_v4'),
      );
      if (before != after) throw StateError('Product migration copy mismatch');
      await db.execute('DROP TABLE products');
      await db.execute('ALTER TABLE products_v4 RENAME TO products');
      await syncTables(db);
      for (final row in await db.query(
        'products',
        where: "owner_id <> 'guest'",
      )) {
        final product = Product.fromMap(row);
        await db.insert('product_outbox', {
          'owner_id': row['owner_id'],
          'mutation_id': newMutationId(),
          'product_id': product.id,
          'local_revision': 0,
          'base_version': 0,
          'deleted': 0,
          'product_json': jsonEncode(product.toMap()),
        });
      }
    }
    if (old < 5 && version >= 5) {
      await db.execute(tableSql('products_v5'));
      const preserved =
          '$columns,sync_version,local_revision,deleted,conflict_json';
      await db.execute(
        'INSERT INTO products_v5($preserved) SELECT $preserved FROM products',
      );
      final before = Sqflite.firstIntValue(
        await db.rawQuery('SELECT count(*) FROM products'),
      );
      final after = Sqflite.firstIntValue(
        await db.rawQuery('SELECT count(*) FROM products_v5'),
      );
      if (before != after) throw StateError('Product migration copy mismatch');
      await db.execute('DROP TABLE products');
      await db.execute('ALTER TABLE products_v5 RENAME TO products');
    }
  }

  static Future<SqliteProductRepository> open() async {
    final db = await openDatabase(
      path.join(await getDatabasesPath(), 'taze_kal.db'),
      version: 5,
      onCreate: (db, _) async {
        await db.execute(tableSql('products'));
        await db.execute(
          'CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)',
        );
        await syncTables(db);
      },
      onUpgrade: upgradeSchema,
    );
    return SqliteProductRepository(db);
  }

  @override
  Future<int> guestCount() async =>
      Sqflite.firstIntValue(
        await db.rawQuery(
          "SELECT count(*) FROM products WHERE owner_id='guest' AND deleted=0",
        ),
      ) ??
      0;
  @override
  Future<void> moveGuestTo(String ownerId) async {
    if (ownerId == 'guest') return;
    await db.transaction((tx) async {
      for (final row in await tx.query(
        'products',
        where: "owner_id='guest' AND deleted=0",
      )) {
        var product = Product.fromMap(row);
        final collision = await tx.query(
          'products',
          where: 'owner_id=? AND id=?',
          whereArgs: [ownerId, product.id],
        );
        if (collision.isNotEmpty) {
          product = Product.fromMap({
            ...product.toMap(),
            'id': newMutationId(),
          });
        }
        await tx.insert('products', {
          ...product.toMap(),
          'owner_id': ownerId,
          'local_revision': 1,
        });
        await tx.insert('product_outbox', {
          'owner_id': ownerId,
          'mutation_id': newMutationId(),
          'product_id': product.id,
          'local_revision': 1,
          'base_version': 0,
          'deleted': 0,
          'product_json': jsonEncode(product.toMap()),
        });
        await tx.delete(
          'products',
          where: "owner_id='guest' AND id=?",
          whereArgs: [row['id']],
        );
      }
    });
    events.changed('guest', local: true);
    events.changed(ownerId, local: true);
  }

  @override
  Future<List<Product>> all() async => (await db.query(
    'products',
    where: 'owner_id=? AND deleted=0',
    whereArgs: [ownerId],
  )).map(Product.fromMap).toList();
  Future<int?> revisionOf(String id) async {
    final rows = await db.query(
      'products',
      columns: ['local_revision'],
      where: 'owner_id=? AND id=? AND deleted=0',
      whereArgs: [ownerId, id],
    );
    return rows.isEmpty ? null : rows.first['local_revision'] as int;
  }

  void _validate(Product p) {
    if (p.localOwnerId != null && p.localOwnerId != ownerId) {
      throw StateError('Product belongs to a different account');
    }
    if (!RegExp(r'^[a-zA-Z0-9_-]{1,100}$').hasMatch(p.id) ||
        p.name.trim().isEmpty ||
        p.name.length > 100 ||
        p.quantity.trim().isEmpty ||
        p.quantity.length > 40 ||
        !['Buzdolabı', 'Kiler', 'Dondurucu'].contains(p.location)) {
      throw StateError('Invalid product');
    }
  }

  Future<void> _queue(
    Transaction tx,
    Product p,
    int revision,
    int base,
    bool deleted,
  ) async {
    if (ownerId == 'guest') return;
    final tail = await tx.query(
      'product_outbox',
      where: 'owner_id=? AND product_id=? AND attempted=0',
      whereArgs: [ownerId, p.id],
    );
    final values = {
      'owner_id': ownerId,
      'mutation_id': tail.isEmpty ? newMutationId() : tail.first['mutation_id'],
      'product_id': p.id,
      'local_revision': revision,
      'base_version': base,
      'deleted': deleted ? 1 : 0,
      'product_json': deleted ? null : jsonEncode(p.toMap()),
    };
    await tx.insert(
      'product_outbox',
      values,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> save(Product product) => saveAll([product]);
  Future<void> saveIfUnchanged(Product product, int expectedRevision) =>
      _save([product], expectedRevision: expectedRevision);
  @override
  Future<void> saveAll(List<Product> products) => _save(products);
  Future<void> _save(List<Product> products, {int? expectedRevision}) async {
    await db.transaction((tx) async {
      for (final p in products) {
        _validate(p);
        final existing = await tx.query(
          'products',
          where: 'owner_id=? AND id=?',
          whereArgs: [ownerId, p.id],
        );
        final row = existing.isEmpty ? null : existing.first;
        final expected = expectedRevision ?? p.localRevision;
        if (expected != null &&
            (row == null ||
                row['local_revision'] != expected ||
                row['deleted'] == 1)) {
          throw const StaleProductEdit();
        }
        final revision = ((row?['local_revision'] as int?) ?? 0) + 1,
            version = (row?['sync_version'] as int?) ?? 0;
        await tx.insert('products', {
          ...p.toMap(),
          'owner_id': ownerId,
          'sync_version': version,
          'local_revision': revision,
          'conflict_json': row?['conflict_json'],
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await _queue(tx, p, revision, version, false);
      }
    });
    events.changed(ownerId, local: true);
  }

  @override
  Future<void> delete(String id) async {
    await db.transaction((tx) async {
      final rows = await tx.query(
        'products',
        where: 'owner_id=? AND id=? AND deleted=0',
        whereArgs: [ownerId, id],
      );
      if (rows.isEmpty) return;
      final row = rows.first,
          revision = (rows.first['local_revision'] as int) + 1;
      await tx.update(
        'products',
        {'deleted': 1, 'local_revision': revision},
        where: 'owner_id=? AND id=?',
        whereArgs: [ownerId, id],
      );
      await _queue(
        tx,
        Product.fromMap(row),
        revision,
        row['sync_version'] as int,
        true,
      );
    });
    events.changed(ownerId, local: true);
  }

  Future<List<PendingProduct>> claimPending() => db.transaction((tx) async {
    final rows = await tx.rawQuery(
      '''SELECT o.* FROM product_outbox o JOIN products p ON p.owner_id=o.owner_id AND p.id=o.product_id
      WHERE o.owner_id=? AND p.conflict_json IS NULL AND NOT EXISTS
      (SELECT 1 FROM product_outbox earlier WHERE earlier.owner_id=o.owner_id AND earlier.product_id=o.product_id AND earlier.local_revision<o.local_revision)
      ORDER BY o.local_revision LIMIT 50''',
      [ownerId],
    );
    for (final row in rows) {
      await tx.update(
        'product_outbox',
        {'attempted': 1},
        where: 'owner_id=? AND mutation_id=?',
        whereArgs: [ownerId, row['mutation_id']],
      );
    }
    return rows
        .map(
          (r) => PendingProduct(
            mutationId: r['mutation_id'] as String,
            productId: r['product_id'] as String,
            revision: r['local_revision'] as int,
            baseVersion: r['base_version'] as int,
            deleted: r['deleted'] == 1,
            product: r['product_json'] == null
                ? null
                : Product.fromMap(
                    Map<String, Object?>.from(
                      jsonDecode(r['product_json'] as String) as Map,
                    ),
                  ),
          ),
        )
        .toList();
  });
  Future<void> acknowledge(
    PendingProduct sent,
    RemoteProduct? remote, {
    required bool conflict,
  }) async {
    if (remote != null && remote.id != sent.productId) {
      throw const FormatException('Mismatched sync result');
    }
    await db.transaction((tx) async {
      final pending = await tx.query(
        'product_outbox',
        where: 'owner_id=? AND mutation_id=?',
        whereArgs: [ownerId, sent.mutationId],
      );
      if (pending.isEmpty) return;
      if (conflict) {
        await tx.update(
          'products',
          {
            'conflict_json': jsonEncode({'remote': remote?.toJson()}),
          },
          where: 'owner_id=? AND id=?',
          whereArgs: [ownerId, sent.productId],
        );
      } else {
        if (remote == null) {
          throw const FormatException('Missing acknowledgement');
        }
        await tx.update(
          'products',
          {'sync_version': remote.version},
          where: 'owner_id=? AND id=?',
          whereArgs: [ownerId, sent.productId],
        );
        await tx.delete(
          'product_outbox',
          where: 'owner_id=? AND mutation_id=?',
          whereArgs: [ownerId, sent.mutationId],
        );
        await tx.update(
          'product_outbox',
          {'base_version': remote.version},
          where: 'owner_id=? AND product_id=? AND attempted=0',
          whereArgs: [ownerId, sent.productId],
        );
      }
    });
  }

  Future<int> cursor() async =>
      (await db.query(
            'product_sync_state',
            where: 'owner_id=?',
            whereArgs: [ownerId],
          )).firstOrNull?['cursor']
          as int? ??
      0;
  Future<int> pendingCount() async =>
      Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT count(DISTINCT product_id) FROM product_outbox WHERE owner_id=?',
          [ownerId],
        ),
      ) ??
      0;
  Future<List<ProductConflict>> conflicts() async {
    final rows = await db.query(
      'products',
      where: 'owner_id=? AND conflict_json IS NOT NULL',
      whereArgs: [ownerId],
    );
    return rows.map((r) {
      final data = jsonDecode(r['conflict_json'] as String) as Map;
      return ProductConflict(
        id: r['id'] as String,
        local: Product.fromMap(r),
        localDeleted: r['deleted'] == 1,
        localRevision: r['local_revision'] as int,
        remote: data['remote'] == null
            ? null
            : RemoteProduct.fromJson(
                Map<String, dynamic>.from(data['remote'] as Map),
              ),
      );
    }).toList();
  }

  Future<void> applyChanges(List<RemoteProduct> changes, int nextCursor) async {
    var changed = false;
    await db.transaction((tx) async {
      final current =
          (await tx.query(
                'product_sync_state',
                where: 'owner_id=?',
                whereArgs: [ownerId],
              )).firstOrNull?['cursor']
              as int? ??
          0;
      if (nextCursor < current) throw StateError('Sync cursor moved backwards');
      for (final remote in changes) {
        final rows = await tx.query(
          'products',
          where: 'owner_id=? AND id=?',
          whereArgs: [ownerId, remote.id],
        );
        final local = rows.firstOrNull;
        if (local != null && (local['sync_version'] as int) >= remote.version) {
          continue;
        }
        final pending = await tx.query(
          'product_outbox',
          columns: ['mutation_id'],
          where: 'owner_id=? AND product_id=?',
          whereArgs: [ownerId, remote.id],
          limit: 1,
        );
        if (pending.isNotEmpty) {
          await tx.update(
            'products',
            {
              'conflict_json': jsonEncode({'remote': remote.toJson()}),
            },
            where: 'owner_id=? AND id=?',
            whereArgs: [ownerId, remote.id],
          );
        } else if (remote.deleted) {
          if (local != null) {
            await tx.update(
              'products',
              {
                'deleted': 1,
                'sync_version': remote.version,
                'local_revision': (local['local_revision'] as int) + 1,
                'conflict_json': null,
              },
              where: 'owner_id=? AND id=?',
              whereArgs: [ownerId, remote.id],
            );
          }
          changed = true;
        } else {
          await tx.insert('products', {
            ...remote.product!.toMap(),
            'owner_id': ownerId,
            'sync_version': remote.version,
            'local_revision': ((local?['local_revision'] as int?) ?? 0) + 1,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          changed = true;
        }
      }
      final state = (await tx.query(
        'product_sync_state',
        where: 'owner_id=?',
        whereArgs: [ownerId],
      )).firstOrNull;
      await tx.insert('product_sync_state', {
        'owner_id': ownerId,
        'cursor': nextCursor,
        'last_success': state?['last_success'],
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    if (changed) events.changed(ownerId, local: false);
  }

  Future<void> markSynced() async {
    await db.update(
      'product_sync_state',
      {'last_success': DateTime.now().toUtc().toIso8601String()},
      where: 'owner_id=?',
      whereArgs: [ownerId],
    );
  }

  Future<String?> lastSuccess() async =>
      (await db.query(
            'product_sync_state',
            where: 'owner_id=?',
            whereArgs: [ownerId],
          )).firstOrNull?['last_success']
          as String?;
  Future<void> resolve(
    ProductConflict conflict, {
    required bool keepLocal,
  }) async {
    await db.transaction((tx) async {
      final row = (await tx.query(
        'products',
        where: 'owner_id=? AND id=?',
        whereArgs: [ownerId, conflict.id],
      )).firstOrNull;
      if (row == null ||
          row['local_revision'] != conflict.localRevision ||
          row['conflict_json'] == null) {
        throw const StaleProductEdit();
      }
      final json = jsonDecode(row['conflict_json'] as String) as Map;
      final remote = json['remote'] == null
          ? null
          : RemoteProduct.fromJson(
              Map<String, dynamic>.from(json['remote'] as Map),
            );
      if (remote?.version != conflict.remote?.version) {
        throw const StaleProductEdit();
      }
      await tx.delete(
        'product_outbox',
        where: 'owner_id=? AND product_id=?',
        whereArgs: [ownerId, conflict.id],
      );
      final revision = conflict.localRevision + 1;
      if (keepLocal) {
        await tx.update(
          'products',
          {
            'sync_version': remote?.version ?? 0,
            'conflict_json': null,
            'local_revision': revision,
          },
          where: 'owner_id=? AND id=?',
          whereArgs: [ownerId, conflict.id],
        );
        await _queue(
          tx,
          Product.fromMap(row),
          revision,
          remote?.version ?? 0,
          row['deleted'] == 1,
        );
      } else if (remote == null || remote.deleted) {
        await tx.update(
          'products',
          {
            'sync_version': remote?.version ?? 0,
            'deleted': 1,
            'conflict_json': null,
            'local_revision': revision,
          },
          where: 'owner_id=? AND id=?',
          whereArgs: [ownerId, conflict.id],
        );
      } else {
        await tx.insert('products', {
          ...remote.product!.toMap(),
          'owner_id': ownerId,
          'sync_version': remote.version,
          'local_revision': revision,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
    events.changed(ownerId, local: keepLocal);
  }

  @override
  Future<String?> setting(String key) async =>
      (await db.query(
            'settings',
            where: 'key=?',
            whereArgs: [scopedKey(key)],
          )).firstOrNull?['value']
          as String?;
  @override
  Future<void> setSetting(String key, String value) async {
    await db.insert('settings', {
      'key': scopedKey(key),
      'value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeSetting(String key) async {
    await db.delete('settings', where: 'key=?', whereArgs: [scopedKey(key)]);
  }
}
