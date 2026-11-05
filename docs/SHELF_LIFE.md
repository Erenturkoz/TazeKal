# Açıldıktan sonra tahmini tüketim süresi

Kullanıcıdan raf ömrü bilmesi beklenmez. Ürün eklerken türünü seçer; açtığında **Bugün açtım** ile açılma tarihini kaydeder. Açılma ekranında geçmiş bir tarih de seçilebilir. Uygulama ürün kartında alıştan ve açılmadan geçen günleri, tahmini kalan tüketim süresini ve açılmamış olsaydı ambalaj tarihine kalan süreyi birlikte gösterir.

## Hesap

```
Takip tarihi = min(ambalaj tarihi, açılma tarihi + açılma tüketim süresi)
Kalan gün = takip tarihi − bugün
Açılmamış karşılaştırması = ambalaj tarihi − bugün
```

Alış tarihi üretim tarihi değildir. Ambalaj tarihi bilinmediğinde aşağıdaki sınırlı katalogla alıştan başlayan bir planlama tahmini sunulabilir; bu gerçek son kullanma tarihinin belirlenmesi veya bozulma ölçümü değildir. Uygulama fiziksel bozulmayı veya buzdolabı sıcaklığını ölçmez. Tarih eklemek zorunlu değildir.

## Ambalaj tarihi yoksa

4 Kasım 2026'da kontrol edilen kaynakların ihtiyatlı alt sınırı kullanılır. Bu kurallar yalnız Buzdolabı (0–4°C varsayımı), uygun saklama ve belirtilen ürün türü içindir. Alıştan önceki saklama süresi bilinmez. Ambalajdaki tarih öğrenilirse tahminin yerine girilmelidir; tahmin güvenli tüketim garantisi değildir.

| Tür | Alıştan itibaren planlama | Kaynak |
|---|---|---|
| Pastörize / günlük süt | 5 gün | [CSIRO](https://www.csiro.au/en/research/production/food/refrigerating-foods), evde soğuk saklama için 5–7 gün aralığının alt sınırı |
| Çiğ, kabuklu yumurta | 21 gün | [FoodSafety.gov](https://www.foodsafety.gov/food-safety-charts/cold-food-storage-charts), 3–5 haftanın alt sınırı |
| Taze, çiğ kıyma | 1 gün | Aynı FoodSafety.gov çizelgesi |
| Taze, çiğ tavuk / hindi | 1 gün | Aynı çizelge |
| Taze, çiğ balık | 1 gün | Aynı çizelge |
| Taze, çiğ parça et | 3 gün | Aynı çizelge |

Ürün adı açıkça eşleşirse öneri oluşur; tür elle de seçilebilir. Genel “süt” adı UHT/pastörize ayrımını sağlamaz ve otomatik süre verilmez. Pişmiş, çorba/salata, bitkisel süt ve belirsiz türler için rastgele süre üretilmez. Kiler ve dondurucuya bu soğuk saklama süreleri uygulanmaz. Kullanıcı **Tarih olmadan takip et** seçeneğiyle tahmini kapatabilir. Tarihi olmayan ürüne gün sayılı bildirim planlanmaz.

## İlk katalog ve kaynaklar

Kaynaklar 25 Ekim 2026'da kontrol edildi. Bunlar eğitilmiş model çıktısı veya bütün markalar için doğrulanmış bozulma süreleri değildir; açıklanabilir, ihtiyatlı takip kurallarıdır.

| Profil | Otomatik süre | Kaynak / seçim gerekçesi |
|---|---|---|
| UHT / uzun ömürlü süt | 2 gün | [Pınar](https://www.pinar.com.tr/yasam_kaliteniz/detay/Merak-Ettikleriniz/47/274/0), açılmış UHT sütü +4°C'de 2 gün içinde tüketmeyi belirtir. Bu ilk katalog bu üretici bilgisini ihtiyatlı başlangıç referansı olarak kullanır; her markanın kendi talimatı değildir. |
| Pastörize / günlük süt | 1 gün | [Çorum İl Sağlık Müdürlüğü](https://corumism.saglik.gov.tr/TR-37567/sut-ve-sut-urunlerini-tuketirken-nelere-dikkat-edilmelidir.html), buzdolabında 1–2 gün belirtir. Uygulama aralığın kısa ucunu takip eder. |

Profil kullanıcı tarafından seçilir; yalnız ürün adında “süt” geçtiği için atama yapılmaz. İlk katalog ambalajlı içme sütüne yöneliktir; çiğ süt ve bitkisel içecekler kapsam dışıdır. Marka/barkod bazında daha özel doğrulanmış talimatlar henüz yoktur.

Otomatik hesabın uygulanması için saklama yeri **Buzdolabı** olmalı ve kullanıcı **0–4°C'de, soğuk zincir bozulmadan saklama** bilgisini onaylamalıdır. Kiler/dondurucuya aynı kural uygulanmaz. Bir ürün dondurulup çözüldüyse bu akış yeterli değildir.

Kullanıcı ambalajda özel açılma talimatını görürse isteğe bağlı gün alanı otomatik süreyi değiştirir. Kullanıcı bu alanı doldurmak zorunda değildir. Ambalajın son tüketim tarihi hiçbir zaman ileri taşınmaz.

## Örnek

25 Ekim'de, 22 Ekim'de alınmış, 24 Ekim'de açılmış ve ambalaj tarihi 30 Ekim olan UHT süt, geçerli soğuk saklama bilgisiyle:

- “3 gün önce aldın • dün açtın.”
- “Tahmini 1 gün kaldı.” (İlk kataloğun 2 günlük kuralı.)
- “Açılmamış olsaydı ambalaj tarihine 5 gün kalacaktı.”

Ambalajda açıldıktan sonra 3 gün talimatı varsa aynı örneğin kalan süresi 2 gün olur. Sayılar ürünün gerçekten ne zaman bozulacağını kesin olarak söylemez.

## Desteklenmeyen durumlar

Açılmış ürünün türü desteklenmiyorsa, saklama koşulu onaylı değilse ve kullanılabilir ambalaj açılma talimatı yoksa rastgele gün üretilmez. Kartta eksik bilgi belirtilir; açılmamış ambalaj tarihi, açılmış ürünün kalan süresi gibi gösterilmez. Bu ürünlere yanıltıcı gün sayılı bildirim planlanmaz. Geçmiş ambalaj tarihi yine görünür.

## Veri ve bildirimler

SQLite v3 geçişi yalnız iki alan ekler: `opening_profile_id` ve `cold_storage_confirmed`. Eski ürünler, ambalaj talimatları ve kullanıcı sahipliği korunur. Profil kimlikleri sürümlüdür (`milk_uht_v1`, `milk_pasteurized_v1`); sonraki kaynak güncellemelerinde eski kuralın anlamı sessizce değiştirilmemelidir.

Açılma kaydı kaydedildiğinde mevcut bildirim planı yeni takip tarihine göre yenilenir. Otomatik süreye dayanan bildirimlerde “tahmini” ifadesi kullanılır. Model eğitimi, marka/barkod eşleştirmesi, sıcaklık sensörü ve cihazlar arası ürün eşitlemesi henüz yoktur.
