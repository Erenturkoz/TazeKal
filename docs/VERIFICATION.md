# Doğrulama kaydı

## 4 Kasım 2026 — isteğe bağlı tarihler ve geçmiş

- Tam Flutter paketi 67 testle geçti; sonrasında tarihsiz takip tercihinin düzenlemede tahmine çevrilmemesini kapsayan ek test ve ürün formunun 4 testi geçti. Toplam 68 farklı test başarılı. Flutter analizi temiz.
- 14 API testi ayrı gerçek PostgreSQL 17 veritabanında başarılı; yeni nullable tarih/kaynak alanları, yetkilendirme, oturum iptali, kullanıcı izolasyonu ve eşzamanlı yazma kilidi dahil. Geçici test konteyneri kaldırıldı.
- Git kuralları önbellekler, yedekler, Apple/Android yerel çıktıları, imzalama ve gizli dosyalar için genişletildi. `check-repo.mjs` temiz; gerçek yapılandırmalar, APK ve ekran görüntüleri Git dışında, lockfile'lar ve kaynak görseller kapsamda.
- x86_64 APK derlenip `run-emulator.ps1 -NoAttach` ile mevcut emülatöre `adb install -r` kullanılarak kuruldu. Oturum ve ürünler korunarak SQLite v5 açıldı. Mevcut 4 tarihi geçmiş ve 3 tüketilmiş ürün Geçmiş alt sekmelerinde ayrı sayaçlarla görüldü; ana stokta gösterilmedi. Hesap ürün eşitlemesi başarılı durumu görüldü.
- Yeni ürün formunda tarih ve tahmin türü alanlarının isteğe bağlı olduğu, tarihsiz kayıt açıklaması ve sabit Kaydet düğmesi emülatörde görsel olarak doğrulandı. Canlı incelemede test ürünü kaydedilmedi, mevcut ürünler düzenlenmedi.
- Tarih kaynakları [SHELF_LIFE.md](SHELF_LIFE.md) içinde. Model eğitimi veya fiziksel bozulma ölçümü yoktur. Gerçek fiş OCR doğruluğu, iOS ve dış sunucu/TLS bu değişiklikte yeniden denenmedi.

## 3–4 Kasım 2026 — ürün eşitleme ve Docker

- Flutter analizi temiz; 63 Flutter testi başarılı. v3→v4 geçişinde hesap/misafir ürünlerinin korunması, misafirlerin onaysız yüklenmemesi, kalıcı kuyruk, kaybolan yanıtın aynı mutation ile tekrarı, sonraki değişikliğin korunması, sürüm çakışmaları, silme kayıtları, eski form yazısının reddi ve hesap değişiminden sonraki geç yanıtlar dahil.
- Ürün ve fiş taslaklarının geri yüklenmesi; tarih doğrulaması, kontrol edilmiş/dışlanmış fiş satırları ve başarısız kayıtta formun açık kalması test edildi.
- 13 API testi gerçek PostgreSQL 17 üzerinde başarılı; yetkilendirme, oturum iptali, kullanıcılar arası izolasyon, idempotency, sürüm çakışmaları, pagination ve eşzamanlı PostgreSQL hesap kilidi dahil. Ayrı geçici test veritabanı kullanıldı.
- 3–4 Kasım: Docker imajı derlendi; ayrı `tazekal-portable-check` Compose projesi sağlıklı başladı. Migration v2 ve `/v1/health/ready` 200 doğrulandı. Geçici örnek hesapla `backup.ps1` çalıştı ve ikili dump üretildi. Docker yeniden açılınca servisler sağlıklı başladı; dump ayrı boş test veritabanına `pg_restore --exit-on-error --no-owner --no-privileges` ile yüklendi ve örnek hesap sayısı doğrulandı. Test kurulumu mevcut geliştirme volume'üne dokunmadı.
- Git kapsamı ve PowerShell yedekleme betiği sözdizimi kontrolü başarılı. Gizli yapılandırmalar ve test dump'ı Git dışında.
- 4 Kasım: x86_64 Android debug APK başarıyla derlendi; kullanıcı emülatörüne kurulmadı.
- Bu değişiklikte kullanıcı emülatörüne kurulum veya gerçek ürün verisiyle migration/eşitleme yapılmadı. İki gerçek cihaz, iOS, canlı sunucu/TLS ve e-posta teslimi doğrulanmadı. Google girişi için önceki kullanıcı doğrulaması geçerlidir; bu testler gerçek OAuth'un yeniden kontrolü değildir.

