import 'dart:async';
import 'package:flutter/foundation.dart';
import '../auth/auth_api.dart';
import '../auth/auth_controller.dart';
import '../data/product_repository.dart';
import '../data/sync_models.dart';

class ProductSync extends ChangeNotifier {
  ProductSync({required this.auth, required this.repository});
  final AuthController auth;
  final SqliteProductRepository repository;
  String? owner, error, lastSuccess;
  int pending = 0;
  List<ProductConflict> conflicts = [];
  bool syncing = false,
      _started = false,
      _foreground = false,
      _disposed = false;
  int _generation = 0, _session = -1;
  bool _wasValidating = false, _wasEligible = false, _rerun = false;
  Timer? _debounce;
  Future<void>? _running;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _current(String id, int generation, int session) =>
      !_disposed &&
      _started &&
      owner == id &&
      generation == _generation &&
      auth.user?.id == id &&
      auth.sessionRevision == session;
  bool get _eligible =>
      _foreground &&
      !auth.restoring &&
      auth.user != null &&
      auth.api.configured &&
      !auth.validating &&
      !auth.offline &&
      auth.api.connection == ApiConnection.available;
  void start() {
    if (_started || _disposed) return;
    _started = true;
    auth.addListener(_authChanged);
    repository.events.addListener(_productsChanged);
    resume();
  }

  void stop() {
    if (!_started) return;
    _started = false;
    syncing = false;
    pause();
    _generation++;
    auth.removeListener(_authChanged);
    repository.events.removeListener(_productsChanged);
  }

  void pause() {
    _foreground = false;
    _debounce?.cancel();
  }

  void resume() {
    _foreground = true;
    _authChanged();
    if (_eligible) _schedule();
  }

  void _authChanged() {
    final next = auth.user?.id;
    if (next != owner || _session != auth.sessionRevision) {
      owner = next;
      _session = auth.sessionRevision;
      _generation++;
      pending = 0;
      conflicts = [];
      lastSuccess = null;
      error = null;
      syncing = false;
      _debounce?.cancel();
      if (next != null) unawaited(_counts(next, _generation, _session));
      _notify();
    }
    final ready = _eligible;
    if (ready && (!_wasEligible || (_wasValidating && !auth.validating))) {
      _schedule();
    }
    _wasEligible = ready;
    _wasValidating = auth.validating;
  }

  void _productsChanged() {
    final event = repository.events.last;
    if (event?.owner != owner || owner == null) return;
    unawaited(_counts(owner!, _generation, _session));
    if (event!.local) {
      if (_running != null) _rerun = true;
      if (_eligible) _schedule();
    }
  }

  void _schedule() {
    _debounce?.cancel();
    if (!_foreground || !_started) return;
    _debounce = Timer(
      const Duration(milliseconds: 500),
      () => unawaited(sync()),
    );
  }

  Future<void> _counts(String id, int generation, int session) async {
    try {
      final repo = repository.forOwner(id);
      final count = await repo.pendingCount(),
          issues = await repo.conflicts(),
          success = await repo.lastSuccess();
      if (_current(id, generation, session)) {
        pending = count;
        conflicts = issues;
        lastSuccess = success;
        _notify();
      }
    } catch (_) {
      if (_current(id, generation, session)) {
        error = 'Eşitleme bilgisi okunamadı. Cihaz kayıtların korunuyor.';
        _notify();
      }
    }
  }

  Future<void> sync({bool force = false}) {
    _debounce?.cancel();
    if (_running != null) {
      _rerun = true;
      return _running!;
    }
    if (!_started ||
        !_foreground ||
        _disposed ||
        auth.user == null ||
        auth.restoring ||
        !auth.api.configured ||
        (!force && !_eligible)) {
      return Future.value();
    }
    final id = auth.user!.id,
        generation = _generation,
        session = auth.sessionRevision;
    final job = _sync(id, generation, session);
    _running = job;
    return job.whenComplete(() {
      if (identical(_running, job)) _running = null;
      if (_rerun && _eligible && _started) {
        _rerun = false;
        _schedule();
      }
    });
  }

