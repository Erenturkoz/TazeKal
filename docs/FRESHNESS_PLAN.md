# Taze Kal: açılmış ve açılmamış ürün tahmin sistemi

Araştırma ve öneri: 4 Kasım 2026. Bu bir uygulama planıdır; yeni model eğitilmedi, mevcut tahmin kodu değiştirilmedi. Ürün adı üzerinden bütün gıdalar için doğrulanmış bozulma günü hesaplanabildiği iddia edilmez.

## Önerilen karar

Önce kaynakları sürümlenen bir bilgi tabanı + deterministik karar motoru + ürün/talimat tanıma katmanı. Yeterli ve uygun gözlem birikirse öğrenen bir süre modeli ayrıca değerlendirilir. Bugün GPU veya ücretli bir büyük dil modeli servisi almak gerekmiyor.

İki ayrı çıktı üretilir:

1. **Açılmamış durum:** mevcut ambalaj koşulları ve saklama geçmişiyle kalan planlama aralığı.
2. **Açılmış durum:** açılma anı, önceki yaş ve saklama geçmişiyle güncellenmiş aralık.

Çıktılar kesin bozulma anı veya güvenli tüketim sertifikası değildir. Kaynak türü, geçerli koşullar, bilinmeyenler, kurala dayalı aralık ve varsa etiket sınırı birlikte korunur. Kaynak aralığı istatistiksel güven aralığı olarak sunulmaz; kalibrasyon olmadan yüzde güven üretilmez.

## Kaynak araştırması

