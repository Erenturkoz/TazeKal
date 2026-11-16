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
  final VoidCallback onSoon, onSort, onAdd, onSettings;
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
    final status = TazeStatusColors.of(context);
    final expiredCount = products
        .where((p) => p.status == 'active' && p.isPast(now))
        .length;
    final consumedCount = products.where((p) => p.status == 'consumed').length;
    final emptyKitchen = tab == 0 && active.isEmpty;
    final filtered = query.isNotEmpty || onlySoon;
    return CustomScrollView(
      key: PageStorageKey('kitchen-scroll:$tab:$showConsumed'),
      slivers: [
        const SliverToBoxAdapter(child: ConnectionBanner(localData: true)),
        const SliverToBoxAdapter(child: SyncStatus()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            TazeSpace.page,
            TazeSpace.sm,
            TazeSpace.page,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 3,
                  child: busy ? const LinearProgressIndicator() : null,
                ),
                const SizedBox(height: TazeSpace.md),
                if (tab != 0) ...[
                  Semantics(
                    header: true,
                    child: Text(
                      tab == 1 ? 'Yaklaşan tarihler' : 'Mutfak geçmişi',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: TazeSpace.xs),
                  Text(
                    tab == 1
                        ? (soon == 0
                              ? 'Önümüzdeki 3 gün içinde tarihi dolan ürün yok.'
                              : '$soon ürünün tarihi 3 gün içinde doluyor.')
                        : 'Tarihi geçenler ve tükettiklerin ana stoktan ayrı tutulur.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: TazeSpace.lg),
                ],
                if (emptyKitchen) ...[
                  _WelcomeCard(onAdd: onAdd),
                  const SizedBox(height: TazeSpace.xl),
                ] else if (tab == 0) ...[
                  _Summary(
                    large: scale > 1.4,
                    items: [
                      _SummaryItem(
                        value: active.length,
                        label: 'Stokta',
                        icon: Icons.inventory_2_outlined,
                        color: scheme.primary,
                      ),
                      _SummaryItem(
                        value: soon,
                        label: 'Yaklaşan',
                        icon: Icons.schedule_rounded,
                        color: soon > 0
                            ? status.caution
                            : scheme.onSurfaceVariant,
                      ),
                      _SummaryItem(
                        value: past,
                        label: 'Tarihsiz',
                        icon: Icons.help_outline_rounded,
                        color: past > 0
                            ? status.caution
                            : scheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: TazeSpace.xl),
                ],
                if (notificationError != null) ...[
                  _Notice(
                    text: notificationError!,
                    icon: Icons.notifications_off_outlined,
                    onTap: onSettings,
                  ),
                  const SizedBox(height: TazeSpace.md),
                ],
                if (tab == 1 && !enabled) ...[
                  _Notice(
                    text:
                        'Telefon hatırlatmaları kapalı. Açarsan yaklaşan tarihleri bildirim olarak alırsın.',
                    icon: Icons.notifications_outlined,
                    onTap: onSettings,
                  ),
                  const SizedBox(height: TazeSpace.lg),
                ],
                if (tab == 2) ...[
                  Wrap(
                    spacing: TazeSpace.sm,
                    runSpacing: TazeSpace.sm,
                    children: [
                      ChoiceChip(
                        label: Text('Tarihi geçenler ($expiredCount)'),
                        selected: !showConsumed,
                        onSelected: (_) => onHistoryFilter?.call(false),
                      ),
                      ChoiceChip(
                        label: Text('Tüketilenler ($consumedCount)'),
                        selected: showConsumed,
                        onSelected: (_) => onHistoryFilter?.call(true),
                      ),
                    ],
                  ),
                  const SizedBox(height: TazeSpace.lg),
                ],
                if (!emptyKitchen) ...[
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final twoRows = scale > 1.3 || constraints.maxWidth < 325;
                      const gap = TazeSpace.sm;
                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
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
                                (constraints.maxWidth -
                                    (twoRows ? gap : gap * 3)) /
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
                  const SizedBox(height: TazeSpace.md),
                  TextField(
                    controller: searchController,
                    onChanged: onSearch,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: location == 'Tümü'
                          ? 'Ürün ara'
                          : '$location içinde ara',
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
                  const SizedBox(height: TazeSpace.sm),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: TazeSpace.sm,
                    children: [
                      if (tab == 0)
                        FilterChip(
                          label: const Text('Önce tüket'),
                          avatar: const Icon(Icons.timelapse_rounded, size: 18),
                          selected: onlySoon,
                          onSelected: (_) => onSoon(),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(left: TazeSpace.xs),
                          child: Text(
                            '${rows.length} ürün',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      TextButton.icon(
                        onPressed: onSort,
                        icon: const Icon(Icons.swap_vert_rounded, size: 18),
                        label: Text(sortByName ? 'Ada göre' : 'Tarihe göre'),
                      ),
                    ],
                  ),
                  const SizedBox(height: TazeSpace.sm),
                ],
              ],
            ),
          ),
        ),
        if (rows.isEmpty && !emptyKitchen)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: TazeSpace.page),
            sliver: SliverToBoxAdapter(
              child: _EmptyState(
                style: style,
                filtered: filtered,
                reminders: tab == 1,
                consumed: tab == 2 && showConsumed,
                expired: tab == 2 && !showConsumed,
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            TazeSpace.page,
            0,
            TazeSpace.page,
            TazeSpace.xl,
          ),
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
      ],
    );
  }
}

