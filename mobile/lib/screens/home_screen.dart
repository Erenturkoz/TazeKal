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
import '../widgets/status_message.dart';
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
          padding: const EdgeInsets.fromLTRB(
            TazeSpace.sm,
            0,
            TazeSpace.sm,
            TazeSpace.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TazeSpace.lg,
                  0,
                  TazeSpace.lg,
                  TazeSpace.md,
                ),
                child: Text(
                  'Nasıl eklemek istersin?',
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
              padding: const EdgeInsets.fromLTRB(
                TazeSpace.xl,
                0,
                TazeSpace.xl,
                TazeSpace.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hatırlatma ayarları',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: TazeSpace.sm),
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
                  const SizedBox(height: TazeSpace.sm),
                  Text(
                    'Son tüketim tarihine 3, 2 ve 1 gün kala, son gün ve ertesi gün hatırlatılır. Aynı güne denk gelen ürünler tek bildirimde toplanır.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: TazeSpace.sm),
                  Text(
                    'Hatırlatmalar cihazda planlanır, internet gerekmez. Telefon izinleri ve pil tasarrufu teslimi geciktirebilir; kaçırılan uyarılar Hatırlatmalar sekmesinde görünür.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: TazeSpace.lg),
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () async {
                            await runAction(() async {});
                            if (sheetContext.mounted) update(() {});
                          },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Hatırlatmaları yeniden planla'),
                  ),
                  if (notificationError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: TazeSpace.md),
                      child: Text(
                        notificationError!,
                        style: TextStyle(
                          color: TazeStatusColors.of(context).caution,
                        ),
                      ),
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
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: TazeSpace.page,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.eco_rounded, color: scheme.primary, size: 24),
            const SizedBox(width: TazeSpace.sm),
            const Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Taze Kal',
                  style: TextStyle(
                    fontSize: 20,
                    letterSpacing: -.4,
                    fontWeight: FontWeight.w700,
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
              icon: const Icon(Icons.account_circle_outlined),
            ),
          Padding(
            padding: const EdgeInsets.only(right: TazeSpace.sm),
            child: IconButton(
              onPressed: busy ? null : settings,
              tooltip: 'Hatırlatma ayarları',
              icon: Icon(
                enabled
                    ? Icons.notifications_active_outlined
                    : Icons.notifications_none_rounded,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: loading
            ? const KitchenSkeleton()
            : error != null
            ? StatusMessage(
                icon: Icons.error_outline_rounded,
                title: 'Ürünler yüklenemedi',
                message: 'Cihazdaki kayıtlar okunamadı. Verilerin silinmedi.',
                actionLabel: 'Tekrar dene',
                onAction: () {
                  setState(() => loading = true);
                  load();
                },
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