| Kaynak | Kullanım | Doğrulama / sınırlama |
|---|---|---|
| [USDA FSIS FoodKeeper veri kataloğu](https://catalog.data.gov/dataset/fsis-foodkeeper-data) | Ürün türü, depolama ve ilgili başlangıç olayına göre saklama rehberlerini aday kurallara dönüştürmek | Resmî katalog JSON/XLS ve CC0 lisansı listeliyor. Katalog güncellenmesiyle dosya içeriğinin sürümü aynı şey değildir. Doğrudan JSON adresi bu araştırma ortamında 403 verdi; dosya indirilip içerik/alan kapsamı henüz doğrulanmadı. |
| [FoodKeeper açıklaması](https://www.foodsafety.gov/keep-food-safe/foodkeeper-app) | Kaynağın amacı ve kapsamı | USDA FSIS, Cornell University ve Food Marketing Institute geliştirmiş; tazelik/kalite ve saklama rehberi. Evlerde gözlenmiş bozulma deneyleri olarak kullanılamaz. |
| [EFSA açılma/çözündürme rehberi](https://efsa.onlinelibrary.wiley.com/doi/full/10.2903/j.efsa.2021.6510) | Ambalaj açılmasının etkisini ve karar dallarını tasarlamak | Açılma; bulaşma ve ambalaj atmosferi gibi etkenleri değiştirebilir. Ambalaj açılmadan geçen süre de önemlidir. Genel bir ev ürünü süre API'si değildir. |
| [Tarım ve Orman Bakanlığı etiket açıklaması](https://guvenilirgida.tarimorman.gov.tr/Haber/Detay/15400) | STT/TETT ayrımı ve Türkçe ürün akışı | STT güvenlik, TETT kalite amacı taşır; aynı bildirim ve geçmiş nedeni kullanılmamalıdır. |
| [Bakanlık raf ömrü kılavuzu duyurusu](https://www.tarimorman.gov.tr/GKGM/Duyuru/516/Gida-Etiketlerinde-Raf-Omru-Bilgisinin-Belirlenmesi-Ve-Belirtilmesi-Hakkinda-Kilavuz-Raf-Omrune-Iliskin-Brosur_afis) | Yerel uzman değerlendirmesi için rehber | Duyuru doğrulandı; tam kılavuzdan sayısal süre aktarılmadı. |
| [Open Food Facts API](https://openfoodfacts.github.io/openfoodfacts-server/api/) | Barkodla aday ürün/marka/kategori ve ambalaj bilgisi tanıma | Topluluk verisidir; alanlar eksik/yanlış olabilir. Normal ürün barkodu, kullanıcının elindeki paketin partiye özel STT'sini garantilemez. Veritabanı ODbL, görseller ayrı lisanslı; katalogla birleştirmeden önce yeniden kullanım düzeni incelenmeli. Bu aşamada ürün/görsel yüklenmedi. |
| [ComBase](https://combase.ars.usda.gov/About_ComBase.aspx), [model açıklaması](https://combase.ars.usda.gov/Predictor_Help.aspx) | İleride uzmanla mikrobiyolojik araştırma | Sıcaklık, pH, su aktivitesi gibi girdilerle mikroorganizma büyümesi/survival verileri. Evdeki tüm ürünler için hazır bozulma modeli değildir; kullanım koşulları, erişim ve hedef organizma incelenmeli. |

Kaynakların birbirinden farklı anlamları korunur. Rehberdeki azami süre, etiket talimatı ve bir deneyin mikrobiyal sonucu aynı eğitim etiketi değildir. Türkiye'deki ürünlerin ABD rehberine eşleştirilmesi otomatik onay sayılmaz.

## Bilgi tabanı

Tek kayıt `süt=7 gün` biçiminde olmayacak. Kural en az şu alanları taşıyacak:

- Sabit kural kimliği/sürümü; ürün ailesi ve alt tür; eşanlamlı Türkçe adlar.
- İşleme biçimi (UHT/pastörize/çiğ/pişmiş vb.), ambalaj ve ürün durumu.
- Açılmamış/açılmış/kesilmiş/hazırlanmış/çözündürülmüş durumu.
- Saklama yeri ve sıcaklık koşulu; nem/ışık gibi ilgili ek koşullar.
- Sürenin başlangıcı: üretim, satın alma, açılma, kesme, pişirme veya çözündürme. Bu olaylar birbirinin yerine kullanılmaz.
- Alt/üst süre ve birimi; amaç: kalite rehberi veya güvenlik sınırı; etiket tarihi/talimatına başvurma koşulu.
- Kaynak URL'si, özgün satır/alan, kontrol tarihi, lisans, uzman inceleme durumu.
- Uygulanmama koşulları ve bilinmeyen durumda çıkış davranışı.

Ürün örnekleri:

| Aile | Gerekli ayrımlar |
|---|---|
| Süt | UHT / pastörize / çiğ / bitkisel; ambalaj açılma durumu; buzdolabı geçmişi |
| Yoğurt | Sade / katkılı / ev yapımı; ambalaj ve üretici talimatı |
| Peynir | Sert / yumuşak / taze / salamuralı / dilimli; farklı peynirler tek süreye indirgenmez |
| Patates | Bütün çiğ / soyulmuş-kesilmiş / pişmiş; ışık, ortam ve saklama koşulları; 'açıldı' yerine ilgili hazırlama olayı |
| Yulaf | Kuru paket / açılmış kuru paket / ıslatılmış veya pişmiş ürün; su/süt eklendiğinde ayrı profil |

Bu tablo sayısal raf ömrü beyanı değildir. Üretici veya kategori kaynağıyla doğrulanacak ayrımların taslağıdır.

## Hesaplama ve öncelik

1. Paketin doğrulanmış STT/TETT türünü, tarihi ve saklama/açılma talimatını ayır.
2. Ürünün türünü barkod/isim/OCR ile öner; belirsiz türü kesinleştirilmiş kabul etme. İstenirse tek dokunuşla düzeltme sun.
3. Uygulanabilir üretici talimatını, yoksa incelenmiş kategori kuralını bul. Eşleşme yoksa süre verme.
4. Açılmamış ve açılmış senaryoyu aynı saklama geçmişi üzerinden ayrı hesapla. Açılma ürünün geçmiş yaşını sıfırlamaz; kalan süreyi otomatik uzatmaz.
5. Doğrulanmış STT ve geçerli açılma talimatı birlikte varsa takip tarihi bunların erken olanıyla sınırlandırılır. STT tahminle ileri alınmaz.
6. TETT için kalite hedefi ve varsa güvenlik uyarısı ayrı tutulur; TETT geçmiş olması tek başına 'bozuldu' etiketi üretmez.
7. Üretimden başlayan bir süreyi yalnız satın alma tarihiyle kalan ömre çevirmeye çalışma. Kaynak satın almadan başlayan evde saklama rehberi veriyorsa bunu o adla göster.
8. Sıcaklık geçmişi bilinmiyorsa varsayımı görünür yap. Ölçüm yokken keyfi sıcaklık katsayısı uygulama. Dondurma/çözündürme ve kesme/pişirme ayrı olaylardır; basitçe aynı sayacı yeniden başlatma.

Örnek çıktı sözleşmesi: ürün profili, durum, referans olayı/tarihi, tahmini aralık, varsa etiket sınırı, karar nedeni, kaynak/kural sürümü, varsayımlar, eksikler ve `estimated / label_based / unknown / review_required` durumu. '3–5 gün' yazıyorsa bunun onaylı kural aralığı mı, kalibre edilmiş model aralığı mı olduğu belirtilir.

## Kullanıcı deneyimi

Süre, marka, sıcaklık ve barkod girişleri zorunlu yapılmayacak. Eksik bilgiyle kayıt mümkün. Daha az bilgi, daha düşük kapsam veya tahmin verilememesi anlamına gelir. Kaydı engellemek yerine ilgili tek ek bilgi önerilir. 'Açtım', gerektiğinde 'Kestim / hazırladım / çözdürdüm' gibi olaylar tek dokunuşla kaydedilir.

Paket OCR'si fiş OCR'sinden ayrı: fiş satın alma/ürün adayını, paket görüntüsü STT/TETT ve saklama/açılma talimatını sağlar. OCR metni çıkarır; belirsiz tarih veya ürün tanımını kullanıcıya doğrulatmadan kesin güvenlik sınırı gibi kullanmaz. Bir dil modeli Türkçe ad eşleştirme ve talimat çıkarımında yardımcı olabilir; kendi başına gün sayısı uydurmaz.

## Yapılacaklar ve sorumlular

**Benim yapabileceklerim:** Kaynak envanteri; erişilebilen FoodKeeper verisinin sürüm/hash/lisans kaydı; alanları inceleyip aday kurallara dönüştürme; Türkçe kategori/eşanlam eşleştirmesi; çelişkileri ayırma; Node.js karar servisi; Flutter için sürümlü çevrimdışı kural paketi; etiket OCR'si veri şeması; sınır durum testleri. Dış kaynak ham dosyaları, gerçek ambalaj fotoğrafları ve kişisel gözlemler Git'e kendiliğinden eklenmez. İncelenmiş kurallar ve kaynak manifesti kaynak koduyla sürümlenir.

**Proje sahibinden:** Başlangıçta beş aileden yaklaşık 20–30 gerçek ürün örneği veya öncelikli marka/çeşit listesi. Her örnekte mümkünse barkod, ürünün ön yüzü, saklama/açılma talimatı, STT/TETT ve varsa üretim tarihi okunur olmalı. Her satın almada fotoğraf çekme zorunluluğu tasarlanmıyor; bu başlangıç doğrulama koleksiyonudur. İsim/fiş kişisel bilgileri gerekmez. Bir gıda mühendisi/gıda mikrobiyolojisi uzmanına erişim varsa yerel eşleştirmelerin incelenmesi. Kurum veya kişilere kullanıcı adına mesaj gönderilmeyecek.

Bu örnekler eğitim seti veya her ürün için geçerlilik kanıtı değildir. Bunlarla kaynak kuralları ve yerel ambalajlar arasındaki farkları saptayacağız. Kullanıcılardan ürünleri bilerek bozması, tatması veya bozulana kadar bekletmesi istenmeyecek.

## Aşamalar ve bitiş koşulları

1. **Veri keşfi:** FoodKeeper dosyasını gerçekten edin, alan/birim/başlangıç olaylarını ve lisansını doğrula; erişilemeyen alanlar ve eksikleri raporla. Bilinmeyen alanları sayı ile doldurma.
2. **İlk kapsam:** Süt/yoğurt/peynir/patates/yulaf alt türlerini yerel örneklerle eşleştir. Her etkin kuralın kaynağı, koşulu, başlangıcı ve inceleme durumu olsun. Uzman incelemesi bekleyen kurallar kullanıcıya otomatik süre vermesin.
3. **Karar motoru:** Açılmış/açılmamış senaryolar, STT/TETT ayrımı ve hazırlama olayları için API; Flutter'ın çevrimdışı kullandığı aynı sürümlü kurallar. Mevcut kayıtlar ve kuyruklar korunacak. Bilinen STT aşılmaması, bilinmeyene sayı verilmemesi ve açılmanın yaşı sıfırlamaması test edilecek.
4. **Pilot:** Ambalajdan doğrulanmış örneklerle eşleştirme doğruluğu, tahmin verilebilen kapsam, yanlış uzun süre önerisi, belirsizliği belirtme ve offline/sync tutarlılığı ölçülecek. Kullanıcıların etiket/olay düzeltmeleri incelenecek.
5. **Model kararı:** Veri yeterliliği ve hedef bağımsız gözlemle doğrulanabiliyorsa öğrenen model denenecek. Bugünden keyfi bir '1000 kayıt yeter' veya yüzde doğruluk sözü verilmiyor.

## Sonraki model nasıl değerlendirilecek?

Uygun hedef için tabular bir zaman-aşımı/survival modeli aday olabilir. Kategori rehberini sentetik olarak bin kez çoğaltmak gerçek eğitim verisi üretmez. 'Tükettim' olayı bozulma zamanı veya güvenlik kanıtı değildir. Son iyi gözlem ile ilk bozulma bildirimi arasındaki aralık, bilinmeyen/eksik gözlem ve ürünün takipten çıkması ayrı kayıt tipleri olmalı. Tüketicide gözlenen kalite değişimi, laboratuvarla doğrulanmış patojen sonucuyla karıştırılmamalı.

Öğrenen model için ürün/parti, işlem/ambalaj, olaylar, uygun sıcaklık geçmişi ve güvenilir hedef etiket gerekir. Veri toplama isteğe bağlı ve amaçla sınırlı planlanır. Değerlendirme zaman, ev/parti ve gerektiğinde marka ayrımıyla veri sızıntısını önler. Kural motoruna göre fayda, aralık kalibrasyonu, grup bazında kapsama ve özellikle yanlış uzun süre tahmini raporlanır. Model varsayılanları/etiket güvenlik sınırlarını kaldıramaz; veri dışı durumlarda çekimser kalır. Gerçek güvenlik modeli için uzman ve uygun deney/laboratuvar çalışması gerekir; kullanıcı fotoğrafı/kokusu tek başına bunun yerine geçmez.

## Mevcut uygulamaya etkisi

Bugün iki açılma ve altı alış-sonrası profil var. Bunları birden tüm ürünler için genelleştirmeyeceğiz. Yeni sistem önce kategori ayrımlarını, etiket tarihinin türünü ve kaynaklı kural sözleşmesini genişletecek. Bu plan aşamasında ürün verisi, hesaplar, emülatör ve çalışan uygulama değiştirilmedi; model/API servisi dışarıya yayımlanmadı.
