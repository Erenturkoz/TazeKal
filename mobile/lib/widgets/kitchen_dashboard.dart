import 'package:flutter/material.dart';
import '../design/taze_icons.dart';
import '../design/taze_theme.dart';
import '../domain/product.dart';
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
    required this.sortByName,
    required this.onLocation,
    required this.onSearch,
    required this.onSort,
    required this.onAdd,
    required this.onSettings,
    required this.onConsume,
    required this.onOpen,
    required this.onEdit,
    required this.onRemove,
    this.onReceipt,
    this.notificationError,
    this.showConsumed = false,
    this.onHistoryFilter,
  });
  final List<Product> products;
  final int tab;
  final String location;
  final TextEditingController searchController;
  final bool busy, enabled, sortByName;
  final ValueChanged<String> onLocation, onSearch;
  final VoidCallback onSort, onAdd, onSettings;
  final VoidCallback? onReceipt;
  final ValueChanged<Product> onConsume, onOpen, onEdit, onRemove;
  final String? notificationError;
  final bool showConsumed;
  final ValueChanged<bool>? onHistoryFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = StorageStyle.of(location), now = DateTime.now();
    final active = products
        .where((p) => p.status == 'active' && !p.isPast(now))
        .toList();
    bool inSection(Product p) => tab == 2
        ? (showConsumed
              ? p.status == 'consumed'
              : p.status == 'active' && p.isPast(now))
        : p.status == 'active' && !p.isPast(now);
    bool isSoon(Product p) =>
        p.hasTrackingDate && p.daysLeft(now) >= 0 && p.daysLeft(now) <= 3;
    final scoped = products
        .where(
          (p) => inSection(p) && (location == 'Tümü' || p.location == location),
        )
        .toList();
    final soon = active.where(isSoon).length;
    final undated = active.where((p) => !p.hasTrackingDate).length;
    final query = searchController.text.toLowerCase().replaceAll('ı', 'i');
    final rows =
        scoped
            .where(
              (p) =>
                  (tab != 1 || (p.hasTrackingDate && p.daysLeft(now) <= 3)) &&
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

    // Bölümler: Mutfağım'da önce 3 gün içindekiler, Hatırlatmalar'da güne
    // göre. Ada göre sıralamada ve Geçmiş'te tek liste.
    final sections = <(String?, List<Product>)>[];
    if (sortByName || tab == 2) {
      sections.add((null, rows));
    } else if (tab == 0) {
      final first = rows.where(isSoon).toList();
      final rest = rows.where((p) => !isSoon(p)).toList();
      if (first.isNotEmpty) {
        sections.add(('3 gün içinde · ${first.length}', first));
      }
      if (rest.isNotEmpty) sections.add(('Takipte · ${rest.length}', rest));
    } else {
      for (final p in rows) {
        final n = p.daysLeft(now);
        final title = n <= 0
            ? 'Bugün'
            : n == 1
            ? 'Yarın'
            : longDay(p.effectiveExpiry!);
        if (sections.isEmpty || sections.last.$1 != title) {
          sections.add((title, [p]));
        } else {
          sections.last.$2.add(p);
        }
      }
    }

    return CustomScrollView(
      key: PageStorageKey('kitchen-scroll:$tab:$showConsumed'),
      slivers: [
        const SliverToBoxAdapter(child: ConnectionBanner(localData: true)),
        const SliverToBoxAdapter(child: SyncStatus()),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: TazeSpace.page),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 3,
                  child: busy ? const LinearProgressIndicator() : null,
                ),
                const SizedBox(height: TazeSpace.sm),
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
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: TazeSpace.lg),
                ],
                if (emptyKitchen) ...[
                  _WelcomeCard(onAdd: onAdd, onReceipt: onReceipt),
                  const SizedBox(height: TazeSpace.xl),
                  const _Hints(),
                  const SizedBox(height: TazeSpace.lg),
                ] else if (tab == 0) ...[
                  _Summary(
                    large: scale > 1.4,
                    items: [
                      _SummaryItem(
                        value: active.length,
                        label: 'Stokta',
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      _SummaryItem(
                        value: soon,
                        label: '3 gün içinde',
                        color: soon > 0
                            ? status.caution
                            : theme.colorScheme.onSurfaceVariant,
                        emphasize: soon > 0,
                      ),
                      _SummaryItem(
                        value: undated,
                        label: 'Tarihsiz',
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                  const SizedBox(height: TazeSpace.lg),
                ],
                if (notificationError != null) ...[
                  _Notice(
                    text: notificationError!,
                    action: 'Ayarlar',
                    onTap: onSettings,
                  ),
                  const SizedBox(height: TazeSpace.md),
                ],
                if (tab == 1 && !enabled) ...[
                  _Notice(
                    text:
                        'Bildirimler kapalı. Aç, tarihi yaklaşınca haber verelim.',
                    action: 'Aç',
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
                  _StorageTabs(
                    twoRows: scale > 1.3,
                    selected: location,
                    countOf: (s) => products
                        .where(
                          (p) =>
                              inSection(p) &&
                              (s.name == 'Tümü' || p.location == s.name),
                        )
                        .length,
                    onSelected: onLocation,
                  ),
                  const SizedBox(height: TazeSpace.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          onChanged: onSearch,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: location == 'Tümü'
                                ? 'Ürün ara'
                                : '$location içinde ara',
                            prefixIcon: const Padding(
                              padding: EdgeInsets.all(14),
                              child: TazeIconView(TazeIcon.search, size: 20),
                            ),
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
                      ),
                      const SizedBox(width: TazeSpace.sm),
                      IconButton.outlined(
                        onPressed: onSort,
                        tooltip: sortByName
                            ? 'Sıralama: ada göre'
                            : 'Sıralama: tarihe göre',
                        isSelected: sortByName,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(50, 50),
                          side: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(TazeRadius.md),
                          ),
                        ),
                        icon: const TazeIconView(TazeIcon.sort, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: TazeSpace.lg),
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
                filtered: query.isNotEmpty,
                reminders: tab == 1,
                consumed: tab == 2 && showConsumed,
                expired: tab == 2 && !showConsumed,
              ),
            ),
          ),
        for (final (title, items) in sections)
          if (items.isNotEmpty) ...[
            if (title != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  TazeSpace.page,
                  0,
                  TazeSpace.page,
                  TazeSpace.sm,
                ),
                sliver: SliverToBoxAdapter(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontSize: 13,
                        color: tab == 1 && title == 'Bugün'
                            ? status.danger
                            : tab == 1 && title == 'Yarın'
                            ? status.caution
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
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
                itemCount: items.length,
                itemBuilder: (context, index) => _ProductRow(
                  product: items[index],
                  now: now,
                  busy: busy,
                  first: index == 0,
                  last: index == items.length - 1,
                  onConsume: onConsume,
                  onOpen: onOpen,
                  onEdit: onEdit,
                  onRemove: onRemove,
                ),
              ),
            ),
          ],
      ],
    );
  }
}

