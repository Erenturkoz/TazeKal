import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:taze_kal/auth/auth_api.dart';
import 'package:taze_kal/auth/auth_controller.dart';
import 'package:taze_kal/data/product_repository.dart';
import 'package:taze_kal/services/product_sync.dart';
import 'auth_controller_test.dart' show MemoryVault, FakeGoogle, user, session;
import 'product_sync_storage_test.dart' show milk, remote;

void main() {
  setUpAll(sqfliteFfiInit);
  Future<SqliteProductRepository> repository() async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await db.execute(SqliteProductRepository.tableSql('products'));
    await db.execute(
      'CREATE TABLE settings(key TEXT PRIMARY KEY,value TEXT NOT NULL)',
    );
    await SqliteProductRepository.syncTables(db);
    return SqliteProductRepository(db);
  }

  test(
    'A failed send stays durable and the next foreground sync uploads and downloads',
    () async {
      final repo = await repository(), scoped = repo.forOwner('user-1');
      await scoped.save(milk());
      var fail = true;
      Map<String, dynamic>? first;
      final api = AuthApi(
        baseUrl: 'http://localhost:3000/v1',
        client: MockClient((req) async {
          if (req.url.path.endsWith('/login')) {
            return http.Response(jsonEncode(session('access')), 200);
          }
          if (req.url.path.endsWith('/sync')) {
            final op =
                (jsonDecode(req.body)['mutations'] as List).single
                    as Map<String, dynamic>;
            if (fail) {
              first = op;
              throw http.ClientException('offline');
            }
            expect(op, first);
            return http.Response(
              jsonEncode({
                'results': [
                  {
                    'mutationId': op['mutationId'],
                    'outcome': 'applied',
                    'remote': remote(1).toJson(),
                  },
                ],
              }),
              201,
              headers: const {
                'content-type': 'application/json; charset=utf-8',
              },
            );
          }
          return http.Response(
            jsonEncode({
              'changes': [remote(1).toJson()],
              'cursor': 1,
              'hasMore': false,
            }),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final auth = AuthController(
        api: api,
        vault: MemoryVault(),
        google: FakeGoogle(),
      );
      await auth.restore();
      await auth.login('eren@example.com', 'password');
      final sync = ProductSync(auth: auth, repository: repo)..start();
      addTearDown(() {
        sync.dispose();
        auth.dispose();
      });
      await sync.sync(force: true);
      expect(await scoped.pendingCount(), 1);
      expect(sync.error, isNotNull);
      fail = false;
      await sync.sync(force: true);
      expect(await scoped.pendingCount(), 0);
      expect(await scoped.cursor(), 1);
      expect(sync.lastSuccess, isNotNull);
    },
  );

  test(
    'A late response after an account switch never acknowledges or imports into either account',
    () async {
      final repo = await repository(), a = repo.forOwner('user-1');
      await a.save(milk());
      final sent = Completer<Map<String, dynamic>>(),
          response = Completer<http.Response>();
      final api = AuthApi(
        baseUrl: 'http://localhost:3000/v1',
        client: MockClient((req) async {
          if (req.url.path.endsWith('/login')) {
            final bob = jsonDecode(req.body)['email'] == 'bob@example.com';
            return http.Response(
              jsonEncode({
                ...session('access'),
                'user': {...user, 'id': bob ? 'bob' : 'user-1'},
              }),
              200,
              headers: const {
                'content-type': 'application/json; charset=utf-8',
              },
            );
          }
          if (req.url.path.endsWith('/sync')) {
            sent.complete((jsonDecode(req.body)['mutations'] as List).single);
            return response.future;
          }
          return http.Response(
            jsonEncode({'changes': [], 'cursor': 0, 'hasMore': false}),
            200,
            headers: const {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      final auth = AuthController(
        api: api,
        vault: MemoryVault(),
        google: FakeGoogle(),
      );
      await auth.restore();
      await auth.login('eren@example.com', 'password');
      final sync = ProductSync(auth: auth, repository: repo)..start();
      addTearDown(() {
        sync.dispose();
        auth.dispose();
      });
      final running = sync.sync(force: true);
      final op = await sent.future;
      await auth.logoutLocally();
      await auth.login('bob@example.com', 'password');
      sync.pause();
      response.complete(
        http.Response(
          jsonEncode({
            'results': [
              {
                'mutationId': op['mutationId'],
                'outcome': 'applied',
                'remote': remote(1).toJson(),
              },
            ],
          }),
          201,
          headers: const {'content-type': 'application/json; charset=utf-8'},
        ),
      );
      await running;
      expect(await a.pendingCount(), 1);
      expect(await a.cursor(), 0);
      expect(await repo.forOwner('bob').all(), isEmpty);
      expect(await repo.forOwner('bob').pendingCount(), 0);
    },
  );
}
