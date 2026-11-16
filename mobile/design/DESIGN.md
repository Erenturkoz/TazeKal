# Taze Kal arayüz sistemi

## Yön

Sakin, bilgi öncelikli bir mutfak envanteri. Slogan, büyük karşılama başlıkları ve süs amaçlı renk blokları kullanılmaz; ekran önce sayıyı, sonra ürünü gösterir. Yeşil marka, sıcak kırık beyaz zemin, beyaz kartlar ve ince kenarlıklar. Ağdan görsel/font gerektirmeyen yerel vektör çizimi ve Material ikonları.

## Tasarım token'ları (`lib/design/taze_theme.dart`)

| Token | Değerler | Kullanım |
|---|---|---|
| `TazeSpace` | 4 / 8 / 12 / 16 / 24 / 32, ekran kenarı 20 | Tüm boşluklar. Serbest sayı yazılmaz. |
| `TazeRadius` | 10 / 14 / 20 / 28 | Rozet, düğme-alan, kart, alt sayfa. |
| Tipografi | 28 / 24 / 22 / 18 / 16 / 14 / 13 / 12 | `textTheme` üzerinden. 12'nin altı kullanılmaz; BÜYÜK HARF etiket yok. |
| `TazeStatusColors` | caution, danger (+ container), card | Tarih uyarıları. Depolama renginden bağımsızdır, her zaman metin ve ikonla birlikte. |

Düğme, alan, çip, kart, diyalog ve alt sayfa stilleri temada tanımlıdır; ekranlarda tekrar yazılmaz.

## Depolama alanları

| Alan | Ana renk | Açık yüzey |
|---|---|---|
| Tümü | #245B43 | #E8EFDF |
| Buzdolabı | #35684D | #E4EEE3 |
| Kiler | #885B24 | #F4EAD8 |
| Dondurucu | #366B85 | #E2EFF5 |

Depolama rengi yalnızca seçili depolama sekmesinde ve ürün ikonunun zemininde kullanılır. Sayfa zemini ve başlıklar renk değiştirmez. Koyu temada yüzeyler ve renklerin açıklığı ayrıca belirlenir.

## Bilgi düzeni

- Üstte küçük marka satırı, profil ve hatırlatma ayarları. Zil ikonu bildirimlerin açık/kapalı olduğunu gösterir.
- Mutfağım: tek kartta üç sayı (Stokta / Yaklaşan / Tarihsiz), depolama sekmeleri, arama, "Önce tüket" filtresi ve sıralama, ürün kartları. Miktarlar farklı birimler taşıdığı için toplanmaz; sayılar ürün kayıtlarını belirtir.
- Boş mutfakta yalnızca tek karşılama kartı: illüstrasyon, ne işe yaradığı ve "İlk ürünü ekle".
- Hatırlatmalar ve Geçmiş sekmelerinde kısa, olgusal bir başlık ve açıklama. Hatırlatmalar kapalıysa tek bir uyarı satırı.
- Ürün kartı: ad, miktar · yer, durum rozeti (kalan gün, bugün, tarihi geçti, tarih eksik ya da tarih). Ayrıntılı tarihler karta dokunulduğunda açılır. Sık kullanılan Tükettim/Bugün açtım görünür; düzenleme ve kaldırma seçenekler menüsünde.
- Boş liste ve hata durumları ikon + kısa başlık + tek cümle; tam ekran hatalar `StatusMessage` ile.
- Tek ana eylem: Ürün ekle. Giriş/profil için çalışmayan düğmeler eklenmez.

## Erişilebilirlik ve performans

En az 48 dp eylem hedefleri, açıklamalı ikonlar, doğal metin ölçekleme, büyük metinde 2 sütun depolama sekmeleri ve dikey özet, koyu/açık tema, SafeArea ve kaydırma altında kalan son ürünler için alt boşluk. Renk tek başına bilgi taşımaz. Dekoratif çizim ekran okuyucudan gizlidir. Listeler SliverList ile ihtiyaç oldukça oluşturulur. Sürekli/dekoratif animasyon yoktur.

## Önizleme

`flutter test tool/preview_test.dart` boş mutfak, dolu mutfak, Kiler, Hatırlatmalar, Geçmiş, ürün formu, koyu tema ve büyük metin görüntülerini `design/previews/` altına yazar (Git'e girmez). Veriler bellekte kalır, cihaza dokunmaz.

## Sonraki aşamalar

Kullanıcı profilleri/giriş ekranları ve Node.js + TypeScript + NestJS + PostgreSQL API bağlantısı eklendi. Hesap ekranları aynı yeşil tasarım sistemini kullanır. Ürün ekleme/OCR ve bulut ürün eşitlemesi sonraki aşamadır. Yerel ProductRepository kimlik servisinden ayrıdır; mevcut bildirimler halen cihazda planlanır, FCM sonraki aşamadır.

Bozulma tahmini için ilk tercih ambalaj bilgisi ve saklama/açılma koşullarına dayanan, kaynağı belli kural tabanı; model eğitimi için etiketli veri gereksinimi ayrıca değerlendirilir. Tahminler doğrulanmış son tüketim tarihi gibi sunulmaz.
