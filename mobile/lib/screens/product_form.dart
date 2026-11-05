import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/product.dart';
import '../domain/opening_profile.dart';
import '../domain/shelf_life_profile.dart';
import '../widgets/shelf_life_panel.dart';
import '../data/product_repository.dart';
import '../data/form_draft.dart';
import '../widgets/draft_status.dart';

class ProductForm extends StatefulWidget {
  const ProductForm({
    super.key,
    this.product,
    this.initialName = '',
    this.initialQuantity = '1 adet',
    this.initialLocation = 'Buzdolabı',
    this.markOpened = false,
    this.repository,
    this.onSave,
    this.canSave,
  }) : assert(!markOpened || product != null);
  final Product? product;
  final bool markOpened;
  final ProductRepository? repository;
  final Future<void> Function(Product)? onSave;
  final bool Function()? canSave;
  final String initialName, initialQuantity, initialLocation;
  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> with WidgetsBindingObserver {
  final form = GlobalKey<FormState>();
  final expiryField = GlobalKey<FormFieldState<DateTime>>();
  late final TextEditingController name, quantity, days;
  late DateTime purchased;
  DateTime? expiry, opened;
  late String location;
  bool details = false;
  String? openingProfileId;
  String? purchaseProfileId;
  ShelfLifeProfile? get purchaseProfile =>
      location != 'Buzdolabı' || purchaseProfileId == 'none'
      ? null
      : ShelfLifeProfile.find(purchaseProfileId) ??
            ShelfLifeProfile.suggest(name.text, location, openingProfileId);
  DateTime? get trackingDate =>
      expiry ??
      (purchaseProfile == null
          ? null
          : addCalendarDays(purchased, purchaseProfile!.days));
  bool coldStorageConfirmed = false;
  final openingController = ExpansibleController();
  FormDraft? draft;
  bool draftReady = false, saving = false, restoringDraft = false;
  late String id;
  int? baseRevision;
  String? ownerId, saveError;
  int draftVersion = 0;
  void change(VoidCallback action) {
    setState(action);
    saveDraft();
  }

  Map<String, dynamic> snapshot() => {
    'id': id,
    'name': name.text,
    'quantity': quantity.text,
    'days': days.text,
    'purchased': dateKey(purchased),
    'expiry': expiry == null ? null : dateKey(expiry!),
    'opened': opened == null ? null : dateKey(opened!),
    'location': location,
    'profile': openingProfileId,
    'purchaseProfile': purchaseProfileId,
    'cold': coldStorageConfirmed,
    'baseRevision': baseRevision,
  };
  void saveDraft() {
    if (!draftReady || restoringDraft || saving) return;
    draft?.schedule(snapshot());
  }

  Future<void> restoreDraft() async {
    final store = draft;
    if (store == null) return;
    try {
      final saved = await store.read();
      if (!mounted) return;
      if (saved != null) {
        final restore = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Taslağına devam edelim mi?'),
            content: const Text(
              'Bu cihazda, bu kullanıcı için kaydedilmiş bir ürün taslağı var.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Yeni başla'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Taslağı yükle'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (restore == null) {
          Navigator.pop(context);
          return;
        }
        if (restore == true) {
          restoringDraft = true;
          setState(() {
            if (widget.product == null && saved['id'] is String) {
              id = saved['id'] as String;
            }
            name.text = saved['name'] as String? ?? name.text;
            quantity.text = saved['quantity'] as String? ?? quantity.text;
            days.text = saved['days'] as String? ?? '';
            purchased =
                DateTime.tryParse(saved['purchased'] as String? ?? '') ??
                purchased;
            expiry = DateTime.tryParse(saved['expiry'] as String? ?? '');
            opened = DateTime.tryParse(saved['opened'] as String? ?? '');
            location = saved['location'] as String? ?? location;
            openingProfileId = saved['profile'] as String?;
            purchaseProfileId = saved['purchaseProfile'] as String?;
            coldStorageConfirmed = saved['cold'] == true;
            baseRevision = saved['baseRevision'] as int?;
            draftVersion++;
          });
          expiryField.currentState?.didChange(expiry);
          restoringDraft = false;
        } else if (restore == false) {
          await store.reset();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => saveError =
              'Taslak okunamadı. Girdiğin bilgileri kaydederken tekrar dene.',
        );
      }
    } finally {
      if (mounted) draftReady = true;
    }
  }

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    id = p?.id ?? newMutationId();
    baseRevision = p?.localRevision;
    ownerId =
        p?.localOwnerId ??
        (widget.repository is SqliteProductRepository
            ? (widget.repository as SqliteProductRepository).ownerId
            : null);
    name = TextEditingController(text: p?.name ?? widget.initialName);
    quantity = TextEditingController(
      text: p?.quantity ?? widget.initialQuantity,
    );
    days = TextEditingController(text: p?.afterOpeningDays?.toString() ?? '');
    purchased = p?.purchasedAt ?? calendarDay(DateTime.now());
    expiry = p?.usesPurchaseEstimate == true ? null : p?.expiresAt;
    purchaseProfileId = p?.expirySource == 'unknown'
        ? 'none'
        : p?.shelfLifeProfileId;
    opened = widget.markOpened ? calendarDay(DateTime.now()) : p?.openedAt;
    location = p?.location ?? widget.initialLocation;
    openingProfileId = p?.openingProfileId;
    coldStorageConfirmed = p?.coldStorageConfirmed ?? false;
    details = opened != null || p?.afterOpeningDays != null;
    name.addListener(() {
      if (mounted && !restoringDraft) setState(() {});
    });
    if (widget.repository != null) {
      draft = FormDraft(
        widget.repository!,
        'draft:product:${widget.markOpened
            ? 'open:$id'
            : p == null
            ? 'new'
            : 'edit:$id'}',
      );
      for (final controller in [name, quantity, days]) {
        controller.addListener(saveDraft);
      }
      WidgetsBinding.instance.addObserver(this);
      WidgetsBinding.instance.addPostFrameCallback((_) => restoreDraft());
    }
  }

  @override
  void dispose() {
    draft?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    name.dispose();
    quantity.dispose();
    days.dispose();
    openingController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      saveDraft();
      unawaited(draft?.flush() ?? Future.value());
    }
  }

  Future<void> pick(String which) async {
    final today = calendarDay(DateTime.now());
    final current = switch (which) {
      'purchased' => purchased,
      'expiry' => expiry ?? today,
      _ => opened ?? today,
    };
    final last = which == 'expiry' ? DateTime(2100) : today;
    final date = await showDatePicker(
      context: context,
      initialDate: current.isAfter(last) ? last : current,
      firstDate: DateTime(2000),
      lastDate: last,
      helpText: which == 'expiry' ? 'Ambalajdaki tarihi seç' : 'Tarih seç',
    );
    if (date == null || !mounted) return;
    change(() {
      if (which == 'purchased') {
        purchased = date;
      } else if (which == 'expiry') {
        expiry = date;
        expiryField.currentState?.didChange(date);
      } else {
        opened = date;
      }
    });
  }

  Future<void> submit() async {
    if (saving) return;
    if (widget.canSave?.call() == false) {
      setState(
        () => saveError =
            'Oturum değişti. Bilgilerin taslakta korunuyor; hesabını kontrol ettikten sonra devam et.',
      );
      return;
    }
    final openingDays = int.tryParse(days.text.trim());
    if (days.text.trim().isNotEmpty &&
        (openingDays == null || openingDays < 1 || openingDays > 3650)) {
      openingController.expand();
    }
    final invalid = form.currentState!.validateGranularly();
    if (invalid.isNotEmpty) {
      Scrollable.ensureVisible(
        invalid.first.context,
        alignment: .2,
        duration: const Duration(milliseconds: 200),
      );
      return;
    }
    if (opened != null && opened!.isBefore(purchased)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Açılma tarihi alış tarihinden önce olamaz.'),
        ),
      );
      return;
    }
    final product = Product(
      id: id,
      name: name.text.trim().isEmpty ? 'Yeni ürün' : name.text.trim(),
      quantity: quantity.text.trim().isEmpty ? '1 adet' : quantity.text.trim(),
      location: location,
      purchasedAt: purchased,
      expiresAt: trackingDate,
      expirySource: expiry != null
          ? 'label'
          : trackingDate != null
          ? 'estimated'
          : 'unknown',
      shelfLifeProfileId: expiry == null ? purchaseProfile?.id : null,
      openedAt: opened,
      afterOpeningDays: int.tryParse(days.text.trim()),
      openingProfileId: openingProfileId,
      coldStorageConfirmed: coldStorageConfirmed,
      status: widget.product?.status ?? 'active',
      localRevision: baseRevision,
      localOwnerId: ownerId,
    );
    setState(() {
      saving = true;
      saveError = null;
    });
    try {
      await widget.onSave?.call(product);
      await draft?.clear();
      if (mounted) Navigator.pop(context, product);
    } catch (failure) {
      if (mounted) {
        setState(() {
          saving = false;
          saveError = failure is StaleProductEdit
              ? failure.toString()
              : 'Ürün kaydedilemedi. Bilgilerin bu ekranda korunuyor; tekrar dene.';
        });
      }
      saveDraft();
    }
  }

  Product preview() => Product(
    id: widget.product?.id ?? 'preview',
    name: name.text.trim(),
    quantity: quantity.text.trim(),
    location: location,
    purchasedAt: purchased,
    expiresAt: trackingDate,
    expirySource: expiry != null
        ? 'label'
        : trackingDate != null
        ? 'estimated'
        : 'unknown',
    shelfLifeProfileId: expiry == null ? purchaseProfile?.id : null,
    openedAt: opened,
    afterOpeningDays: int.tryParse(days.text.trim()),
    openingProfileId: openingProfileId,
    coldStorageConfirmed: coldStorageConfirmed,
  );

  Widget openingControls() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Açıldıktan sonra akıllı takip',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      const Text(
        'Gün sayısını bilmen gerekmiyor. Ürün türünü seç; süreyi biz hesaplayalım.',
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        key: ValueKey('profile:$draftVersion'),
        initialValue: OpeningProfile.find(openingProfileId)?.id ?? '',
        isExpanded: true,
        itemHeight: MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 80 : 56,
        decoration: const InputDecoration(labelText: 'Ürün türü'),
        items: [
          const DropdownMenuItem(
            value: '',
            child: Text('Diğer / tür belirtilmedi'),
          ),
          for (final profile in OpeningProfile.all)
            DropdownMenuItem(value: profile.id, child: Text(profile.label)),
        ],
        onChanged: (v) => change(() => openingProfileId = v == '' ? null : v),
      ),
      if (openingProfileId != null) ...[
        const Text(
          'Ambalajlı içme sütü için. Çiğ süt ve bitkisel içecekleri kapsamaz.',
        ),
        const SizedBox(height: 8),
        if (location == 'Buzdolabı')
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('Buzdolabında, 0–4°C’de saklıyorum'),
            subtitle: const Text('Soğuk zincirin bozulmadığı varsayılır.'),
            value: coldStorageConfirmed,
            onChanged: (v) => change(() => coldStorageConfirmed = v ?? false),
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Açılmış süt için bu saklama yerinde süre tahmini yapamıyoruz. Saklama bilgisini düzenle.',
            ),
          ),
      ],
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Ürün açıldı'),
        subtitle: const Text('Sadece açılma tarihini belirtmen yeterli.'),
        value: opened != null,
        onChanged: (v) =>
            change(() => opened = v ? calendarDay(DateTime.now()) : null),
      ),
      if (opened != null)
        dateTile('Açılma tarihi', displayDate(opened!), 'opened'),
      if (trackingDate != null || opened != null)
        ShelfLifePanel(
          product: preview(),
          now: DateTime.now(),
          showSource: true,
        ),
      const SizedBox(height: 12),
      if (openingProfileId == null)
        const Text(
          'İlk tahmin kataloğu UHT ve pastörize sütü destekler. Diğer ürünlere henüz otomatik gün atanmıyor.',
        ),
    ],
  );

  Widget section(String title, String subtitle, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      );

  Widget dateTile(String label, String value, String which, {String? error}) =>
      Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Icon(
            Icons.calendar_month_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(label),
          subtitle: Text(
            error ?? value,
            style: error == null
                ? null
                : TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => pick(which),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.markOpened
                ? 'Açılmayı kaydet'
                : widget.product == null
                ? 'Ürün ekle'
                : 'Ürünü düzenle',
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (draft != null) DraftStatusLabel(draft: draft!),
                if (saveError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      saveError!,
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                FilledButton.icon(
                  onPressed: saving ? null : submit,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Kaydet'),
                ),
              ],
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Form(
                key: form,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.markOpened) ...[
                        Text(
                          name.text,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text('${quantity.text} • $location'),
                        const SizedBox(height: 24),
                        DropdownButtonFormField<String>(
                          initialValue: location,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Açıldıktan sonraki saklama yeri',
                          ),
                          items: ['Buzdolabı', 'Kiler', 'Dondurucu']
                              .map(
                                (v) =>
                                    DropdownMenuItem(value: v, child: Text(v)),
                              )
                              .toList(),
                          onChanged: (v) => change(() {
                            location = v!;
                            coldStorageConfirmed = false;
                          }),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (!widget.markOpened) ...[
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.kitchen_outlined,
                                color: scheme.onPrimaryContainer,
                                size: 32,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                widget.product == null
                                    ? 'Mutfağına ekle.'
                                    : 'Bilgileri güncelle.',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      color: scheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Bildiğin kadarını ekle. Tarih yoksa uygun ürünler için tahmin önerelim.',
                                style: TextStyle(
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        section('Ürün bilgileri', 'Ne aldın, ne kadar aldın?', [
                          TextFormField(
                            controller: name,
                            maxLength: 100,
                            textInputAction: TextInputAction.next,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              labelText: 'Ürün adı',
                              hintText: 'Örn. Günlük süt',
                              prefixIcon: Icon(Icons.shopping_bag_outlined),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: quantity,
                            maxLength: 40,
                            decoration: const InputDecoration(
                              labelText: 'Miktar',
                              hintText: 'Örn. 1 L veya 2 paket',
                            ),
                          ),
                        ]),
                        section(
                          'Nerede saklayacaksın?',
                          'Her ürün doğru rafta.',
                          [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final entry in {
                                  'Buzdolabı': Icons.kitchen_outlined,
                                  'Kiler': Icons.shelves,
                                  'Dondurucu': Icons.ac_unit_rounded,
                                }.entries)
                                  ChoiceChip(
                                    showCheckmark: false,
                                    label: Text(entry.key),
                                    avatar: Icon(entry.value, size: 18),
                                    selected: location == entry.key,
                                    onSelected: (_) => change(() {
                                      if (location != entry.key) {
                                        coldStorageConfirmed = false;
                                      }
                                      location = entry.key;
                                    }),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        section(
                          'Tarihleri belirle',
                          'İsteğe bağlı. Ambalajdaki tarih her zaman önceliklidir.',
                          [
                            FormField<DateTime>(
                              key: expiryField,
                              initialValue: expiry,
                              builder: (field) => dateTile(
                                'Son tüketim tarihi',
                                expiry == null
                                    ? 'İsteğe bağlı • biliyorsan seç'
                                    : displayDate(expiry!),
                                'expiry',
                                error: field.errorText,
                              ),
                            ),
                            if (expiry != null)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => change(() {
                                    expiry = null;
                                    expiryField.currentState?.didChange(null);
                                  }),
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Tarihi kaldır'),
                                ),
                              ),
                            if (expiry == null) ...[
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                key: ValueKey('purchase-profile:$draftVersion'),
                                initialValue: purchaseProfileId ?? '',
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  labelText: 'Tahmin türü • isteğe bağlı',
                                ),
                                items: [
                                  const DropdownMenuItem(
                                    value: '',
                                    child: Text('Ürün adından otomatik bul'),
                                  ),
                                  const DropdownMenuItem(
                                    value: 'none',
                                    child: Text('Tarih olmadan takip et'),
                                  ),
                                  for (final profile in ShelfLifeProfile.all)
                                    DropdownMenuItem(
                                      value: profile.id,
                                      child: Text(profile.label),
                                    ),
                                ],
                                onChanged: (value) => change(
                                  () => purchaseProfileId = value == ''
                                      ? null
                                      : value,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      trackingDate == null
                                          ? 'Tarihsiz de ekleyebilirsin'
                                          : 'Tahmini takip: ${displayDate(trackingDate)}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      purchaseProfile == null
                                          ? 'Bu ürün için henüz güvenilir bir süre öneremiyoruz. Stokta tutulur; tarih bildirimi planlanmaz.'
                                          : '${purchaseProfile!.label} • alıştan itibaren ${purchaseProfile!.days} gün. Buzdolabında 0–4°C ve uygun saklama varsayımıdır; güvenlik garantisi değildir.',
                                    ),
                                    if (purchaseProfile != null)
                                      TextButton(
                                        onPressed: () => showDialog<void>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text(
                                              'Tahminin kaynağı',
                                            ),
                                            content: SelectableText(
                                              '${purchaseProfile!.source}\n${purchaseProfile!.url}\n\nSürenin ihtiyatlı başlangıcı kullanılır. Alış öncesi saklama bilinmez; ambalaj tarihini öğrendiğinde güncelleyebilirsin.',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx),
                                                child: const Text('Tamam'),
                                              ),
                                            ],
                                          ),
                                        ),
                                        child: const Text('Kaynağı gör'),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                            dateTile(
                              'Alış tarihi',
                              displayDate(purchased),
                              'purchased',
                            ),
                            if (expiry != null &&
                                expiry!.isBefore(calendarDay(DateTime.now())))
                              const Padding(
                                padding: EdgeInsets.all(8),
                                child: Text(
                                  'Seçtiğin tarih geçmiş. Ürün, tarihi geçenler arasında gösterilecek.',
                                ),
                              ),
                          ],
                        ),
                      ],
                      openingControls(),
                      const SizedBox(height: 16),
                      ExpansionTile(
                        controller: openingController,
                        maintainState: true,
                        initiallyExpanded: details,
                        tilePadding: EdgeInsets.zero,
                        leading: const Icon(Icons.inventory_2_outlined),
                        title: const Text('Ambalajda özel talimat varsa'),
                        subtitle: const Text(
                          'İsteğe bağlı • tahmin yerine ambalaj bilgisi',
                        ),
                        children: [
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: days,
                            onChanged: (_) => change(() {}),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Tüketim süresi (gün)',
                              helperText:
                                  'Örn. “Açıldıktan sonra 3 gün içinde tüketin.”',
                              helperMaxLines: 2,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return null;
                              }
                              final n = int.tryParse(v);
                              return n == null || n < 1 || n > 3650
                                  ? '1–3650 arasında gün gir.'
                                  : null;
                            },
                          ),
                          const Text(
                            'Bu alanı bilmen gerekmiyor. Doldurursan otomatik süre yerine ambalaj talimatı kullanılır; ambalaj tarihi hiçbir zaman uzatılmaz.',
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
