import 'package:flutter/material.dart';
import '../design/taze_theme.dart';
import '../domain/product.dart';
import 'pantry_art.dart';
import 'shelf_life_panel.dart';
import 'connection_status.dart';
import 'sync_status.dart';

class KitchenDashboard extends StatelessWidget {
  const KitchenDashboard({
    super.key,
    required this.products,
    required this.tab,
    required this.location,
    required this.searchController,
    required this.busy,
    required this.enabled,
    required this.onlySoon,
    required this.sortByName,
    required this.onLocation,
    required this.onSearch,
    required this.onSoon,
    required this.onSort,
    required this.onAdd,
    required this.onReminders,
    required this.onSettings,
    required this.onConsume,
    required this.onOpen,
    required this.onEdit,
    required this.onRemove,
    this.notificationError,
    this.showConsumed = false,
    this.onHistoryFilter,
  });
  final List<Product> products;
  final int tab;
  final String location;
  final TextEditingController searchController;
  final bool busy, enabled, onlySoon, sortByName;
  final ValueChanged<String> onLocation, onSearch;
  final VoidCallback onSoon, onSort, onAdd, onReminders, onSettings;
  final ValueChanged<Product> onConsume, onOpen, onEdit, onRemove;
  final String? notificationError;
  final bool showConsumed;
  final ValueChanged<bool>? onHistoryFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = theme.colorScheme;
    final style = StorageStyle.of(location), now = DateTime.now();
    final active = products
        .where((p) => p.status == 'active' && !p.isPast(now))
        .toList();
    bool inSection(Product p) => tab == 2
        ? (showConsumed
              ? p.status == 'consumed'
              : p.status == 'active' && p.isPast(now))
        : p.status == 'active' && !p.isPast(now);
    final scoped = products
        .where(
          (p) => inSection(p) && (location == 'Tümü' || p.location == location),
        )
        .toList();
    final soon = active
        .where(
          (p) =>
              p.hasTrackingDate && p.daysLeft(now) >= 0 && p.daysLeft(now) <= 3,
        )
        .length;
    final past = active.where((p) => !p.hasTrackingDate).length;
    final query = searchController.text.toLowerCase().replaceAll('ı', 'i');
    final rows =
        scoped
            .where(
              (p) =>
                  ((tab != 1 && !onlySoon) ||
                      (p.hasTrackingDate && p.daysLeft(now) <= 3)) &&
                  p.name.toLowerCase().replaceAll('ı', 'i').contains(query),
            )
            .toList()
          ..sort(
            (a, b) => sortByName
                ? a.name.compareTo(b.name)
                : a.effectiveExpiry == null
                ? (b.effectiveExpiry == null ? a.name.compareTo(b.name) : 1)
                : b.effectiveExpiry == null
                ? -1
                : a.effectiveExpiry!.compareTo(b.effectiveExpiry!),
          );
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final urgent = soon + past;
    return CustomScrollView(
      key: PageStorageKey('kitchen-scroll:$tab:$showConsumed'),
      slivers: [
        const SliverToBoxAdapter(child: ConnectionBanner(localData: true)),
        const SliverToBoxAdapter(child: SyncStatus()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (busy)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: LinearProgressIndicator(),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tab == 0
                            ? 'EV MUTFAĞIN'
                            : tab == 1
                            ? 'TAZELİK TAKİBİ'
                            : 'MUTFAK GEÇMİŞİN',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (scale <= 1.4) ...[
                      Icon(
                        Icons.circle,
                        size: 6,
                        color: style.foreground(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Cihazda kayıtlı',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                Semantics(
                  header: true,
                  child: Text(
                    tab == 0
                        ? (active.isEmpty
                              ? 'Mutfağın,\nkontrol altında.'
                              : 'Mutfağın hazır.')
                        : tab == 1
                        ? 'Önce tazelik.'
                        : 'Geçmişin burada.',
                    style: theme.textTheme.headlineLarge,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  tab == 0
                      ? (active.isEmpty
                            ? 'Neyin var, ne zaman tüketilmeli? Bir bakışta gör.'
                            : 'Stoklarını gör, önceliğini seç.')
                      : tab == 1
                      ? 'Yaklaşan tarihleri birlikte takip edelim.'
                      : 'Tarihi geçenler ve tükettiklerin ana stoktan ayrı.',
                  style: TextStyle(color: scheme.onSurfaceVariant, height: 1.5),
                ),
                const SizedBox(height: 24),
                if (tab == 0) ...[
                  if (active.isEmpty)
                    _FreshnessHero(
                      style: style,
                      urgent: urgent,
                      onTap: onReminders,
                    ),
                  if (active.isEmpty) const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final children = [
                        _Metric(
                          value: '${active.length}',
                          title: 'Stoktaki ürün',
                          icon: Icons.inventory_2_outlined,
                          color: style.foreground(context),
                        ),
                        _Metric(
                          value: '$soon',
                          title: 'Yaklaşan tarih',
                          icon: Icons.schedule_rounded,
                          color: const Color(0xff956224),
                        ),
                        _Metric(
                          value: '$past',
                          title: 'Tarihi belirsiz',
                          icon: Icons.info_outline_rounded,
                          color: const Color(0xffa34b3c),
                        ),
                      ];
                      if (scale > 1.4) {
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: children
                              .map(
                                (w) => SizedBox(
                                  width: constraints.maxWidth,
                                  child: w,
                                ),
                              )
                              .toList(),
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < children.length; i++) ...[
                            if (i > 0) const SizedBox(width: 10),
                            Expanded(child: children[i]),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                ],
                if (tab == 1) ...[
                  _FreshnessStrip(
                    style: style,
                    urgent: urgent,
                    onTap: onSettings,
                  ),
                  const SizedBox(height: 16),
                ],
                if (notificationError != null) ...[
                  _Notice(text: notificationError!, onTap: onSettings),
                  const SizedBox(height: 16),
                ],
                if (tab == 1 && !enabled) ...[
                  _Notice(
                    text:
                        'Telefon hatırlatmalarını aç, yaklaşan tarihleri kaçırma.',
                    onTap: onSettings,
                  ),
                  const SizedBox(height: 16),
                ],
                if (tab == 2) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(
                          'Tarihi geçenler (${products.where((p) => p.status == 'active' && p.isPast(now)).length})',
                        ),
                        selected: !showConsumed,
                        onSelected: (_) => onHistoryFilter?.call(false),
                      ),
                      ChoiceChip(
                        label: Text(
                          'Tüketilenler (${products.where((p) => p.status == 'consumed').length})',
                        ),
                        selected: showConsumed,
                        onSelected: (_) => onHistoryFilter?.call(true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          tab == 2
                              ? (showConsumed
                                    ? 'Tüketilen ürünler'
                                    : 'Tarihi geçen ürünler')
                              : 'Depolama alanların',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                    ),
                    Text(
                      '${scoped.length} ürün',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoRows = scale > 1.3 || constraints.maxWidth < 325;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: StorageStyle.values.map((s) {
                        final count = products
                            .where(
                              (p) =>
                                  inSection(p) &&
                                  (s.name == 'Tümü' || p.location == s.name),
                            )
                            .length;
                        return SizedBox(
                          width:
                              (constraints.maxWidth - (twoRows ? 8 : 24)) /
                              (twoRows ? 2 : 4),
                          child: _StorageTab(
                            style: s,
                            count: count,
                            selected: location == s.name,
                            onTap: () => onLocation(s.name),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
                const SizedBox(height: 22),
                if (location != 'Tümü') ...[
                  Row(
                    children: [
                      Icon(
                        style.icon,
                        size: 19,
                        color: style.foreground(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          style.description,
                          style: TextStyle(
                            color: style.foreground(context),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: searchController,
                  onChanged: onSearch,
                  decoration: InputDecoration(
                    hintText: location == 'Tümü'
                        ? 'Mutfağında ara…'
                        : '$location içinde ara…',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Aramayı temizle',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              searchController.clear();
                              onSearch('');
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (tab != 2)
                      FilterChip(
                        label: const Text('Önce tüket'),
                        avatar: const Icon(Icons.timelapse_rounded, size: 18),
                        selected: tab == 1 || onlySoon,
                        onSelected: tab == 1 ? null : (_) => onSoon(),
                      ),
                    TextButton.icon(
                      onPressed: onSort,
                      icon: const Icon(Icons.swap_vert_rounded, size: 18),
                      label: Text(
                        sortByName ? 'Ürün adına göre' : 'En yakın tarih',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (rows.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      '${rows.length} ${tab == 2 ? (showConsumed ? 'tüketilen' : 'tarihi geçen') : 'kayıtlı'} ürün',
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (rows.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverToBoxAdapter(
              child: _EmptyState(
                style: style,
                filtered: query.isNotEmpty || onlySoon || tab == 1,
                consumed: tab == 2 && showConsumed,
                expired: tab == 2 && !showConsumed,
                onAdd: onAdd,
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) => _ProductTile(
              product: rows[index],
              now: now,
              busy: busy,
              onConsume: onConsume,
              onOpen: onOpen,
              onEdit: onEdit,
              onRemove: onRemove,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.eco_outlined,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    'Az israf. Daha çok tazelik.',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FreshnessStrip extends StatelessWidget {
  const _FreshnessStrip({
    required this.style,
    required this.urgent,
    required this.onTap,
  });
  final StorageStyle style;
  final int urgent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: style.accent,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.spa_outlined,
                color: Color(0xffe5efcf),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    urgent == 0
                        ? 'Tazelik kontrol altında.'
                        : '$urgent ürüne öncelik ver.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Hatırlatma ayarlarını aç',
                    style: TextStyle(color: Color(0xffedf2e4), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_rounded,
              color: Colors.white,
              size: 20,
            ),
          ],
        ),
      ),
    ),
  );
}

class _FreshnessHero extends StatelessWidget {
  const _FreshnessHero({
    required this.style,
    required this.urgent,
    required this.onTap,
  });
  final StorageStyle style;
  final int urgent;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 12, 18),
      decoration: BoxDecoration(
        color: style.accent,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'KÜÇÜK BİR KONTROL, BÜYÜK BİR FARK',
                  style: TextStyle(
                    color: Color(0xffe1edcd),
                    fontSize: 9,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  urgent == 0
                      ? 'Tazeliğe yer aç.'
                      : '$urgent ürünün\nseni bekliyor.',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.7,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  urgent == 0
                      ? 'Elindekileri bil, zamanında tüket.'
                      : 'Yaklaşan ve geçen tarihleri kontrol et.',
                  style: const TextStyle(
                    color: Color(0xffedf2e4),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    backgroundColor: Colors.white.withValues(alpha: .12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'Tazelik kontrolü',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!large) ...[
            const SizedBox(width: 4),
            PantryArt(accent: style.accent),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.value,
    required this.title,
    required this.icon,
    required this.color,
  });
  final String value, title;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: dark ? scheme.surfaceContainer : Colors.white,
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              if (MediaQuery.textScalerOf(context).scale(1) <= 1.4)
                Icon(
                  icon,
                  size: 20,
                  color: dark ? Color.lerp(color, Colors.white, .5) : color,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageTab extends StatelessWidget {
  const _StorageTab({
    required this.style,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  final StorageStyle style;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: '${style.name}, $count ürün',
    excludeSemantics: true,
    child: Material(
      color: selected ? style.accent : style.background(context),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          child: Column(
            children: [
              Icon(
                style.icon,
                size: 24,
                color: selected ? Colors.white : style.foreground(context),
              ),
              const SizedBox(height: 10),
              Text(
                style.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : style.foreground(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count ürün',
                style: TextStyle(
                  color: selected ? Colors.white : style.foreground(context),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.onTap});
  final String text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.secondaryContainer,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.notifications_outlined),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.style,
    required this.filtered,
    required this.consumed,
    required this.onAdd,
    this.expired = false,
  });
  final StorageStyle style;
  final bool filtered, consumed;
  final bool expired;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: style.background(context),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            shape: BoxShape.circle,
          ),
          child: Icon(
            filtered ? Icons.manage_search_rounded : style.icon,
            size: 32,
            color: style.foreground(context),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          filtered
              ? 'Burada her şey yolunda.'
              : expired
              ? 'Tarihi geçen ürün yok.'
              : consumed
              ? 'Güzel alışkanlıklar birikir.'
              : 'İlk ürünle başlayalım.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          filtered
              ? 'Bu arama veya filtreye uygun ürün yok. Diğer alanlarına da göz atabilirsin.'
              : expired
              ? 'Tarihi geçen ürünlerin burada saklanır; ana stok listene karışmaz.'
              : consumed
              ? '“Tükettim” dediğin ürünler burada yerini alacak.'
              : '${style.name == 'Tümü' ? 'Mutfağındaki' : '${style.name} içindeki'} ürünleri ekle, stoklarını ve tarihlerini kolayca takip et.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.6,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.now,
    required this.busy,
    required this.onConsume,
    required this.onOpen,
    required this.onEdit,
    required this.onRemove,
  });
  final Product product;
  final DateTime now;
  final bool busy;
  final ValueChanged<Product> onConsume, onOpen, onEdit, onRemove;
  IconData get foodIcon {
    final name = product.name.toLowerCase();
    if (name.contains('süt') ||
        name.contains('yoğurt') ||
        name.contains('peynir')) {
      return Icons.local_drink_outlined;
    }
    if (name.contains('ekmek') ||
        name.contains('un') ||
        name.contains('makarna')) {
      return Icons.bakery_dining_outlined;
    }
    if (name.contains('elma') ||
        name.contains('muz') ||
        name.contains('domates') ||
        name.contains('avokado')) {
      return Icons.eco_outlined;
    }
    return StorageStyle.of(product.location).icon;
  }

  void details(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                product.name,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text('${product.quantity} · ${product.location}'),
              const SizedBox(height: 24),
              _DetailLine('Alış tarihi', displayDate(product.purchasedAt)),
              _DetailLine(
                product.usesPurchaseEstimate
                    ? 'Tahmini tarih'
                    : 'Ambalaj tarihi',
                displayDate(product.expiresAt),
              ),
              if (product.openingDays != null)
                _DetailLine(
                  'Açıldıktan sonra',
                  '${product.openingDays} gün${product.afterOpeningDays == null ? ' • tahmini' : ' • ambalaj talimatı'}',
                ),
              if (product.openedAt != null)
                _DetailLine('Açılma tarihi', displayDate(product.openedAt!)),
              if (product.hasTrackingDate)
                _DetailLine(
                  'Takip edilen tarih',
                  displayDate(product.effectiveExpiry),
                ),
              const SizedBox(height: 16),
              ShelfLifePanel(product: product, now: now, showSource: true),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Tamam'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme,
        style = StorageStyle.of(product.location);
    final n = product.effectiveExpiry == null ? 999999 : product.daysLeft(now),
        consumed = product.status == 'consumed';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final unknown = !product.hasTrackingDate;
    final warning = !consumed && (unknown || n <= 3);
    final statusColor = consumed
        ? scheme.primary
        : n < 0
        ? scheme.error
        : unknown
        ? (dark ? const Color(0xffedc17e) : const Color(0xff88591e))
        : n <= 3
        ? (dark ? const Color(0xffedc17e) : const Color(0xff88591e))
        : style.foreground(context);
    final label = consumed
        ? 'Tüketildi'
        : n < 0
        ? 'Kontrol edilmeli'
        : unknown
        ? (product.expiresAt == null && product.openedAt == null
              ? 'Tarih eklenmedi'
              : 'Açılma süresi için bilgi eksik')
        : n == 0
        ? 'Bugün tüket'
        : n <= 3
        ? '${product.usesEstimate ? 'Tahmini ' : ''}$n gün kaldı'
        : 'Tazeliği takipte';
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: dark ? scheme.surfaceContainer : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => details(context),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 8, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 54,
                      height: 58,
                      decoration: BoxDecoration(
                        color: style.background(context),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        foodIcon,
                        size: 28,
                        color: style.foreground(context),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${product.quantity} · ${product.location}',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Icon(
                                warning
                                    ? Icons.schedule_rounded
                                    : consumed
                                    ? Icons.check_circle_outline
                                    : Icons.circle_outlined,
                                size: 14,
                                color: statusColor,
                              ),
                              Text(
                                label,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (!warning && !consumed)
                                Text(
                                  '· ${product.usesEstimate ? 'Tahmini ' : ''}${displayDate(product.effectiveExpiry)}',
                                  style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          if (product.openedAt != null && !consumed)
                            Padding(
                              padding: const EdgeInsets.only(top: 7),
                              child: Text(
                                'Açılmış ürün',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: '${product.name} seçenekleri',
                      enabled: !busy,
                      icon: const Icon(Icons.more_horiz_rounded),
                      onSelected: (action) {
                        if (action == 'edit') onEdit(product);
                        if (action == 'remove') onRemove(product);
                        if (action == 'details') details(context);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'details',
                          child: Text('Ürün detayı'),
                        ),
                        if (!consumed)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Düzenle'),
                          ),
                        const PopupMenuItem(
                          value: 'remove',
                          child: Text('Kaldır'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (!consumed &&
                (product.openedAt != null || product.openingProfile != null))
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
                child: ShelfLifePanel(product: product, now: now),
              ),
            if (!consumed && n < 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  'Bu ürün bozulmuş olabilir. Tüketim süresi geçti.',
                  style: TextStyle(color: scheme.error, fontSize: 12),
                ),
              ),
            if (!consumed) ...[
              Divider(
                height: 1,
                indent: 18,
                endIndent: 18,
                color: scheme.outlineVariant.withValues(alpha: .55),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                child: Wrap(
                  spacing: 8,
                  children: [
                    TextButton.icon(
                      onPressed: busy ? null : () => onConsume(product),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text(
                        'Tükettim',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                    if (product.openedAt == null)
                      TextButton(
                        onPressed: busy ? null : () => onOpen(product),
                        child: const Text(
                          'Bugün açtım',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                  ],
                ),
              ),
            ] else
              const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 20,
      runSpacing: 4,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
    ),
  );
}