## 2 Kasım 2026 — yükleme, hareket ve bağlantı

- Flutter analizi temiz; 53 Flutter testi başarılı. Skeleton → stok geçişi, hareket azaltma, büyük metin/yatay ekran, sunucuyu beklemeden kayıtlı mutfağın açılması, yavaş istek bildirimi, çift gönderimin engellenmesi ve açık onayla cihazdan çıkış dahil.
- Android x64 debug APK derlendi, `run-emulator.ps1 -NoAttach` ile mevcut TazeKal_API36 emülatörüne veriler sıfırlanmadan kuruldu ve uygulama açıldı. Görsel kontrolde kullanıcının açık ürün formuna müdahale edilmedi; bu aşamada cihazdaki oturumdan çıkış yapılmadı.
- API testleri tek toplam zaman aşımını, yanıt gövdesi gecikmesini, iptal sinyalini, geç gelen giriş/profil yanıtının atılmasını, güvenli depoda bekleyen girişin temizlenmesini, bağlantı geri gelişini ve hesap reddini kapsıyor. Eski profil okuması yeni profil değişikliğini ezmiyor.
- Backend TypeScript derlemesi ve 7 test başarılı; sunucuda yetkilendirme, refresh rotasyonu, oturum iptali ve kullanıcı izolasyonu dahil. Testler pg-mem ile çalıştırıldı; gerçek PostgreSQL testi bu aşamada tekrar edilmedi.
- Ağ hataları ve gecikme otomatik testlerde denetimli HTTP istemcileriyle üretildi. Gerçek cihazda fiziksel ağ kesintisi, iOS ve Google'ın yerel hesap seçicisi bu aşamada yeniden doğrulanmadı.
- Kaynak/config örnekleri ve [bağlantı kılavuzu](OFFLINE.md) davranışla güncel. Ürünler cihazda; bulut eşitleme/çevrimdışı sunucu yazma kuyruğu henüz yok. Yerel çıkış, sunucu oturumunun iptali olarak gösterilmiyor. Commit, push veya yayın yapılmadı.

## 25 Ekim 2026 — açılma süresi tahmini

- Flutter analizi temiz; 36 testlik tam koşum ve ardından eklenen büyük yazı testi başarılı (toplam 37 test). Açılma ekranının büyük yazı düzeltmesinden sonra ilgili 3 etkileşim testi yeniden geçti. Gün sayısı girmeden açılma kaydı, ürün türü ve soğuk saklama seçimi, açılmış/açılmamış karşılaştırması ve otomatik bildirim tarihleri dahil.
- Android x64 APK derlendi; TazeKal_API36 emülatörüne veri sıfırlamadan kurulum ve SQLite v3 ile uygulama açılışı başarılı.
- UHT/pastörize süt için sürümlü kaynak kuralları eklendi. Özel ambalaj talimatı önceliği, ambalaj tarihinin uzatılmaması, desteklenmeyen tür/saklama koşulunda süre uydurulmaması test edildi.
- SQLite v1 → v2 → v3 geçişi ürünleri koruyor; yeni profil/saklama alanları kalıcı tutuluyor ve kullanıcı izolasyonu sürüyor.
- Fiziksel bozulma doğruluğu ölçülmedi; soğuk saklama kullanıcı beyanı. Eğitimli model veya gerçek sıcaklık sensörü yok. [Kural kaynakları ve kapsam](SHELF_LIFE.md).

