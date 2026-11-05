import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

enum ApiFailureKind {
  other,
  network,
  timeout,
  cancelled,
  configuration,
  invalidResponse,
}

enum ApiConnection { unknown, available, unavailable, unconfigured }

class ApiFailure implements Exception {
  const ApiFailure(
    this.message, [
    this.status = 0,
    this.kind = ApiFailureKind.other,
    this.mayHaveCompleted = false,
  ]);
  final String message;
  final int status;
  final ApiFailureKind kind;
  final bool mayHaveCompleted;
  bool get unavailable =>
      kind != ApiFailureKind.cancelled &&
      kind != ApiFailureKind.invalidResponse &&
      (status == 0 || status >= 500);
  bool get cancelled => kind == ApiFailureKind.cancelled;
  @override
  String toString() => message;
}

class AuthApi extends ChangeNotifier {
  AuthApi({
    http.Client? client,
    String? baseUrl,
    this.requestTimeout = const Duration(seconds: 12),
    this.slowAfter = const Duration(seconds: 3),
  }) : client = client ?? http.Client(),
       baseUrl =
           baseUrl ??
           const String.fromEnvironment(
             'API_BASE_URL',
             defaultValue: kReleaseMode ? '' : 'http://10.0.2.2:3000/v1',
           ) {
    if (!configured) connection = ApiConnection.unconfigured;
  }
  final http.Client client;
  final String baseUrl;
  final Duration requestTimeout, slowAfter;
  ApiConnection connection = ApiConnection.unknown;
  final _pending = <Completer<void>>{};
  final _slow = <Completer<void>>{};
  bool _disposed = false;
  int _sequence = 0, _lastStatusSequence = 0;
  Future<void>? _checking;
  bool get busy => _pending.isNotEmpty;
  bool get slow => _slow.isNotEmpty;
  bool get configured {
    final base = Uri.tryParse(baseUrl);
    final local =
        base != null &&
        ['10.0.2.2', 'localhost', '127.0.0.1'].contains(base.host);
    return base != null &&
        base.hasAuthority &&
        (base.scheme == 'https' ||
            (!kReleaseMode && local && base.scheme == 'http'));
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  void _status(ApiConnection next, int sequence) {
    if (_disposed || sequence < _lastStatusSequence) return;
    _lastStatusSequence = sequence;
    connection = next;
    _changed();
  }

  static const cancelledFailure = ApiFailure(
    'İşlem iptal edildi.',
    0,
    ApiFailureKind.cancelled,
  );

  void cancelRequests() {
    for (final abort in _pending.toList()) {
      if (!abort.isCompleted) abort.complete();
    }
  }

  Future<void> checkService() {
    if (_checking != null) return _checking!;
    // A real account request already gives stronger evidence than a health probe.
    if (busy || _disposed) return Future.value();
    final future = _probe();
    _checking = future;
    return future.whenComplete(() {
      if (identical(_checking, future)) _checking = null;
    });
  }

  Future<void> _probe() async {
    try {
      await call('GET', '/health', timeout: const Duration(seconds: 4));
    } on ApiFailure {
      /* State is reported by call; no write is ever retried. */
    }
  }

  Future<Map<String, dynamic>> call(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
    Duration? timeout,
  }) async {
    if (_disposed) throw cancelledFailure;
    final sequence = ++_sequence;
    if (!configured) {
      _status(ApiConnection.unconfigured, sequence);
      throw const ApiFailure(
        'Hesap hizmeti henüz kullanıma hazır değil. Hesapsız devam edebilirsin.',
        0,
        ApiFailureKind.configuration,
      );
    }
    final abort = Completer<void>();
    _pending.add(abort);
    final slowTimer = Timer(slowAfter, () {
      if (_pending.contains(abort)) {
        _slow.add(abort);
        _changed();
      }
    });
    _changed();
    final mutation = method != 'GET' && method != 'HEAD';
    try {
      final request = http.AbortableRequest(
        method,
        Uri.parse('${baseUrl.replaceAll(RegExp(r'/+$'), '')}$path'),
        abortTrigger: abort.future,
      )..followRedirects = false;
      request.headers['Content-Type'] = 'application/json';
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (body != null) request.body = jsonEncode(body);
      // One deadline covers connection, headers AND the complete response body.
      final response =
          await Future.any<http.Response>([
            (() async =>
                http.Response.fromStream(await client.send(request)))(),
            abort.future.then<http.Response>((_) => throw cancelledFailure),
          ]).timeout(
            timeout ?? requestTimeout,
            onTimeout: () {
              if (!abort.isCompleted) abort.complete();
              throw TimeoutException('Request deadline exceeded');
            },
          );
      if (_disposed || abort.isCompleted) throw cancelledFailure;
      _status(
        response.statusCode >= 500
            ? ApiConnection.unavailable
            : ApiConnection.available,
        sequence,
      );
      Map<String, dynamic> data = {};
      if (response.bodyBytes.isNotEmpty) {
        try {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map<String, dynamic>) {
            data = decoded;
          } else if (response.statusCode < 400) {
            throw const FormatException();
          }
        } on FormatException {
          if (response.statusCode >= 200 && response.statusCode < 300) {
            throw ApiFailure(
              'Sunucudan beklenmeyen bir yanıt geldi. Biraz sonra tekrar dene.',
              response.statusCode,
              ApiFailureKind.invalidResponse,
              mutation,
            );
          }
        }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = data['message'];
        throw ApiFailure(
          response.statusCode == 429
              ? 'Çok fazla deneme yaptın. Bir dakika sonra tekrar dene.'
              : response.statusCode >= 500
              ? 'Hesap hizmetine şu anda ulaşılamıyor. Biraz sonra tekrar dene.'
              : message is String
              ? message
              : 'Bilgilerini kontrol edip tekrar dene.',
          response.statusCode,
          ApiFailureKind.other,
          mutation && response.statusCode >= 500,
        );
      }
      return data;
    } on TimeoutException {
      _status(ApiConnection.unavailable, sequence);
      throw ApiFailure(
        mutation
            ? 'Yanıt gecikti; işlemin sonucu doğrulanamadı. Tekrar denemeden önce durumunu kontrol et.'
            : 'Bağlantı yavaş; sunucu zamanında yanıt vermedi. Tekrar deneyebilirsin.',
        0,
        ApiFailureKind.timeout,
        mutation,
      );
    } on ApiFailure {
      rethrow;
    } on http.RequestAbortedException {
      throw cancelledFailure;
    } catch (_) {
      if (_disposed || abort.isCompleted) throw cancelledFailure;
      _status(ApiConnection.unavailable, sequence);
      throw ApiFailure(
        mutation
            ? 'Hesap hizmetine bağlantı kesildi; işlemin sonucu doğrulanamadı. Bağlantıyı kontrol et.'
            : 'Hesap hizmetine ulaşılamadı. Bağlantını veya sunucuyu kontrol edip tekrar dene.',
        0,
        ApiFailureKind.network,
        mutation,
      );
    } finally {
      slowTimer.cancel();
      _pending.remove(abort);
      _slow.remove(abort);
      _changed();
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cancelRequests();
    client.close();
    super.dispose();
  }
}