/// Boş mutfakta tek karşılama: ne işe yaradığını söyler ve ilk eylemi verir.
class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.onAdd, this.onReceipt});
  final VoidCallback onAdd;
  final VoidCallback? onReceipt;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          TazeSpace.xl,
          TazeSpace.xl + 4,
          TazeSpace.xl,
          TazeSpace.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Wrap(
                spacing: TazeSpace.sm + 2,
                runSpacing: TazeSpace.sm,
                children: [
                  for (final s in StorageStyle.values.skip(1))
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: s.background(context),
                        borderRadius: BorderRadius.circular(TazeRadius.md),
                      ),
                      child: Center(
                        child: TazeIconView(
                          s.icon,
                          size: 26,
                          color: s.foreground(context),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: TazeSpace.lg + 4),
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
              style: theme.textTheme.bodyLarge?.copyWith(
                fontSize: 15,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: TazeSpace.lg + 4),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const TazeIconView(TazeIcon.plus, size: 20),
              label: const Text('İlk ürünü ekle'),
            ),
            if (onReceipt != null) ...[
              const SizedBox(height: TazeSpace.sm),
              OutlinedButton.icon(
                onPressed: onReceipt,
                icon: const TazeIconView(TazeIcon.receipt, size: 20),
                label: const Text('Fişten ekle'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Hints extends StatelessWidget {
  const _Hints();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.onSurfaceVariant;
    Widget hint(TazeIcon icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: TazeSpace.md + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TazeIconView(icon, size: 20, color: color),
          const SizedBox(width: TazeSpace.md),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
    return Column(
      children: [
        hint(TazeIcon.soon, 'Tarihi 3 gün içinde dolanlar en üstte görünür.'),
        hint(
          TazeIcon.bell,
          'Hatırlatmalar cihazda planlanır, internet gerekmez.',
        ),
        hint(
          TazeIcon.fridge,
          'Tarih bilinmiyorsa uygun ürünler için kaynağı belli bir tahmin önerilir.',
        ),
      ],
    );
  }
}

class _SummaryItem {
  const _SummaryItem({
    required this.value,
    required this.label,
    required this.color,
    this.emphasize = false,
  });
  final int value;
  final String label;
  final Color color;
  final bool emphasize;
}

/// Tek kartta üç sayı. Miktarlar farklı birimler taşıdığı için kayıt sayılır.
class _Summary extends StatelessWidget {
  const _Summary({required this.items, required this.large});
  final List<_SummaryItem> items;
  final bool large;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget label(_SummaryItem item) => Text(
      item.label,
      style: theme.textTheme.labelMedium?.copyWith(color: item.color),
    );
    Widget value(_SummaryItem item) => Text(
      '${item.value}',
      style: theme.textTheme.headlineMedium?.copyWith(
        color: item.emphasize ? item.color : null,
      ),
    );
    Widget cell(_SummaryItem item) => Semantics(
      label: '${item.label}: ${item.value} ürün',
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: TazeSpace.lg,
          vertical: large ? TazeSpace.sm : TazeSpace.md + 2,
        ),
        // Büyük metinde sayı etiketin yanına alınır; kart gereksiz uzamaz.
        child: large
            ? Row(
                children: [
                  Expanded(child: label(item)),
                  value(item),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [label(item), const SizedBox(height: 2), value(item)],
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

/// Zemin üzerinde bölümlü seçici; seçili alan yükseltilmiş kart yüzeyidir.
class _StorageTabs extends StatelessWidget {
  const _StorageTabs({
    required this.twoRows,
    required this.selected,
    required this.countOf,
    required this.onSelected,
  });
  final bool twoRows;
  final String selected;
  final int Function(StorageStyle) countOf;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = theme.colorScheme;
    final colors = TazeStatusColors.of(context);
    Widget tab(StorageStyle s) {
      final on = selected == s.name, count = countOf(s);
      return Semantics(
        selected: on,
        button: true,
        label: '${s.name}, $count ürün',
        excludeSemantics: true,
        child: Material(
          color: on ? colors.card : Colors.transparent,
          elevation: on ? 1 : 0,
          shadowColor: Colors.black26,
          borderRadius: BorderRadius.circular(TazeRadius.sm + 2),
          child: InkWell(
            borderRadius: BorderRadius.circular(TazeRadius.sm + 2),
            onTap: () => onSelected(s.name),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 2,
                  vertical: TazeSpace.xs,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontSize: 13,
                        fontWeight: on ? FontWeight.w700 : FontWeight.w600,
                        color: on && s.name != 'Tümü'
                            ? s.foreground(context)
                            : scheme.onSurface,
                      ),
                    ),
                    Text(
                      '$count',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final styles = StorageStyle.values;
    return Container(
      padding: const EdgeInsets.all(TazeSpace.xs),
      decoration: BoxDecoration(
        color: colors.track,
        borderRadius: BorderRadius.circular(TazeRadius.md + 2),
      ),
      child: twoRows
          ? Column(
              children: [
                for (var r = 0; r < 2; r++)
                  Row(
                    children: [
                      for (var c = 0; c < 2; c++) ...[
                        if (c > 0) const SizedBox(width: TazeSpace.xs),
                        Expanded(child: tab(styles[r * 2 + c])),
                      ],
                    ],
                  ),
              ],
            )
          : Row(
              children: [
                for (var i = 0; i < styles.length; i++) ...[
                  if (i > 0) const SizedBox(width: TazeSpace.xs),
                  Expanded(child: tab(styles[i])),
                ],
              ],
            ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.text,
    required this.action,
    required this.onTap,
  });
  final String text, action;
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.all(TazeSpace.md),
            child: Row(
              children: [
                const SizedBox(width: TazeSpace.xs),
                TazeIconView(
                  TazeIcon.bellOff,
                  size: 20,
                  color: status.onCautionContainer,
                ),
                const SizedBox(width: TazeSpace.md),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: status.onCautionContainer,
                    ),
                  ),
                ),
                const SizedBox(width: TazeSpace.sm),
                Text(
                  action,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: status.onCautionContainer,
                  ),
                ),
                const SizedBox(width: TazeSpace.xs),
              ],
            ),
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
            TazeIcon.noResults,
            'Sonuç yok',
            'Aramayı değiştir; diğer depolama alanlarına da bakabilirsin.',
          )
        : reminders
        ? (
            TazeIcon.allGood,
            'Acil bir şey yok',
            'Tarihi 3 gün içinde dolan ürünler burada görünür.',
          )
        : expired
        ? (
            TazeIcon.allGood,
            'Tarihi geçen ürün yok',
            'Tarihi geçen ürünler burada toplanır; ana stok listene karışmaz.',
          )
        : consumed
        ? (
            TazeIcon.consumed,
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
          TazeIconView(
            icon,
            size: 32,
            color: theme.colorScheme.onSurfaceVariant,
          ),
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

enum _Tone { ok, caution, danger, done }

/// Ürünün durumu: listede kısa metin, ayrıntıda uzun metin ve ton.
class _Status {
  factory _Status(Product product, DateTime now) {
    final n = product.effectiveExpiry == null ? 999999 : product.daysLeft(now);
    final estimate = product.usesEstimate;
    if (product.status == 'consumed') {
      return const _Status._('Tüketildi', '', 'Tüketildi', _Tone.done);
    }
    if (n < 0) {
      return _Status._(
        'Geçti',
        shortDay(product.effectiveExpiry!),
        'Kontrol edilmeli',
        _Tone.danger,
      );
    }
    if (!product.hasTrackingDate) {
      final none = product.expiresAt == null && product.openedAt == null;
      return _Status._(
        'Tarih yok',
        none ? 'eklenmedi' : 'bilgi eksik',
        none ? 'Tarih eklenmedi' : 'Açılma süresi için bilgi eksik',
        _Tone.caution,
      );
    }
    if (n == 0) {
      return const _Status._('Bugün', 'son gün', 'Bugün tüket', _Tone.danger);
    }
    if (n <= 3) {
      return _Status._(
        '$n gün',
        estimate ? 'tahmini' : 'kaldı',
        '${estimate ? 'Tahmini ' : ''}$n gün kaldı',
        _Tone.caution,
      );
    }
    final date = product.effectiveExpiry!;
    return _Status._(
      n <= 14 ? '$n gün' : shortDay(date),
      estimate
          ? 'tahmini'
          : n <= 14
          ? shortDay(date)
          : '${date.year}',
      '${estimate ? 'Tahmini son gün' : 'Son gün'} ${displayDate(date)}',
      _Tone.ok,
    );
  }
  const _Status._(this.short, this.sub, this.long, this.tone);
  final String short, sub, long;
  final _Tone tone;

  Color color(BuildContext context) {
    final status = TazeStatusColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    return switch (tone) {
      _Tone.danger => status.danger,
      _Tone.caution => status.caution,
      _Tone.done => scheme.primary,
      _Tone.ok => scheme.onSurface,
    };
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.product,
    required this.now,
    required this.busy,
    required this.first,
    required this.last,
    required this.onConsume,
    required this.onOpen,
    required this.onEdit,
    required this.onRemove,
  });
  final Product product;
  final DateTime now;
  final bool busy, first, last;
  final ValueChanged<Product> onConsume, onOpen, onEdit, onRemove;

  void details(BuildContext context) {
    final status = _Status(product, now);
    final colors = TazeStatusColors.of(context);
    final consumed = product.status == 'consumed';
    final style = StorageStyle.of(product.location);
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (status.tone) {
      _Tone.danger => (colors.dangerContainer, colors.onDangerContainer),
      _Tone.caution => (colors.cautionContainer, colors.onCautionContainer),
      _ => (scheme.surfaceContainerHigh, scheme.onSurface),
    };
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) {
        final theme = Theme.of(sheet);
        void act(ValueChanged<Product> action) {
          Navigator.pop(sheet);
          action(product);
        }

        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              TazeSpace.page,
              0,
              TazeSpace.page,
              TazeSpace.page,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _FoodTile(product: product, size: 52),
                    const SizedBox(width: TazeSpace.md + 2),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: theme.textTheme.headlineSmall,
                          ),
                          Text(
                            '${product.quantity} · ${product.location}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TazeSpace.lg + 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: TazeSpace.lg,
                    vertical: TazeSpace.md + 2,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(TazeRadius.md),
                  ),
                  child: Row(
                    children: [
                      TazeIconView(
                        switch (status.tone) {
                          _Tone.danger => TazeIcon.expired,
                          _Tone.done => TazeIcon.consumed,
                          _ =>
                            product.hasTrackingDate
                                ? TazeIcon.soon
                                : TazeIcon.noDate,
                        },
                        size: 22,
                        color: fg,
                      ),
                      const SizedBox(width: TazeSpace.md),
                      Expanded(
                        child: Text(
                          status.long,
                          style: TextStyle(
                            color: fg,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!consumed && status.short == 'Geçti')
                  Padding(
                    padding: const EdgeInsets.only(top: TazeSpace.sm),
                    child: Text(
                      'Bu ürün bozulmuş olabilir. Tüketim süresi geçti.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.danger,
                      ),
                    ),
                  ),
                const SizedBox(height: TazeSpace.sm),
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
                const SizedBox(height: TazeSpace.lg),
                if (!consumed) ...[
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: busy ? null : () => act(onConsume),
                          icon: const TazeIconView(TazeIcon.check, size: 20),
                          label: const Text('Tükettim'),
                        ),
                      ),
                      if (product.openedAt == null) ...[
                        const SizedBox(width: TazeSpace.sm),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: busy ? null : () => act(onOpen),
                            icon: TazeIconView(
                              TazeIcon.opened,
                              size: 20,
                              color: style.foreground(sheet),
                            ),
                            label: const Text('Bugün açtım'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: TazeSpace.sm),
                ],
                Row(
                  children: [
                    if (!consumed)
                      Expanded(
                        child: TextButton.icon(
                          onPressed: busy ? null : () => act(onEdit),
                          icon: const TazeIconView(TazeIcon.edit, size: 18),
                          label: const Text('Düzenle'),
                        ),
                      ),
                    Expanded(
                      child: TextButton(
                        onPressed: busy ? null : () => act(onRemove),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.danger,
                        ),
                        child: const Text('Kaldır'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context), scheme = theme.colorScheme;
    final colors = TazeStatusColors.of(context);
    final status = _Status(product, now);
    final consumed = product.status == 'consumed';
    const radius = Radius.circular(TazeRadius.lg);
    final line = scheme.outlineVariant.withValues(alpha: .6);
    final shape = RoundedRectangleBorder(
      side: BorderSide(color: line),
      borderRadius: BorderRadius.vertical(
        top: first ? radius : Radius.zero,
        bottom: last ? radius : Radius.zero,
      ),
    );
    final meta = [
      product.quantity,
      product.location,
      if (product.openedAt != null && !consumed) 'açıldı',
    ].where((t) => t.isNotEmpty).join(' · ');
    // Kenarlık yalnız dışta: satırlar arası çizgi ayrı çizilir, böylece grup
    // tek kart gibi görünür.
    return Transform.translate(
      offset: Offset(0, first ? 0 : -1),
      child: Material(
        color: colors.card,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: '${product.name}, $meta, ${status.long}',
                excludeSemantics: true,
                child: InkWell(
                  onTap: () => details(context),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      TazeSpace.md + 2,
                      TazeSpace.md,
                      TazeSpace.sm,
                      TazeSpace.md,
                    ),
                    child: Row(
                      children: [
                        _FoodTile(product: product, size: 40),
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
                              Text(meta, style: theme.textTheme.bodySmall),
                            ],
                          ),
                        ),
                        const SizedBox(width: TazeSpace.sm),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              status.short,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: status.color(context),
                              ),
                            ),
                            if (status.sub.isNotEmpty)
                              Text(
                                status.sub,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (!consumed)
              Padding(
                padding: const EdgeInsets.only(right: TazeSpace.sm),
                child: IconButton.outlined(
                  onPressed: busy ? null : () => onConsume(product),
                  tooltip: '${product.name}: tükettim',
                  style: IconButton.styleFrom(
                    foregroundColor: scheme.primary,
                    side: BorderSide(color: line),
                  ),
                  icon: const TazeIconView(TazeIcon.check, size: 20),
                ),
              )
            else
              const SizedBox(width: TazeSpace.md),
          ],
        ),
      ),
    );
  }
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({required this.product, required this.size});
  final Product product;
  final double size;
  @override
  Widget build(BuildContext context) {
    final style = StorageStyle.of(product.location);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: style.background(context),
        borderRadius: BorderRadius.circular(
          size > 44 ? TazeRadius.md : TazeRadius.sm,
        ),
      ),
      child: Center(
        child: TazeIconView(
          foodIconFor(product.name, product.location),
          size: size * .55,
          color: style.foreground(context),
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
