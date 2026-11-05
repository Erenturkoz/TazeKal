import 'package:flutter/material.dart';
import '../data/product_repository.dart';
import '../screens/home_screen.dart';
import '../services/notification_service.dart';
import 'auth_controller.dart';
import 'auth_screen.dart';
import 'profile_screen.dart';
import '../services/receipt_scanner.dart';
import '../widgets/loading_skeleton.dart';

class AccountGate extends StatefulWidget {
  const AccountGate({
    super.key,
    required this.auth,
    required this.repository,
    required this.notifications,
    this.receiptScanner,
  });
  final AuthController auth;
  final AccountProductRepository repository;
  final NotificationService notifications;
  final ReceiptScanner? receiptScanner;
  @override
  State<AccountGate> createState() => _AccountGateState();
}

class _AccountGateState extends State<AccountGate> {
  bool guestMode = false;
  int revision = 0;
  String? previousOwner;
  bool switching = false;
  String? switchError;
  @override
  void initState() {
    super.initState();
    widget.auth.addListener(changed);
    if (!widget.auth.restoring) {
      switching = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) changed();
      });
    }
  }

  Future<void> changed() async {
    if (widget.auth.restoring) {
      if (mounted) setState(() {});
      return;
    }
    final owner = widget.auth.user?.id ?? (guestMode ? 'guest' : 'signed-out');
    if (owner != previousOwner) {
      previousOwner = owner;
      if (mounted) setState(() => switching = true);
      // Finish cancelling the old account before mounting the new HomeScreen.
      switchError = null;
      try {
        await widget.notifications.reschedule(
          [],
          enabled: false,
          hour: 10,
          minute: 0,
        );
      } catch (_) {
        switchError =
            'Bildirim alanı hazırlanamadı. Hesaplar arasında güvenli geçiş için tekrar dene.';
      }
      if (mounted && previousOwner == owner) setState(() => switching = false);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.auth.removeListener(changed);
    super.dispose();
  }

  Future<void> profile() async {
    if (widget.auth.user == null) {
      guestMode = false;
      await changed();
      return;
    }
    final owner = widget.auth.user!.id;
    final count = await widget.repository.guestCount();
    if (!mounted || widget.auth.user?.id != owner) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (profileContext) => ProfileScreen(
          auth: widget.auth,
          guestCount: count,
          onImport: () async {
            if (widget.auth.user?.id != owner) {
              throw StateError('Account changed');
            }
            await widget.repository.moveGuestTo(owner);
            if (mounted) setState(() => revision++);
          },
          onLogout: () async {
            await widget.auth.logout();
            if (profileContext.mounted) Navigator.pop(profileContext);
            if (mounted) setState(() => guestMode = false);
          },
          onLocalLogout: () async {
            await widget.auth.logoutLocally();
            if (profileContext.mounted) Navigator.pop(profileContext);
            if (mounted) setState(() => guestMode = false);
          },
        ),
      ),
    );
    if (mounted) setState(() => revision++);
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.auth;
    if (switchError != null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(switchError!),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      previousOwner = null;
                      changed();
                    },
                    child: const Text('Tekrar dene'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (auth.restoring || switching) {
      return const StartupSkeleton();
    }
    if (auth.user == null && !guestMode) {
      return AuthScreen(
        auth: auth,
        onGuest: () {
          guestMode = true;
          changed();
        },
      );
    }
    final owner = auth.user?.id ?? 'guest';
    return HomeScreen(
      key: ValueKey('$owner:$revision'),
      repository: widget.repository.forOwner(owner),
      notifications: widget.notifications,
      onProfile: profile,
      profileName: auth.user?.displayName,
      receiptScanner: widget.receiptScanner,
    );
  }
}
