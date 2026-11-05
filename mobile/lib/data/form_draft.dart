import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'product_repository.dart';

enum DraftStatus { idle, saving, saved, failed }

/// The bound repository provides account isolation; drafts never enter the sync outbox.
class FormDraft extends ValueNotifier<DraftStatus> {
  FormDraft(this.repository, this.key) : super(DraftStatus.idle);
  final ProductRepository repository;
  final String key;
  Timer? _timer;
  String? _latest;
  Future<void> _tail = Future.value();
  bool _disposed = false, _cleared = false;
  void _status(DraftStatus next) {
    if (!_disposed) value = next;
  }

  Future<Map<String, dynamic>?> read() async {
    final raw = await repository.setting(key);
    if (raw == null || raw.isEmpty) return null;
    return Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  void schedule(Map<String, dynamic> snapshot) {
    if (_cleared || _disposed) return;
    _latest = jsonEncode(snapshot);
    _timer?.cancel();
    _status(DraftStatus.saving);
    _timer = Timer(const Duration(milliseconds: 350), () => unawaited(flush()));
  }

  Future<void> flush() {
    _timer?.cancel();
    final raw = _latest;
    _latest = null;
    if (raw == null || _cleared) return _tail;
    final job = _tail.then((_) => repository.setSetting(key, raw));
    _tail = job.then<void>(
      (_) => _status(DraftStatus.saved),
      onError: (Object _, StackTrace _) => _status(DraftStatus.failed),
    );
    return _tail;
  }

  Future<void> clear() async {
    _timer?.cancel();
    _cleared = true;
    _latest = null;
    await _tail;
    try {
      await repository.setSetting(key, '');
      _status(DraftStatus.idle);
    } catch (_) {
      _status(DraftStatus.failed);
    }
  }

  Future<void> reset() async {
    await clear();
    _cleared = false;
  }

  @override
  void dispose() {
    if (_disposed) return;
    unawaited(flush());
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
