import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'auth_api.dart';
import 'google_identity.dart';
import 'session_vault.dart';

class AccountUser {
  const AccountUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.emailVerified,
    required this.providers,
  });
  final String id, email, displayName;
  final bool emailVerified;
  final List<String> providers;
  factory AccountUser.fromJson(Map<String, dynamic> data) => AccountUser(
    id: data['id'] as String,
    email: data['email'] as String,
    displayName: data['displayName'] as String,
    emailVerified: data['emailVerified'] as bool,
    providers: (data['providers'] as List).cast<String>(),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'emailVerified': emailVerified,
    'providers': providers,
  };
}

class AuthController extends ChangeNotifier {
  AuthController({
    required this.api,
    required this.vault,
    required this.google,
  });
  final AuthApi api;
  final SessionVault vault;
  final GoogleIdentityProvider google;
  AccountUser? user;
  String? _access, _refresh;
  bool restoring = true, offline = false, validating = false;
  bool _disposed = false;
  int _epoch = 0, _validationEpoch = -1, _profileRevision = 0;
  Future<void>? _refreshing, _validation;
  Future<void> _vaultTail = Future.value();
  int get sessionRevision => _epoch;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _ensure(int epoch) {
    if (_disposed || epoch != _epoch) throw AuthApi.cancelledFailure;
  }

  int _newOperation() {
    if (_disposed) throw AuthApi.cancelledFailure;
    _epoch++;
    api.cancelRequests();
    _refreshing = null;
    validating = false;
    return _epoch;
  }

  // Secure-store writes and clears must keep their order, even on slow devices.
  Future<void> _vaultJob(Future<void> Function() action) {
    final job = _vaultTail.then((_) => action());
    _vaultTail = job.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return job;
  }

  Future<void> _store(
    AccountUser next,
    String access,
    String refresh,
    int epoch, {
    int? profileRevision,
  }) async {
    _ensure(epoch);
    await _vaultJob(() async {
      _ensure(epoch);
      final selected =
          profileRevision != null && profileRevision != _profileRevision
          ? user ?? next
          : next;
      await vault.write(
        jsonEncode({
          'accessToken': access,
          'refreshToken': refresh,
          'user': selected.toJson(),
        }),
      );
      _ensure(epoch);
      user = profileRevision != null && profileRevision != _profileRevision
          ? user ?? selected
          : selected;
      _access = access;
      _refresh = refresh;
      offline = false;
      _notify();
    });
  }

  Future<void> _saveUser(
    AccountUser next,
    int epoch,
    int revision,
  ) => _vaultJob(() async {
    _ensure(epoch);
    if (revision != _profileRevision) return;
    // Read tokens inside the storage queue, after any concurrent refresh write.
    await vault.write(
      jsonEncode({
        'accessToken': _access!,
        'refreshToken': _refresh!,
        'user': next.toJson(),
      }),
    );
    _ensure(epoch);
    if (revision == _profileRevision) {
      user = next;
      offline = false;
      _notify();
    }
  });

  Future<void> restore() async {
    final epoch = _newOperation();
    restoring = true;
    _notify();
    try {
      final saved = await vault.read();
      _ensure(epoch);
      if (saved == null) {
        user = null;
        _access = null;
        _refresh = null;
      } else {
        final data = jsonDecode(saved) as Map<String, dynamic>;
        final cached = AccountUser.fromJson(
          data['user'] as Map<String, dynamic>,
        );
        _access = data['accessToken'] as String;
        _refresh = data['refreshToken'] as String;
        user = cached;
      }
      // The kitchen is ready as soon as the local identity has been read.
      restoring = false;
      _notify();
      if (user != null) await revalidate();
    } on ApiFailure catch (e) {
      if (!e.cancelled && epoch == _epoch) offline = true;
    } catch (_) {
      if (epoch == _epoch) {
        user = null;
        _access = null;
        _refresh = null;
      }
    } finally {
      if (!_disposed && epoch == _epoch) {
        restoring = false;
        _notify();
      }
    }
  }

  Future<void> revalidate() {
    if (_disposed || restoring) return Future.value();
    if (user == null) return api.checkService();
    if (_validation != null && _validationEpoch == _epoch) return _validation!;
    final epoch = _epoch;
    _validationEpoch = epoch;
    final job = _validate(epoch);
    _validation = job;
    return job.whenComplete(() {
      if (identical(_validation, job)) _validation = null;
    });
  }

  Future<void> _validate(int epoch) async {
    final revision = _profileRevision;
    validating = true;
    _notify();
    try {
      final next = AccountUser.fromJson(
        await authenticated('GET', '/users/me'),
      );
      _ensure(epoch);
      await _saveUser(next, epoch, revision);
    } on ApiFailure catch (e) {
      if (epoch == _epoch && !_disposed && !e.cancelled) {
        if (e.status == 401) {
          await _forget(epoch);
        } else {
          offline = true;
          _notify();
        }
      }
    } catch (_) {
      if (epoch == _epoch && !_disposed) {
        offline = true;
        _notify();
      }
    } finally {
      if (!_disposed && epoch == _epoch) {
        validating = false;
        _notify();
      }
    }
  }

