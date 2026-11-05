import 'package:flutter/material.dart';
import '../data/product_repository.dart';
import '../data/sync_models.dart';
import '../domain/product.dart';
import '../domain/opening_profile.dart';
import '../services/product_sync.dart';

class SyncScope extends InheritedWidget {
  const SyncScope({super.key, required this.sync, required super.child});
  final ProductSync sync;
  static ProductSync? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SyncScope>()?.sync;
  @override
  bool updateShouldNotify(SyncScope oldWidget) => sync != oldWidget.sync;
}

class SyncHost extends StatefulWidget {
  const SyncHost({super.key, required this.sync, required this.child});
  final ProductSync sync;
  final Widget child;
  @override
  State<SyncHost> createState() => _SyncHostState();
}

class _SyncHostState extends State<SyncHost> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.sync.start();
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) {
      widget.sync.pause();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.sync.resume();
    } else {
      widget.sync.pause();
    }
  }

  @override
  void dispose() {
    widget.sync.stop();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      SyncScope(sync: widget.sync, child: widget.child);
}

class SyncStatus extends StatelessWidget {
  const SyncStatus({super.key});
  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.maybeOf(context);
    if (sync == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: sync,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final guest = sync.owner == null;
        final title = guest
            ? 'Hesapsız kullanım • Bu cihazda'
            : sync.syncing
            ? 'Ürünlerin eşitleniyor'
            : sync.conflicts.isNotEmpty
            ? '${sync.conflicts.length} ürün için seçim gerekiyor'
            : sync.error != null
            ? 'Eşitleme bekliyor'
            : sync.pending > 0
            ? '${sync.pending} ürün gönderilmeyi bekliyor'
            : sync.lastSuccess != null
            ? 'Ürünlerin hesabına eşitlendi'
            : 'Hesabınla eşitleme hazırlanıyor';
        return Container(
          margin: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    guest
                        ? Icons.phone_android_outlined
                        : sync.conflicts.isNotEmpty
                        ? Icons.merge_type_rounded
                        : Icons.cloud_sync_outlined,
                    color: scheme.primary,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              if (sync.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(sync.error!),
                ),
              if (guest)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'Hesaba giriş yaparak ürünlerini hesabına kaydedip diğer cihazlarında kullanabilirsin.',
                  ),
                ),
              if (!guest)
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: sync.syncing
                          ? null
                          : () => sync.sync(force: true),
                      child: const Text('Şimdi eşitle'),
                    ),
                    if (sync.conflicts.isNotEmpty)
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => SyncConflicts(sync: sync),
                          ),
                        ),
                        child: const Text('Farkları incele'),
                      ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}

class SyncConflicts extends StatefulWidget {
  const SyncConflicts({super.key, required this.sync});
  final ProductSync sync;
  @override
  State<SyncConflicts> createState() => _SyncConflictsState();
}

class _SyncConflictsState extends State<SyncConflicts> {
  String describe(Product p) =>
      '${p.name}\n${p.quantity} • ${p.location}\n'
      'Alış: ${displayDate(p.purchasedAt)}\nAmbalaj: ${displayDate(p.expiresAt)}\n'
      'Açılma: ${p.openedAt == null ? 'Açılmamış' : displayDate(p.openedAt!)}\n'
      'Tür: ${OpeningProfile.find(p.openingProfileId)?.label ?? 'Belirtilmedi'}\n'
      '${p.afterOpeningDays == null ? '' : 'Ambalaj talimatı: ${p.afterOpeningDays} gün\n'}'
      '0–4°C saklama onayı: ${p.coldStorageConfirmed ? 'Var' : 'Yok'}\n'
      '${p.status == 'consumed' ? 'Tüketildi' : 'Stokta'}';
  late final owner = widget.sync.owner;
  bool busy = false;
  String? error;
  Future<void> choose(ProductConflict conflict, bool local) async {
    if (busy || widget.sync.owner != owner) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.sync.resolve(conflict, keepLocal: local);
    } catch (failure) {
      if (mounted) {
        error = failure is StaleProductEdit
            ? failure.toString()
            : 'Seçim kaydedilemedi. Tekrar dene.';
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ürün farklarını incele')),
    body: AnimatedBuilder(
      animation: widget.sync,
      builder: (context, _) {
        if (owner == null || widget.sync.owner != owner) {
          return const Center(
            child: Text('Hesap değişti. Bu ekranı kapatabilirsin.'),
          );
        }
        final conflicts = widget.sync.conflicts;
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'İki cihaz aynı ürünü değiştirmiş. Her iki sürüm korunuyor; hangisini kullanacağını seç.',
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (conflicts.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Text('Bekleyen bir fark yok.'),
              ),
            for (final conflict in conflicts)
              Card(
                margin: const EdgeInsets.only(top: 16),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        conflict.local.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Bu cihazda',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        conflict.localDeleted
                            ? 'Kaldırılmış'
                            : describe(conflict.local),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Sunucuda',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        conflict.remote == null || conflict.remote!.deleted
                            ? 'Ürün bulunmuyor / kaldırılmış'
                            : describe(conflict.remote!.product!),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: busy ? null : () => choose(conflict, true),
                        child: const Text('Bu cihazdaki sürümü koru'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: busy ? null : () => choose(conflict, false),
                        child: const Text('Sunucudaki sürümü kullan'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}
