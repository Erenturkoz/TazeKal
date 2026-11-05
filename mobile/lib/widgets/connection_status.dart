import 'dart:async';
import 'package:flutter/material.dart';
import '../auth/auth_api.dart';
import '../auth/auth_controller.dart';
import 'loading_skeleton.dart';

class AccountConnectionScope extends InheritedWidget {
  const AccountConnectionScope({
    super.key,
    required this.auth,
    required super.child,
  });
  final AuthController auth;
  static AuthController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AccountConnectionScope>()
      ?.auth;
  @override
  bool updateShouldNotify(AccountConnectionScope oldWidget) =>
      oldWidget.auth != auth;
}

/// Foreground only: check an existing account, or probe the configured API.
/// No stock/profile writes are retried or queued.
class ConnectionWatch extends StatefulWidget {
  const ConnectionWatch({super.key, required this.auth, required this.child});
  final AuthController auth;
  final Widget child;
  @override
  State<ConnectionWatch> createState() => _ConnectionWatchState();
}

class _ConnectionWatchState extends State<ConnectionWatch>
    with WidgetsBindingObserver {
  Timer? timer;
  bool foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    foreground = state == null || state == AppLifecycleState.resumed;
    if (foreground) _start();
    WidgetsBinding.instance.addPostFrameCallback((_) => check());
  }

  void _start() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 30), (_) => check());
  }

  Future<void> check() async {
    if (!mounted ||
        !foreground ||
        widget.auth.restoring ||
        widget.auth.api.busy) {
      return;
    }
    try {
      await widget.auth.revalidate();
    } on ApiFailure {
      /* Keep the local view. */
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      foreground = true;
      _start();
      check();
    } else {
      foreground = false;
      timer?.cancel();
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key, this.localData = false});
  final bool localData;
  @override
  Widget build(BuildContext context) {
    final auth = AccountConnectionScope.maybeOf(context);
    if (auth == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: Listenable.merge([auth, auth.api]),
      builder: (context, _) {
        final api = auth.api;
        final unavailable =
            auth.offline || api.connection == ApiConnection.unavailable;
        final message = !api.configured
            ? 'Hesap hizmeti henüz hazır değil.'
            : api.slow
            ? 'Hesap hizmeti yavaş yanıt veriyor.'
            : auth.offline && api.connection == ApiConnection.available
            ? 'Oturum kontrolü tamamlanamadı.'
            : unavailable
            ? 'Hesap hizmetine şu anda ulaşılamıyor.'
            : null;
        final scheme = Theme.of(context).colorScheme;
        return AnimatedSize(
          duration: reducedMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: message == null
              ? const SizedBox.shrink()
              : Semantics(
                  liveRegion: true,
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              api.slow
                                  ? Icons.hourglass_top_rounded
                                  : Icons.cloud_off_outlined,
                              size: 20,
                              color: scheme.onSecondaryContainer,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                message,
                                style: TextStyle(
                                  color: scheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (localData)
                          Padding(
                            padding: const EdgeInsets.only(left: 30, top: 4),
                            child: Text(
                              'Ürünlerin bu cihazda kayıtlı. Stok ve hatırlatmalarını kullanabilirsin.',
                              style: TextStyle(
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        if (api.configured)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: api.busy || auth.validating
                                  ? null
                                  : () => auth.revalidate(),
                              child: Text(
                                api.busy || auth.validating
                                    ? 'Kontrol ediliyor…'
                                    : 'Tekrar dene',
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class SlowRequestHint extends StatelessWidget {
  const SlowRequestHint({super.key, required this.auth});
  final AuthController auth;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: auth.api,
    builder: (context, _) => !auth.api.slow
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Semantics(
              liveRegion: true,
              child: const Text(
                'Bağlantı yavaş; işlemin sürüyor. Tekrar basmana gerek yok.',
              ),
            ),
          ),
  );
}
