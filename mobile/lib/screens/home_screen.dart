import 'dart:async';
import 'package:flutter/material.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';
import '../services/notification_service.dart';
import 'product_form.dart';
import '../widgets/kitchen_dashboard.dart';
import '../widgets/kitchen_navigation.dart';
import '../widgets/loading_skeleton.dart';
import '../design/taze_theme.dart';
import '../services/receipt_scanner.dart';
import 'receipt_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.notifications,
    this.onProfile,
    this.profileName,
    this.receiptScanner,
  });
  final ProductRepository repository;
  final NotificationService notifications;
  final VoidCallback? onProfile;
  final String? profileName;
  final ReceiptScanner? receiptScanner;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<Product> products = [];
  int tab = 0;
  bool loading = true, busy = false, enabled = false;
  String location = 'Tümü';
  final searchController = TextEditingController();
  bool onlySoon = false, sortByName = false;
  bool showConsumed = false;
  String? error, notificationError;
  TimeOfDay time = const TimeOfDay(hour: 10, minute: 0);
  Timer? timer;
  bool reloadPending = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
    if (widget.repository is SqliteProductRepository) {
      (widget.repository as SqliteProductRepository).events.addListener(
        repositoryChanged,
      );
    }
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    if (widget.repository is SqliteProductRepository) {
      (widget.repository as SqliteProductRepository).events.removeListener(
        repositoryChanged,
      );
    }
    timer?.cancel();
    searchController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void repositoryChanged() {
    final repo = widget.repository;
    if (repo is! SqliteProductRepository ||
        repo.events.last?.owner != repo.ownerId ||
        !mounted) {
      return;
    }
    if (loading || busy) {
      reloadPending = true;
      return;
    }
    runAction(() async {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !loading && !busy) {
      runAction(() async {});
    }
  }

  void tell(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Future<void> load() async {
    try {
      products = await widget.repository.all();
      enabled = await widget.repository.setting('notifications') == 'true';
      final hour =
          int.tryParse(await widget.repository.setting('hour') ?? '') ?? 10;
      final minute =
          int.tryParse(await widget.repository.setting('minute') ?? '') ?? 0;
      time = TimeOfDay(hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
      await schedule();
      error = null;
    } catch (_) {
      error = 'Ürünler yüklenemedi. Tekrar dene.';
    }
    if (mounted) setState(() => loading = false);
    if (mounted && reloadPending) {
      reloadPending = false;
      runAction(() async {});
    }
    if (widget.receiptScanner != null && mounted) {
      try {
        final recovered = await widget.receiptScanner!.recover();
        if (recovered != null && mounted) await receipt(recovered);
      } catch (_) {
        tell('Önceki fiş fotoğrafı kurtarılamadı. Fişi yeniden seçebilirsin.');
      }
    }
  }

  Future<void> schedule() async {
    try {
      final limited = await widget.notifications.reschedule(
        products,
        enabled: enabled,
        hour: time.hour,
        minute: time.minute,
      );
      notificationError = limited
          ? 'En yakın 60 bildirim günü planlandı. Diğer günler uygulamayı açtığında yenilenir.'
          : null;
    } catch (_) {
      notificationError =
          'Hatırlatmalar telefona planlanamadı. Ürünlerin kayıtlı; uygulama içinden takip edebilirsin. Bildirim ayarlarından tekrar dene.';
    }
  }

  Future<void> runAction(Future<void> Function() action) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await action();
      products = await widget.repository.all();
      await schedule();
    } catch (_) {
      tell('İşlem tamamlanamadı. Lütfen tekrar dene.');
    } finally {
      if (mounted) {
        setState(() => busy = false);
        if (reloadPending) {
          reloadPending = false;
          runAction(() async {});
        }
      }
    }
  }

  Future<void> edit([Product? p, bool markOpened = false]) async {
    final result = await Navigator.push<Product>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductForm(
          product: p,
          markOpened: markOpened,
          initialLocation: location == 'Tümü' ? 'Buzdolabı' : location,
          repository: widget.repository,
          canSave: () => mounted,
          onSave: (product) async {
            if (!mounted) throw StateError('Account changed');
            if (p == null &&
                widget.repository is SqliteProductRepository &&
                await (widget.repository as SqliteProductRepository).revisionOf(
                      product.id,
                    ) !=
                    null) {
              throw const StaleProductEdit();
            }
            await widget.repository.save(product);
          },
        ),
      ),
    );
    if (result != null && mounted) {
      await runAction(() async {});
    }
  }

  Future<void> receipt([String? initialText]) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ReceiptScreen(
          scanner: widget.receiptScanner ?? DeviceReceiptScanner(),
          initialText: initialText,
          initialLocation: location == 'Tümü' ? 'Buzdolabı' : location,
          repository: widget.repository,
          canSave: () => mounted,
          onSave: (products) async {
            if (!mounted) throw StateError('Account changed');
            if (widget.repository is SqliteProductRepository) {
              final repo = widget.repository as SqliteProductRepository;
              for (final product in products) {
                if (await repo.revisionOf(product.id) != null) {
                  throw const StaleProductEdit();
                }
              }
            }
            await widget.repository.saveAll(products);
            // Notification failures must not turn a successful save into a retry.
            if (!mounted) return;
            this.products = await widget.repository.all();
            await schedule();
            if (mounted) setState(() {});
          },
        ),
      ),
    );
  }

  Future<void> add() async {
    final method = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Mutfağına nasıl ekleyelim?',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit_note_rounded),
                title: const Text('Elle ürün ekle'),
                subtitle: const Text('Bir ürünün bilgilerini kendin gir.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(ctx, 'manual'),
              ),
              ListTile(
                leading: const Icon(Icons.document_scanner_outlined),
                title: const Text('Fişten ürün ekle'),
                subtitle: const Text(
                  'Fotoğrafı tara, ürünleri kontrol edip ekle.',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.pop(ctx, 'receipt'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (method == 'manual') await edit();
    if (method == 'receipt') await receipt();
  }

  Future<void> settings() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, update) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hatırlatma ayarları',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Telefon bildirimleri'),
                    value: enabled,
                    onChanged: busy
                        ? null
                        : (v) async {
                            await runAction(() async {
                              if (v &&
                                  !await widget.notifications
                                      .requestPermission()) {
                                tell(
                                  'Bildirim izni verilmedi. Telefonun uygulama ayarlarını kontrol et.',
                                );
                                return;
                              }
                              await widget.repository.setSetting(
                                'notifications',
                                '$v',
                              );
                              enabled = v;
                            });
                            if (sheetContext.mounted) update(() {});
                          },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_outlined),
                    title: const Text('Hatırlatma saati'),
                    subtitle: Text(time.format(context)),
                    onTap: busy
                        ? null
                        : () async {
                            final selected = await showTimePicker(
                              context: context,
                              initialTime: time,
                            );
                            if (selected == null || !mounted) return;
                            await runAction(() async {
                              await widget.repository.setSetting(
                                'hour',
                                '${selected.hour}',
                              );
                              await widget.repository.setSetting(
                                'minute',
                                '${selected.minute}',
                              );
                              time = selected;
                            });
                            if (sheetContext.mounted) update(() {});
                          },
                  ),
                  const Text(
                    '3, 2 ve 1 gün kala, son gün ve ertesi gün hatırlatılır. Aynı güne denk gelen ürünler tek bildirimde toplanır.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Hatırlatmalar cihazda planlanır. İnternet gerekmez; telefon izinleri ve pil yönetimi teslimi geciktirebilir. Ayarlanan saat geçtiyse bugünün uyarıları Hatırlatmalar sekmesinde görünür.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Ürünlerin bu cihazda saklanır. Hatırlatmalar için internet bağlantısı gerekmez.',
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: busy
                        ? null
                        : () async {
                            await runAction(() async {});
                            if (sheetContext.mounted) update(() {});
                          },
                    child: const Text('Hatırlatmaları yeniden planla'),
                  ),
                  if (notificationError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(notificationError!),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> remove(Product p) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ürün kaldırılsın mı?'),
        content: Text('${p.name} ve bekleyen hatırlatmaları kaldırılacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await runAction(() => widget.repository.delete(p.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = theme.colorScheme;
    final style = StorageStyle.of(location);
    final pageColor = Color.lerp(
      scheme.surface,
      style.background(context),
      location == 'Tümü' ? 0 : .32,
    );
    return Scaffold(
      backgroundColor: pageColor,
      appBar: AppBar(
        backgroundColor: pageColor,
        toolbarHeight: 76,
        titleSpacing: 24,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                Icons.eco_outlined,
                color: scheme.onPrimary,
                size: 25,
              ),
            ),
            const SizedBox(width: 10),
            const Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'taze kal',
                  style: TextStyle(
                    fontSize: 25,
                    letterSpacing: -1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (widget.onProfile != null)
            IconButton(
              onPressed: busy ? null : widget.onProfile,
              tooltip: widget.profileName == null
                  ? 'Giriş yap veya kayıt ol'
                  : 'Profilim',
              icon: const Icon(Icons.person_outline_rounded),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton.filledTonal(
              onPressed: busy ? null : settings,
              tooltip: 'Hatırlatma ayarları',
              style: IconButton.styleFrom(
                backgroundColor: style.background(context),
                foregroundColor: style.foreground(context),
              ),
              icon: const Icon(Icons.notifications_outlined),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: loading
            ? const KitchenSkeleton()
            : error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_off_outlined, size: 40),
                      const SizedBox(height: 16),
                      Text(error!),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () {
                          setState(() => loading = true);
                          load();
                        },
                        child: const Text('Tekrar dene'),
                      ),
                    ],
                  ),
                ),
              )
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: MotionReveal(
                    replayKey: '$tab:$location',
                    child: KitchenDashboard(
                      products: products,
                      tab: tab,
                      location: location,
                      searchController: searchController,
                      busy: busy,
                      enabled: enabled,
                      onlySoon: onlySoon,
                      sortByName: sortByName,
                      showConsumed: showConsumed,
                      onHistoryFilter: (value) =>
                          setState(() => showConsumed = value),
                      notificationError: notificationError,
                      onLocation: (value) => setState(() => location = value),
                      onSearch: (_) => setState(() {}),
                      onSoon: () => setState(() => onlySoon = !onlySoon),
                      onSort: () => setState(() => sortByName = !sortByName),
                      onAdd: add,
                      onReminders: () => setState(() {
                        tab = 1;
                        onlySoon = false;
                      }),
                      onSettings: settings,
                      onConsume: (p) => runAction(
                        () => widget.repository.save(
                          p.copyWith(status: 'consumed'),
                        ),
                      ),
                      onOpen: (p) => edit(p, true),
                      onEdit: (p) => edit(p),
                      onRemove: remove,
                    ),
                  ),
                ),
              ),
      ),
      bottomNavigationBar: KitchenNavigation(
        selectedIndex: tab,
        expiredCount: products
            .where((p) => p.status == 'active' && p.isPast(DateTime.now()))
            .length,
        busy: busy || loading || error != null,
        onAdd: add,
        onSelected: (i) => setState(() {
          if (tab != i) {
            location = 'Tümü';
            searchController.clear();
          }
          tab = i;
          onlySoon = false;
        }),
      ),
    );
  }
}
