# Taze Kal arayüz sistemi

## Yön

Doğal, sakin ve günlük kullanıma uygun bir mutfak envanteri. Yeşil marka, sıcak kırık beyaz zemin, okunaklı tipografi, 8 dp aralık sistemi, 16–26 dp köşe yarıçapları. Ağdan görsel/font gerektirmeyen yerel vektör çizimi ve Material ikonları.

## Depolama alanları

| Alan | Ana renk | Açık yüzey | İfade |
|---|---|---|---|
| Tümü | #245B43 | #E8EFDF | Yeşil marka / genel görünüm |
| Buzdolabı | #35684D | #E4EEE3 | Adaçayı / günlük tazelik |
| Kiler | #885B24 | #F4EAD8 | Amber / raf ve kuru gıda |
| Dondurucu | #366B85 | #E2EFF5 | Buz mavisi / saklama |

Seçilen alanda üst tazelik kartı ve depolama sekmesi renklendirilir. Ürünlerin kendi depolama renkleri korunur. Uyarılar sekme renginden bağımsız anlam taşır: tarih metni ve ikonla birlikte gösterilir. Koyu temada yüzeyler ve renklerin açıklığı ayrıca belirlenir.

## Bilgi düzeni

- Üstte marka ve bildirim ayarları; ardından mutfak özeti.
- Boş mutfakta kısa karşılama ve illüstrasyon. Ürün varken tanıtım kartı kaldırılır; sayılar ve stoklar öne geçer. Hatırlatmalar ekranında kısa tazelik şeridi bulunur.
- Gerçek kayıtlardan hesaplanan ürün, yaklaşan tarih ve kontrol sayıları. Miktarlar farklı birimler taşıdığı için toplanmaz; sayılar ürün kayıtlarını belirtir.
- Tümü/Buzdolabı/Kiler/Dondurucu sekmeleri: gerçek sayılar, etiketler ve seçili semantiği.
- Seçili alanda arama, önce tüket filtresi ve ad/tarih sıralaması.
- Ürün kartında ad, miktar, yer ve durum. Ayrıntılı tarihler karta dokunulduğunda açılır.
- Sık kullanılan Tükettim/Bugün açtım görünür; düzenleme ve kaldırma seçenekler menüsünde.
- Tek ana eylem: Ürün ekle. Giriş/profil için çalışmayan düğmeler eklenmez.

## Erişilebilirlik ve performans

En az 48 dp eylem hedefleri, açıklamalı ikonlar, doğal metin ölçekleme, büyük metinde 2 sütun depolama sekmeleri, koyu/açık tema, SafeArea ve kaydırma altında kalan son ürünler için alt boşluk. Renk tek başına bilgi taşımaz. Dekoratif çizim ekran okuyucudan gizlidir. Listeler SliverList ile ihtiyaç oldukça oluşturulur. Sürekli/dekoratif animasyon yoktur.

## Sonraki aşamalar

Kullanıcı profilleri/giriş ekranları ve Node.js + TypeScript + NestJS + PostgreSQL API bağlantısı eklendi. Hesap ekranları aynı yeşil tasarım sistemini kullanır. Ürün ekleme/OCR ve bulut ürün eşitlemesi sonraki aşamadır. Yerel ProductRepository kimlik servisinden ayrıdır; mevcut bildirimler halen cihazda planlanır, FCM sonraki aşamadır.

Bozulma tahmini için ilk tercih ambalaj bilgisi ve saklama/açılma koşullarına dayanan, kaynağı belli kural tabanı; model eğitimi için etiketli veri gereksinimi ayrıca değerlendirilir. Tahminler doğrulanmış son tüketim tarihi gibi sunulmaz.
