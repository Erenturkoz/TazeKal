import 'package:flutter/material.dart';
import '../domain/product.dart';
import '../domain/shelf_life_profile.dart';

class ShelfLifePanel extends StatelessWidget {
  const ShelfLifePanel({
    super.key,
    required this.product,
    required this.now,
    this.showSource = false,
  });
  final Product product;
  final DateTime now;
  final bool showSource;

  void source(BuildContext context) {
    final profile = product.openingProfile;
    final purchase = ShelfLifeProfile.find(product.shelfLifeProfileId);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nasıl hesaplandı?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.usesPurchaseEstimate && purchase != null) ...[
                Text(
                  'Alış tarihinden itibaren ${purchase.days} gün: ${purchase.label}. Buzdolabında 0–4°C ve uygun saklama varsayımıyla planlama tahminidir. Ambalaj tarihi bilindiğinde önceliklidir.',
                ),
                const SizedBox(height: 8),
                SelectableText('${purchase.source}\n${purchase.url}'),
                const SizedBox(height: 12),
              ],
              Text(
                product.afterOpeningDays != null
                    ? 'Ambalajdan girilen açıldıktan sonra tüketim talimatı: ${product.afterOpeningDays} gün.'
                    : profile?.explanation ??
                          'Bu ürün için doğrulanmış açılma kuralı henüz yok.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Varsa ambalaj tarihi önceliklidir. Açılma hesabı daha erken bir tarih verirse o takip edilir. Tahmin fiziksel bozulmayı ölçmez; alış tarihi üretim tarihi değildir.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Süt tahminleri, ürünün 0–4°C’de ve soğuk zincir bozulmadan saklandığı varsayımına dayanır. Uygulama sıcaklığı veya fiziksel bozulmayı ölçmez. Ambalajdaki özel talimatı esas al.',
              ),
              if (profile != null) ...[
                const SizedBox(height: 16),
                Text('Kaynak: ${profile.source}'),
                const SizedBox(height: 8),
                SelectableText(profile.url),
                const SizedBox(height: 8),
                const Text('Kural kaynak kontrolü: 25.10.2026'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final opened = product.openedAt;
    final unopened = product.unopenedDaysLeft(now);
    final unopenedText = unopened == null
        ? 'Tarih yok • stokta takip ediliyor'
        : product.usesPurchaseEstimate
        ? product.remainingText(now)
        : unopened < 0
        ? 'Ambalaj tarihi geçti'
        : unopened == 0
        ? 'Ambalaj tarihinin son günü'
        : 'Ambalaj tarihine $unopened gün';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.auto_awesome_outlined,
                size: 20,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  opened == null ? unopenedText : product.remainingText(now),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${relativeDay(product.purchasedAt, now)} aldın${opened == null ? ' • Henüz açılmadı' : ' • ${relativeDay(opened, now).toLowerCase()} açtın'}.',
          ),
          if (opened != null) ...[
            const SizedBox(height: 6),
            Text(
              unopened == null
                  ? 'Açılmamış ürün için karşılaştırılabilecek tarih eklenmedi.'
                  : product.usesPurchaseEstimate
                  ? 'Açılmamış haldeki tahmini süre: $unopened gün. Ambalaj tarihi eklenmedi.'
                  : unopened < 0
                  ? 'Açılmamış olsaydı da ambalaj tarihi geçmişti.'
                  : unopened == 0
                  ? 'Açılmamış olsaydı ambalaj tarihinin son günüydü.'
                  : 'Açılmamış olsaydı ambalaj tarihine $unopened gün kalacaktı.',
            ),
            if (!product.hasTrackingDate) ...[
              const SizedBox(height: 8),
              Text(
                product.openingProfile != null
                    ? 'Tahmin için buzdolabı ve soğuk saklama bilgisini tamamla.'
                    : 'Bu ürün türü için otomatik süre henüz yok. Süt ise türünü seç; varsa ambalaj talimatını ekle.',
              ),
            ],
          ] else if (product.openingDays != null) ...[
            const SizedBox(height: 6),
            Text(
              'Açtığında ${product.openingDays} günlük ${product.afterOpeningDays == null ? 'tahmini takip' : 'ambalaj talimatı'} başlayacak.',
            ),
          ],
          if (product.usesEstimate) ...[
            const SizedBox(height: 8),
            const Text(
              '0–4°C’de saklama varsayımı • Bozulma ölçümü değildir.',
              style: TextStyle(fontSize: 12),
            ),
          ],
          if (showSource)
            TextButton(
              onPressed: () => source(context),
              child: const Text('Nasıl hesaplandı?'),
            ),
        ],
      ),
    );
  }
}