  Future<void> _sync(String id, int generation, int session) async {
    final repo = repository.forOwner(id);
    syncing = true;
    error = null;
    _rerun = false;
    _notify();
    try {
      for (var cycle = 0; cycle < 4; cycle++) {
        if (!_current(id, generation, session)) return;
        final batch = await repo.claimPending();
        if (!_current(id, generation, session)) return;
        if (batch.isNotEmpty) {
          final response = await auth.authenticated(
            'POST',
            '/products/sync',
            body: {'mutations': batch.map((m) => m.toJson()).toList()},
          );
          if (!_current(id, generation, session)) return;
          final results = (response['results'] as List)
              .cast<Map<String, dynamic>>();
          if (results.length != batch.length) {
            throw const FormatException('Incomplete sync acknowledgement');
          }
          for (var index = 0; index < batch.length; index++) {
            final result = results[index];
            if (result['mutationId'] != batch[index].mutationId ||
                !['applied', 'conflict'].contains(result['outcome'])) {
              throw const FormatException('Unexpected mutation result');
            }
            final remote = result['remote'] == null
                ? null
                : RemoteProduct.fromJson(
                    result['remote'] as Map<String, dynamic>,
                  );
            await repo.acknowledge(
              batch[index],
              remote,
              conflict: result['outcome'] == 'conflict',
            );
            if (!_current(id, generation, session)) return;
          }
        }
        final cursor = await repo.cursor();
        final response = await auth.authenticated(
          'GET',
          '/products/changes?after=$cursor&limit=200',
        );
        if (!_current(id, generation, session)) return;
        final changes = (response['changes'] as List)
            .map((r) => RemoteProduct.fromJson(r as Map<String, dynamic>))
            .toList();
        final next = response['cursor'] as int,
            more = response['hasMore'] as bool;
        if (next < cursor ||
            changes.any((r) => r.cursor <= cursor || r.cursor > next) ||
            (more && next <= cursor)) {
          throw const FormatException('Invalid sync page');
        }
        await repo.applyChanges(changes, next);
        if (!_current(id, generation, session)) return;
        await _counts(id, generation, session);
        final readyPending = pending > conflicts.length;
        if (!more && !readyPending) {
          if (pending == 0 && conflicts.isEmpty) await repo.markSynced();
          break;
        }
        if (cycle == 3) _rerun = true;
      }
      await _counts(id, generation, session);
    } on ApiFailure catch (failure) {
      if (_current(id, generation, session) && !failure.cancelled) {
        error = failure.status == 409
            ? 'Sunucu eşitleme geçmişi geride. Cihaz kayıtların korunuyor; sunucu yedeği kontrol edilmeli.'
            : 'Ürünler cihazında kayıtlı. Sunucuya eşitleme tamamlanamadı; tekrar denenecek.';
      }
    } catch (_) {
      if (_current(id, generation, session)) {
        error =
            'Eşitleme tamamlanamadı. Cihaz kayıtların ve bekleyen değişikliklerin korunuyor.';
      }
    } finally {
      if (_current(id, generation, session)) {
        syncing = false;
        await _counts(id, generation, session);
        _notify();
      }
    }
  }

  Future<void> resolve(
    ProductConflict conflict, {
    required bool keepLocal,
  }) async {
    final id = owner, generation = _generation, session = _session;
    if (id == null || !_current(id, generation, session)) {
      throw StateError('Account changed');
    }
    await repository.forOwner(id).resolve(conflict, keepLocal: keepLocal);
    await _counts(id, generation, session);
    if (_eligible) _schedule();
  }

  @override
  void dispose() {
    if (_disposed) return;
    stop();
    _disposed = true;
    super.dispose();
  }
}
