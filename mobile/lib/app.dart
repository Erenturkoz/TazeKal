import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data/product_repository.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'design/taze_theme.dart';
import 'auth/auth_api.dart';
import 'auth/auth_controller.dart';
import 'auth/session_vault.dart';
import 'auth/google_identity.dart';
import 'auth/account_gate.dart';
import 'services/receipt_scanner.dart';
import 'widgets/connection_status.dart';
import 'services/product_sync.dart';
import 'widgets/sync_status.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final repository = await SqliteProductRepository.open();
    final auth = AuthController(
      api: AuthApi(),
      vault: const SecureSessionVault(),
      google: DeviceGoogleIdentity(),
    );
    runApp(
      TazeKalApp(
        repository: repository,
        notifications: NotificationService(),
        auth: auth,
        sync: ProductSync(auth: auth, repository: repository),
        receiptScanner: DeviceReceiptScanner(),
      ),
    );
    await auth.restore();
  } catch (_) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Veritabanı açılamadı. Uygulamayı yeniden başlatmayı dene.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: main,
                    child: const Text('Tekrar dene'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TazeKalApp extends StatelessWidget {
  const TazeKalApp({
    super.key,
    required this.repository,
    required this.notifications,
    this.auth,
    this.receiptScanner,
    this.sync,
  });
  final ProductRepository repository;
  final NotificationService notifications;
  final AuthController? auth;
  final ReceiptScanner? receiptScanner;
  final ProductSync? sync;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Taze Kal',
    debugShowCheckedModeBanner: false,
    locale: const Locale('tr'),
    supportedLocales: const [Locale('tr')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: TazeTheme.create(Brightness.light),
    darkTheme: TazeTheme.create(Brightness.dark),
    builder: (context, child) => auth == null
        ? child!
        : AccountConnectionScope(
            auth: auth!,
            child: ConnectionWatch(
              auth: auth!,
              child: sync == null
                  ? child!
                  : SyncHost(sync: sync!, child: child!),
            ),
          ),
    home: auth != null && repository is AccountProductRepository
        ? AccountGate(
            auth: auth!,
            repository: repository as AccountProductRepository,
            notifications: notifications,
            receiptScanner: receiptScanner,
          )
        : HomeScreen(
            repository: repository,
            notifications: notifications,
            receiptScanner: receiptScanner,
          ),
  );
}