/// Boş mutfakta tek karşılama: ne işe yaradığını söyler ve ilk eylemi verir.
class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!large)
            Container(
              height: 148,
              color: StorageStyle.all.accent,
              alignment: Alignment.center,
              child: PantryArt(accent: StorageStyle.all.accent),
            ),
          Padding(
            padding: const EdgeInsets.all(TazeSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Mutfağın şimdilik boş.',
                    style: theme.textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: TazeSpace.sm),
                Text(
                  'Ürünlerini ve son tüketim tarihlerini ekle. Tarihi yaklaşanları sıralar, istersen telefonuna hatırlatırız.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: TazeSpace.lg),
                FilledButton.tonalIcon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('İlk ürünü ekle'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryItem {
  const _SummaryItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });
  final int value;
  final String label;
  final IconData icon;
  final Color color;
}

/// Tek kartta üç sayı. Miktarlar farklı birimler taşıdığı için kayıt sayılır.
class _Summary extends StatelessWidget {
  const _Summary({required this.items, required this.large});
  final List<_SummaryItem> items;
  final bool large;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget label(_SummaryItem item) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(item.icon, size: 16, color: item.color),
        const SizedBox(width: TazeSpace.xs + 2),
        Flexible(
          child: Text(
            item.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
    Widget value(_SummaryItem item) =>
        Text('${item.value}', style: theme.textTheme.headlineMedium);
    Widget cell(_SummaryItem item) => Semantics(
      label: '${item.label}: ${item.value} ürün',
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: TazeSpace.lg,
          vertical: large ? TazeSpace.sm : TazeSpace.lg,
        ),
        // Büyük metinde sayı etiketin yanına alınır; kart gereksiz uzamaz.
        child: large
            ? Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: label(item),
                    ),
                  ),
                  value(item),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  label(item),
                  const SizedBox(height: TazeSpace.xs),
                  value(item),
                ],
              ),
      ),
    );
    return Card(
      child: large
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  cell(items[i]),
                ],
              ],
            )
          : IntrinsicHeight(
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const VerticalDivider(width: 1),
                    Expanded(child: cell(items[i])),
                  ],
                ],
              ),
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = theme.colorScheme;
    final fg = selected ? style.foreground(context) : scheme.onSurface;
    return Semantics(
      selected: selected,
      button: true,
      label: '${style.name}, $count ürün',
      excludeSemantics: true,
      child: Material(
        color: selected
            ? style.background(context)
            : TazeStatusColors.of(context).card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TazeRadius.md),
          side: BorderSide(
            color: selected
                ? style.foreground(context)
                : scheme.outlineVariant.withValues(alpha: .6),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(TazeRadius.md),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: TazeSpace.xs,
                vertical: TazeSpace.sm,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    style.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: fg,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$count',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: selected ? fg : scheme.onSurfaceVariant,
                    ),
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

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.icon, required this.onTap});
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final status = TazeStatusColors.of(context);
    return Material(
      color: status.cautionContainer,
      borderRadius: BorderRadius.circular(TazeRadius.md),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TazeRadius.md),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TazeSpace.lg,
            TazeSpace.md,
            TazeSpace.sm,
            TazeSpace.md,
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: status.onCautionContainer),
              const SizedBox(width: TazeSpace.md),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: status.onCautionContainer,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: status.onCautionContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.style,
    required this.filtered,
    required this.consumed,
    this.expired = false,
    this.reminders = false,
  });
  final StorageStyle style;
  final bool filtered, consumed, expired, reminders;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, title, body) = filtered
        ? (
            Icons.search_off_rounded,
            'Sonuç yok',
            'Aramayı veya filtreyi değiştir; diğer depolama alanlarına da bakabilirsin.',
          )
        : reminders
        ? (
            Icons.check_circle_outline_rounded,
            'Acil bir şey yok',
            'Tarihi 3 gün içinde dolan ürünler burada görünür.',
          )
        : expired
        ? (
            Icons.check_circle_outline_rounded,
            'Tarihi geçen ürün yok',
            'Tarihi geçen ürünler burada toplanır; ana stok listene karışmaz.',
          )
        : consumed
        ? (
            Icons.history_rounded,
            'Henüz tüketilen ürün yok',
            '“Tükettim” dediğin ürünler burada listelenir.',
          )
        : (
            style.icon,
            '${style.name == 'Tümü' ? 'Stokta' : '${style.name} alanında'} ürün yok',
            'Yeni ürünü alttaki “Ürün ekle” düğmesiyle ekleyebilirsin.',
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TazeSpace.xxl),
      child: Column(
        children: [
          Icon(icon, size: 32, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: TazeSpace.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: TazeSpace.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
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
          padding: const EdgeInsets.fromLTRB(
            TazeSpace.xl,
            0,
            TazeSpace.xl,
            TazeSpace.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                product.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: TazeSpace.xs),
              Text(
                '${product.quantity} · ${product.location}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: TazeSpace.lg),
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
              const SizedBox(height: TazeSpace.lg),
              ShelfLifePanel(product: product, now: now, showSource: true),
              const SizedBox(height: TazeSpace.xl),
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
    final theme = Theme.of(context), scheme = theme.colorScheme;
    final style = StorageStyle.of(product.location);
    final status = TazeStatusColors.of(context);
    final n = product.effectiveExpiry == null ? 999999 : product.daysLeft(now),
        consumed = product.status == 'consumed';
    final unknown = !product.hasTrackingDate;
    final past = !consumed && n < 0;
    final warning = !consumed && (unknown || n <= 3);
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
        : '${product.usesEstimate ? 'Tahmini ' : ''}${displayDate(product.effectiveExpiry)}';
    final (pillColor, pillText, pillIcon) = past
        ? (
            status.dangerContainer,
            status.onDangerContainer,
            Icons.error_outline,
          )
        : warning
        ? (
            status.cautionContainer,
            status.onCautionContainer,
            unknown ? Icons.help_outline_rounded : Icons.schedule_rounded,
          )
        : consumed
        ? (
            scheme.secondaryContainer,
            scheme.onSecondaryContainer,
            Icons.check_rounded,
          )
        : (
            scheme.surfaceContainerHigh,
            scheme.onSurfaceVariant,
            Icons.event_outlined,
          );
    return Padding(
      padding: const EdgeInsets.only(bottom: TazeSpace.md),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => details(context),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  TazeSpace.lg,
                  TazeSpace.lg,
                  TazeSpace.xs,
                  TazeSpace.md,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: style.background(context),
                        borderRadius: BorderRadius.circular(TazeRadius.sm),
                      ),
                      child: Icon(
                        foodIcon,
                        size: 22,
                        color: style.foreground(context),
                      ),
                    ),
                    const SizedBox(width: TazeSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              product.quantity,
                              product.location,
                              if (product.openedAt != null && !consumed)
                                'Açılmış ürün',
                            ].where((t) => t.isNotEmpty).join(' · '),
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: TazeSpace.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: TazeSpace.sm,
                              vertical: TazeSpace.xs,
                            ),
                            decoration: BoxDecoration(
                              color: pillColor,
                              borderRadius: BorderRadius.circular(
                                TazeRadius.sm,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(pillIcon, size: 14, color: pillText),
                                const SizedBox(width: TazeSpace.xs),
                                Flexible(
                                  child: Text(
                                    label,
                                    style: TextStyle(
                                      color: pillText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: '${product.name} seçenekleri',
                      enabled: !busy,
                      icon: const Icon(Icons.more_vert_rounded),
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
            if (past)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TazeSpace.lg,
                  0,
                  TazeSpace.lg,
                  TazeSpace.md,
                ),
                child: Text(
                  'Bu ürün bozulmuş olabilir. Tüketim süresi geçti.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: status.danger,
                  ),
                ),
              ),
            if (!consumed &&
                (product.openedAt != null || product.openingProfile != null))
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TazeSpace.lg,
                  0,
                  TazeSpace.lg,
                  TazeSpace.md,
                ),
                child: ShelfLifePanel(product: product, now: now),
              ),
            if (!consumed) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: TazeSpace.sm),
                child: Wrap(
                  spacing: TazeSpace.xs,
                  children: [
                    TextButton.icon(
                      onPressed: busy ? null : () => onConsume(product),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Tükettim'),
                    ),
                    if (product.openedAt == null)
                      TextButton.icon(
                        onPressed: busy ? null : () => onOpen(product),
                        icon: const Icon(Icons.lock_open_rounded, size: 18),
                        label: const Text('Bugün açtım'),
                      ),
                  ],
                ),
              ),
            ],
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: TazeSpace.md),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: .5),
        ),
      ),
    ),
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: TazeSpace.lg,
      runSpacing: TazeSpace.xs,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}
