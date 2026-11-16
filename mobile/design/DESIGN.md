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

Tasarım kaynağı: Claude Design tuvali (Mutfağım, Boş mutfak, Hatırlatmalar, Ürün ekle, Ürün detayı, Koyu tema, İkon seti) ve `/mnt/project-files/mobile-ui/tasarim-brief.md`.

- Üst çubuk: marka ikonu, "Taze Kal" ve bugünün tarihi ("16 Kasım, Pazartesi"); profil ve zil (açık/kapalı iki ayrı ikon).
- Mutfağım: tek kartta üç sayı (Stokta / 3 gün içinde / Tarihsiz), iz üzerinde segmentli depolama sekmeleri (seçili sekme yükseltilmiş), arama ve ikon sıralama düğmesi. Liste "3 gün içinde · N" ve "Takipte · N" gruplarına ayrılır; isme göre sıralamada tek liste. Miktarlar toplanmaz.
- Ürün satırı: gıda grubu ikon karosu, ad, "miktar · yer", sağda kısa durum (ör. "1 gün / kaldı") ve yuvarlak hızlı "tükettim" düğmesi. Satıra dokununca alt sayfa açılır: durum bandı, tarih satırları, kaynak açıklaması, Tükettim / Bugün açtım / Düzenle / Kaldır.
- Hatırlatmalar: Bugün / Yarın / tarih gruplarında aynı satırlar; bildirimler kapalıysa tek uyarı satırı ve "Aç".
- Boş mutfak: üç depolama karosu, kısa açıklama, "İlk ürünü ekle" ve "Fişten ekle", altında üç ipucu satırı. İllüstrasyon yok.
- Boş liste ve hata durumları ikon + kısa başlık + tek cümle; tam ekran hatalar `StatusMessage` ile.
- Tek ana eylem: Ürün ekle.

## İkonlar (`lib/design/taze_icons.dart`, kaynak SVG'ler `design/icons/`)

24 px ızgara, 1.75 px çizgi, yuvarlak uçlar, tek renk; rengi ve boyutu `IconTheme`'den alır (`TazeIconView`). Yeni bağımlılık yok, SVG yolları küçük bir ayrıştırıcıyla çizilir.

| Grup | İkonlar | Kullanıldığı yer |
|---|---|---|
| Depolama | all, fridge, pantry, freezer | Depolama sekmeleri, boş mutfak karoları, alt menü (Mutfağım) |
| Gıda grubu | dairy, cheese, egg, meat, fish, fruit, vegetable, bread, grain, drink, canned, frozen, other | Ürün satırı ve detay karosu; `foodIconFor(ad, yer)` seçer, tanınmayan ürün yer ikonunu alır |
| Durum | soon, today, expired, noDate, consumed, opened | Alt menü (Hatırlatmalar), detay durum bandı, boş mutfak ipuçları |
| Boş durum | emptyKitchen, noResults, allGood | Arama sonucu yok, hatırlatma yok, boş liste |
| Arayüz | history, bell, bellOff, user, search, sort, check, plus, receipt, edit, brand | Alt menü, üst çubuk, arama/sıralama, hızlı tüketme, ekleme sayfası, marka |

## Erişilebilirlik ve performans

En az 48 dp eylem hedefleri, açıklamalı ikonlar, doğal metin ölçekleme, büyük metinde 2 sütun depolama sekmeleri ve dikey özet, koyu/açık tema, SafeArea ve kaydırma altında kalan son ürünler için alt boşluk. Renk tek başına bilgi taşımaz. Dekoratif ikonlar ekran okuyucudan gizlidir; hızlı tüketme düğmesi "<ürün>: tükettim" olarak okunur. Listeler SliverList ile ihtiyaç oldukça oluşturulur. Sürekli/dekoratif animasyon yoktur.

## Önizleme

`flutter test tool/preview_test.dart` boş mutfak, dolu mutfak, Kiler, Hatırlatmalar, Geçmiş, ürün formu, koyu tema ve büyük metin görüntülerini `design/previews/` altına yazar (Git'e girmez). Veriler bellekte kalır, cihaza dokunmaz.

## Sonraki aşamalar

Kullanıcı profilleri/giriş ekranları ve Node.js + TypeScript + NestJS + PostgreSQL API bağlantısı eklendi. Hesap ekranları aynı yeşil tasarım sistemini kullanır. Ürün ekleme/OCR ve bulut ürün eşitlemesi sonraki aşamadır. Yerel ProductRepository kimlik servisinden ayrıdır; mevcut bildirimler halen cihazda planlanır, FCM sonraki aşamadır.

Bozulma tahmini için ilk tercih ambalaj bilgisi ve saklama/açılma koşullarına dayanan, kaynağı belli kural tabanı; model eğitimi için etiketli veri gereksinimi ayrıca değerlendirilir. Tahminler doğrulanmış son tüketim tarihi gibi sunulmaz.
