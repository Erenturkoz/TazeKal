import 'dart:async';
import 'package:flutter/material.dart';
import '../data/product_repository.dart';
import '../data/form_draft.dart';
import '../widgets/draft_status.dart';
import '../domain/product.dart';
import '../domain/receipt.dart';
import '../domain/shelf_life_profile.dart';
import '../services/receipt_scanner.dart';
import 'product_form.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({
    super.key,
    required this.scanner,
    required this.onSave,
    this.initialText,
    this.initialLocation = 'Buzdolabı',
    this.repository,
    this.canSave,
  });
  final ReceiptScanner scanner;
  final Future<void> Function(List<Product>) onSave;
  final String? initialText;
  final String initialLocation;
  final ProductRepository? repository;
  final bool Function()? canSave;
  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen>
    with WidgetsBindingObserver {
  late final TextEditingController text;
  List<ReceiptItem>? items;
  final Map<int, Product> reviewed = {};
  final Set<int> excluded = {};
  bool busy = false, saving = false, done = false;
  String? error;
  FormDraft? draft;
  bool draftReady = false;
  void saveDraft() {
    if (!draftReady || done || saving) return;
    draft?.schedule({
      'text': text.text,
      'items': items
          ?.map((i) => {'name': i.name, 'quantity': i.quantity})
          .toList(),
      'reviewed': {
        for (final entry in reviewed.entries)
          '${entry.key}': entry.value.toMap(),
      },
      'excluded': excluded.toList(),
    });
  }

  Future<void> restoreDraft() async {
    try {
      final saved = await draft?.read();
      if (!mounted) return;
      if (saved != null) {
        final restore = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Fiş taslağına devam edelim mi?'),
            content: const Text(
              'Fiş metni ve kontrol ettiğin ürünler bu cihazda saklandı.',
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
          setState(() => done = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.pop(context);
          });
          return;
        }
        if (restore) {
          final rows = saved['items'] as List?;
          final restored = <int, Product>{};
          for (final entry in (saved['reviewed'] as Map? ?? {}).entries) {
            restored[int.parse(entry.key as String)] = Product.fromMap(
              Map<String, Object?>.from(entry.value as Map),
            );
          }
          setState(() {
            text.text = saved['text'] as String? ?? '';
            items = rows
                ?.map(
                  (r) => ReceiptItem(
                    r['name'] as String,
                    quantity: r['quantity'] as String,
                  ),
                )
                .toList();
            reviewed.addAll(restored);
            excluded.addAll((saved['excluded'] as List? ?? []).cast<int>());
          });
        } else {
          await draft?.reset();
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Fiş taslağı okunamadı. Yeni bir fiş girebilirsin.',
        );
      }
    } finally {
      if (mounted) draftReady = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && draft != null) {
      unawaited(draft!.flush());
    }
  }

  @override
  void initState() {
    super.initState();
    text = TextEditingController(text: widget.initialText);
    WidgetsBinding.instance.addObserver(this);
    if (widget.repository != null) {
      draft = FormDraft(widget.repository!, 'draft:receipt');
      text.addListener(saveDraft);
      WidgetsBinding.instance.addPostFrameCallback((_) => restoreDraft());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    draft?.dispose();
    text.dispose();
    super.dispose();
  }

  Future<void> scan(ReceiptSource source) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = await widget.scanner.scan(source);
      if (!mounted) return;
      if (result != null) {
        text.text = result;
        if (result.trim().isEmpty) {
          error =
              'Yazı okunamadı. Fişi aydınlık bir yerde, düz tutarak tekrar dene veya metni gir.';
        }
      }
    } catch (_) {
      if (mounted) {
        error =
            'Fotoğraf okunamadı. Kamera/galeri iznini kontrol et, tekrar dene veya metni elle gir.';
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void prepare() {
    final parsed = parseReceipt(text.text);
    setState(() {
      if (parsed.isEmpty) {
        error = 'Ürün satırı bulunamadı. Her satıra bir ürün adı yazabilirsin.';
      } else {
        items = parsed;
        for (var i = 0; i < parsed.length; i++) {
          reviewed[i] = suggested(parsed[i]);
        }
        error = null;
      }
    });
    saveDraft();
  }

  Product suggested(ReceiptItem item) {
    final profile = ShelfLifeProfile.suggest(
      item.name,
      widget.initialLocation,
      null,
    );
    final now = calendarDay(DateTime.now());
    return Product(
      id: newMutationId(),
      name: item.name,
      quantity: item.quantity,
      location: widget.initialLocation,
      purchasedAt: now,
      expiresAt: profile == null ? null : addCalendarDays(now, profile.days),
      expirySource: profile == null ? 'unknown' : 'estimated',
      shelfLifeProfileId: profile?.id,
    );
  }

  Future<void> review(int index) async {
    final item = items![index];
    final product = await Navigator.push<Product>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductForm(
          product: reviewed[index],
          initialName: item.name,
          initialQuantity: item.quantity,
          initialLocation: widget.initialLocation,
        ),
      ),
    );
    if (product != null && mounted) {
      setState(() => reviewed[index] = product);
      saveDraft();
    }
  }

  Future<void> save() async {
    if (widget.canSave?.call() == false) {
      setState(
        () => error =
            'Hesap değişti. Bu fiş önceki hesabın taslağı olarak korunuyor.',
      );
      return;
    }
    final selected = [
      for (var i = 0; i < items!.length; i++)
        if (!excluded.contains(i)) i,
    ];
    if (selected.isEmpty) {
      return;
    }
    for (final i in selected) {
      reviewed.putIfAbsent(i, () => suggested(items![i]));
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSave([for (final i in selected) reviewed[i]!]);
      await draft?.clear();
      if (!mounted) return;
      setState(() {
        done = true;
        saving = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error =
              'Ürünler kaydedilemedi. Kontrol ettiğin bilgiler duruyor; tekrar dene.';
        });
      }
    }
  }

  Future<void> leave() async {
    if (saving || busy) return;
    if (draft != null) {
      saveDraft();
      await draft!.flush();
      if (!mounted) return;
      if (draft!.value == DraftStatus.failed) {
        setState(
          () => error =
              'Taslak saklanamadı. Bilgilerini kaybetmemek için ekranda kalıyorsun; tekrar dene.',
        );
        return;
      }
      setState(() => done = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.pop(context);
      });
      return;
    }
    if (text.text.trim().isEmpty && reviewed.isEmpty) {
      setState(() => done = true);
    } else {
      final discard = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Fişten çıkılsın mı?'),
          content: const Text(
            'Kaydedilmemiş fiş bilgileri silinecek. Stoktaki ürünlerin korunur.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Devam et'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Çık'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
      setState(() => done = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = items;
    final selected = list == null ? 0 : list.length - excluded.length;
    final ready = reviewed.keys.where((i) => !excluded.contains(i)).length;
    final locked = busy || saving;
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: done,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            list == null ? 'Fişten ürün ekle' : 'Ürünleri kontrol et',
          ),
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (draft != null) DraftStatusLabel(draft: draft!),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(error!, style: TextStyle(color: scheme.error)),
                  ),
                if (locked)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 12),
                    child: LinearProgressIndicator(),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: locked
                        ? null
                        : list == null
                        ? prepare
                        : selected > 0
                        ? save
                        : null,
                    icon: Icon(
                      list == null
                          ? Icons.playlist_add_check_rounded
                          : Icons.check_rounded,
                    ),
                    label: Text(
                      list == null
                          ? 'Ürün listesini hazırla'
                          : '$selected ürünü stoka ekle',
                    ),
                  ),
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
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    list == null
                        ? 'Bir fiş, düzenli bir mutfak.'
                        : '$ready / $selected ürün hazır',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    list == null
                        ? 'Fişi düz bir zeminde ve iyi ışıkta çek. Metni cihazında okuyup kontrolüne sunacağız.'
                        : 'Fişte ambalaj tarihi bulunmaz. Uygun ürünlere tahmin ekledik; diğerleri tarihsiz kaydedilebilir. İstersen bilgileri düzenle, ürün olmayan satırları çıkar.',
                  ),
                  const SizedBox(height: 24),
                  if (list == null) ...[
                    FilledButton.tonalIcon(
                      onPressed: locked
                          ? null
                          : () => scan(ReceiptSource.camera),
                      icon: const Icon(Icons.document_scanner_outlined),
                      label: const Text('Kamerayla fişi tara'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: locked
                          ? null
                          : () => scan(ReceiptSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galeriden fiş seç'),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: text,
                      enabled: !locked,
                      minLines: 7,
                      maxLines: 14,
                      decoration: const InputDecoration(
                        labelText: 'Fiş metni',
                        alignLabelWithHint: true,
                        hintText:
                            'Okunan metin burada görünecek.\nİstersen her satıra bir ürün yaz.',
                        helperText: 'Hatalı satırları burada düzeltebilirsin.',
                        helperMaxLines: 2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Fiş fotoğrafı ve metni sunucumuza gönderilmez. Ürünler yalnızca sen onayladığında kaydedilir.',
                    ),
                  ] else ...[
                    for (var i = 0; i < list.length; i++)
                      Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CheckboxListTile(
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text(reviewed[i]?.name ?? list[i].name),
                                subtitle: Text(
                                  excluded.contains(i)
                                      ? 'Eklenmeyecek'
                                      : reviewed.containsKey(i)
                                      ? '${reviewed[i]!.quantity} • ${reviewed[i]!.location}\n${reviewed[i]!.usesPurchaseEstimate ? 'Tahmini: ' : ''}${displayDate(reviewed[i]!.expiresAt)}'
                                      : 'Ambalaj tarihi ve ürün bilgileri bekleniyor',
                                ),
                                value: !excluded.contains(i),
                                onChanged: locked
                                    ? null
                                    : (v) => setState(() {
                                        if (v == true) {
                                          excluded.remove(i);
                                        } else {
                                          excluded.add(i);
                                        }
                                        saveDraft();
                                      }),
                              ),
                              if (!excluded.contains(i))
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: locked ? null : () => review(i),
                                    icon: Icon(
                                      reviewed.containsKey(i)
                                          ? Icons.edit_outlined
                                          : Icons.fact_check_outlined,
                                    ),
                                    label: Text(
                                      reviewed.containsKey(i)
                                          ? 'Bilgileri düzenle'
                                          : 'Kontrol et ve tarih seç',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: locked
                          ? null
                          : () async {
                              final reset = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Metne geri dönülsün mü?'),
                                  content: const Text(
                                    'Ürünler için yaptığın düzenlemeler sıfırlanır. Fiş metni korunur.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Vazgeç'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Metne dön'),
                                    ),
                                  ],
                                ),
                              );
                              if (reset == true && mounted) {
                                setState(() {
                                  items = null;
                                  reviewed.clear();
                                  excluded.clear();
                                  error = null;
                                });
                                saveDraft();
                              }
                            },
                      child: const Text('Fiş metnini yeniden düzenle'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