## 25 Ekim 2026 — ürün ekleme ve fiş kontrolü

- Flutter analizi temiz. 26 testin tamamı ve sonrasında eklenen 3 form testi başarılı (toplam 29). Elle giriş, fiş satır ayrıştırma, satır çıkarma, zorunlu ambalaj tarihi, hata/tekrar deneme, kamera iptali, büyük metin ve açık/koyu tema dahil.
- SQLite batch testi: başka hesabın ürünüyle çakışan toplu kayıt tamamen geri alınır; önceki ürünler ve kullanıcı izolasyonu korunur.
- Google hesabıyla gerçek giriş, proje sahibinin yerel Android kurulumunda kullanıcı tarafından başarılı olarak doğrulandı. Google token doğrulaması birim testlerinde ayrıca taklit edilir.
- Git kapsam kontrolü başarılı; gerçek `.env`, yerel mobil yapılandırma ve APK/derleme klasörü Git dışında. Commit, push veya GitHub Actions çalıştırması yapılmadı.
- Android x64 APK başarıyla derlenip `run-emulator.ps1 -NoAttach` ile TazeKal_API36'ya veriler silinmeden kuruldu; uygulama açıldı.
- Yerel ML Kit OCR emülatörde galeriden sentetik fiş görseliyle doğrulandı: süt, yoğurt ve pirinç kontrol listesine geldi; fiyat, tarih ve toplam satırları kayda dönüşmedi. Deneme ürünleri stoka kaydedilmedi. OCR ilk harfi küçük okuyabildi; kullanıcı düzeltmesi açıktır.
- Otomatik etkileşim testleri sahte tarayıcı kullanır. Gerçek market fişi doğruluğu ve fiziksel kamera izinleri henüz doğrulanmadı. iOS 15.5 yapılandırması Windows'ta derlenmedi. E-posta doğrulama/parola sıfırlama gönderimi yok; ürünler cihazda hesap bazında tutulur.

## İlk hesap aşaması — tarihsel kayıt

- Flutter 3.41.1 / Dart 3.11 ile kod analizi: sorun yok.
- Flutter testleri: 21 başarılı. Mevcut stok/tarih akışları, hesap denetleyicisi, UTF-8 hata gösterimi, giriş ekranı, büyük metin ve SQLite kullanıcı izolasyonu dahil.
- Backend: TypeScript derlemesi ve 7 başarılı test. Hash/salt, kayıt/giriş, profil yetkilendirmesi, refresh token rotasyonu ve tekrar kullanım reddi, çıkışla access token iptali, Google hesap bağlama sınırı ve deneme sınırı dahil.
- Android x64 debug APK derlendi. APK Git dışında tutulur.
- Git kapsamı kontrolü başarılı; `.env`, yerel OAuth ayarları, bağımlılıklar ve derleme çıktıları yok sayılıyor. Lockfile'lar kaynak kapsamındadır.

## Doğrulama sınırları

Backend testleri bu ortamda pg-mem ile çalıştırıldı; Docker Engine kapalı olduğu için gerçek PostgreSQL burada çalıştırılmadı. CI dosyası aynı testleri ayrı PostgreSQL 17 servisinde çalıştıracak şekilde hazırlandı; GitHub'a push ve CI çalıştırması yapılmadı.

İlk aşamada Google doğrulayıcısının dış sınırı testlerde taklit edildi; o sırada Cloud istemcileri hazır olmadığı için gerçek OAuth denenmedi. Güncel kullanıcı doğrulaması yukarıda kayıtlıdır. SMTP/e-posta doğrulama ve şifre sıfırlama henüz eklenmedi.

İlk aşamada emülatör doluydu. Sonrasında ayrı TazeKal_API36 emülatörüne kurulum ve çıkış düzeltmesi başarıyla uygulandı. iOS kaynakları Windows ortamında derlenmedi. Hesap verileri PostgreSQL'de; ürünler henüz buluta eşitlenmez ve cihazda kullanıcı bazında saklanır.