  Future<void> _accept(
    Map<String, dynamic> data,
    int epoch, {
    int? profileRevision,
  }) async {
    _ensure(epoch);
    final next = AccountUser.fromJson(data['user'] as Map<String, dynamic>);
    await _store(
      next,
      data['accessToken'] as String,
      data['refreshToken'] as String,
      epoch,
      profileRevision: profileRevision,
    );
  }

  Future<void> register(String name, String email, String password) async {
    final epoch = _newOperation();
    await _accept(
      await api.call(
        'POST',
        '/auth/register',
        body: {
          'displayName': name.trim(),
          'email': email.trim(),
          'password': password,
        },
      ),
      epoch,
    );
  }

  Future<void> login(String email, String password) async {
    final epoch = _newOperation();
    await _accept(
      await api.call(
        'POST',
        '/auth/login',
        body: {'email': email.trim(), 'password': password},
      ),
      epoch,
    );
  }

  Future<void> loginGoogle() async {
    final epoch = _newOperation();
    final token = await google.idToken();
    _ensure(epoch);
    if (token == null) return;
    await _accept(
      await api.call('POST', '/auth/google', body: {'idToken': token}),
      epoch,
    );
  }

  Future<void> cancelAuthentication() async {
    if (user != null) throw AuthApi.cancelledFailure;
    // Also clear a login write that may already be inside secure storage.
    await _forget();
  }

  Future<void> _renew(int epoch, Duration timeout) async {
    _ensure(epoch);
    final refresh = _refresh;
    final revision = _profileRevision;
    if (refresh == null) {
      throw const ApiFailure('Tekrar giriş yapmalısın.', 401);
    }
    try {
      await _accept(
        await api.call(
          'POST',
          '/auth/refresh',
          body: {'refreshToken': refresh},
          timeout: timeout,
        ),
        epoch,
        profileRevision: revision,
      );
    } on ApiFailure catch (e) {
      if (e.status == 401 && epoch == _epoch && !_disposed) {
        await _forget(epoch);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> authenticated(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final epoch = _epoch;
    final clock = Stopwatch()..start();
    Duration remaining() {
      final time = api.requestTimeout - clock.elapsed;
      if (time <= Duration.zero) {
        throw ApiFailure(
          'Hesap hizmeti zamanında yanıt vermedi. Tekrar deneyebilirsin.',
          0,
          ApiFailureKind.timeout,
          method != 'GET',
        );
      }
      return time;
    }

    _ensure(epoch);
    if (_access == null) {
      throw const ApiFailure('Tekrar giriş yapmalısın.', 401);
    }
    try {
      final data = await api.call(
        method,
        path,
        body: body,
        token: _access,
        timeout: remaining(),
      );
      _ensure(epoch);
      return data;
    } on ApiFailure catch (e) {
      if (e.status != 401) rethrow;
      _ensure(epoch);
      final renewal = _refreshing ??= _renew(epoch, remaining());
      try {
        await renewal.timeout(
          remaining(),
          onTimeout: () => throw const ApiFailure(
            'Oturum kontrolü zamanında tamamlanamadı. Tekrar dene.',
            0,
            ApiFailureKind.timeout,
          ),
        );
      } finally {
        if (identical(_refreshing, renewal)) _refreshing = null;
      }
      _ensure(epoch);
      try {
        final data = await api.call(
          method,
          path,
          body: body,
          token: _access,
          timeout: remaining(),
        );
        _ensure(epoch);
        return data;
      } on ApiFailure catch (retry) {
        if (retry.status == 401 && epoch == _epoch) await _forget(epoch);
        rethrow;
      }
    }
  }

  Future<void> rename(String name) async {
    final epoch = _epoch;
    final revision = ++_profileRevision;
    final next = AccountUser.fromJson(
      await authenticated(
        'PATCH',
        '/users/me',
        body: {'displayName': name.trim()},
      ),
    );
    _ensure(epoch);
    await _saveUser(next, epoch, revision);
  }

  Future<void> linkGoogle() async {
    final epoch = _epoch;
    final token = await google.idToken();
    _ensure(epoch);
    if (token == null) return;
    final revision = ++_profileRevision;
    final next = AccountUser.fromJson(
      await authenticated(
        'POST',
        '/auth/google/link',
        body: {'idToken': token},
      ),
    );
    _ensure(epoch);
    await _saveUser(next, epoch, revision);
  }

  Future<void> _forget([int? expected]) async {
    if (expected != null) _ensure(expected);
    final epoch = _newOperation();
    await _vaultJob(vault.clear);
    _ensure(epoch);
    user = null;
    _access = null;
    _refresh = null;
    offline = false;
    restoring = false;
    _notify();
  }

  Future<void> logout() async {
    final epoch = _epoch;
    try {
      await authenticated('POST', '/auth/logout');
    } on ApiFailure catch (e) {
      // An already rejected session need not trap the user on the profile page.
      if (e.status != 401) rethrow;
    }
    if (epoch == _epoch) {
      await _forget(epoch);
    } else if (user != null) {
      throw AuthApi.cancelledFailure;
    }
  }

  // The UI explicitly explains that this does NOT revoke the remote session.
  Future<void> logoutLocally() => _forget();

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _epoch++;
    api.dispose();
    super.dispose();
  }
}
