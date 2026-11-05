# Taze Kal mobil MVP

Android/iOS için Flutter (Dart). Kök dizindeki HTML dosyası önceki web prototipidir; mobil uygulamanın kodu bu klasördedir.

## Çalıştırma

```sh
flutter pub get
flutter run
flutter test
flutter build apk --debug
```

iOS derleme ve imzalama için macOS ve Xcode gerekir.

### x64 Android emülatöründe çalıştırma

Proje kökünden PowerShell ile `./mobile/run-emulator.ps1` çalıştırın. Betik çalışan `TazeKal_API36` emülatörünü tercih eder; tek emülatör varsa onu seçer. Gerekirse `-DeviceId emulator-5556` verin. Betik yalnız x64 mimarisini derler ve o APK'yı yükler. ARM tabanlı fiziksel telefon için kullanılmaz.

Kurulumdan önce en az 1 GB boş alan kontrol edilir. Kurulum doğrudan `adb install -r` ile yapılır; başarısız olursa betik uygulamayı kaldırmaz. Başarılı kurulumdan sonra uygulama açılır ve `flutter attach` ile hata ayıklayıcı bağlanır. `-NoAttach` yalnız kurup açar. `config/local.json` varsa derlemeye otomatik aktarılır. Betikteki hata mesajları eski Windows PowerShell sürümlerinde kodlama bozulmaması için ASCII'dir.

Normal `flutter run`, kurulum hatasında uygulamayı kaldırıp tekrar yüklemeyi deneyebilir. Veri korunması gereken emülatörlerde bu güvenli betiği kullanın. Mevcut AVD'yi sıfırlamak yerine ayrı ve daha geniş depolamalı bir AVD oluşturulabilir; bu makinedeki `TazeKal_API36` 12 GB veri bölümüyle oluşturulmuştur.

Emülatörde 537 MB boş alan varken tüm mimarileri içeren yaklaşık 149 MB debug APK `INSTALL_FAILED_INSUFFICIENT_STORAGE` hatası verdi. Yaklaşık 65 MB x64 APK aynı emülatöre veri silmeden başarıyla kuruldu. Android kurulum sırasında APK boyutunun üzerinde geçici ve açılmış dosya alanı da ister; geliştirmeye devam ederken emülatörde daha fazla boş alan bırakılması önerilir.

## Doğrulama

- Flutter analizinde sorun bulunmadı.
- 21 test geçti: tarih/açılma hesabı, hatırlatma aşamaları, ürün ekleme–açma–tüketme akışı, depolama sekmesi filtreleri, 375 px/yatay ekran, açık-koyu tema, 2 kat metin ölçeği, hesap oturumları ve SQLite kullanıcı izolasyonu.
- Android debug APK başarıyla derlendi: `build/app/outputs/flutter-apk/app-debug.apk`.
- Gerçek cihazda bildirim teslimi ve SQLite yeniden açılış kontrolü henüz yapılmadı. Arayüz testlerinde bellek deposu ve sahte bildirim servisi kullanıldı.
- iOS kaynakları yapılandırıldı; bu Windows ortamında iOS derlemesi yapılmadı.

## Arayüz yenilemesi

Yeşil marka, adaçayı buzdolabı, amber kiler ve buz mavisi dondurucu sekmeleri; gerçek stok sayıları; sade ürün kartları; ürün detay sayfası yerine açılır detay paneli; arama ve önce tüket filtresi; ad/tarih sıralaması; açık/koyu tema. Ürün ekleme iş akışı korunmuştur. Profil/giriş ekranları ve Node.js API bağlantısı eklendi; yapılandırma için `../docs/ACCOUNTS.md` dosyasını izleyin.

Tasarım kararları: `design/DESIGN.md`. Örnek verilerle üretilen ekranlar: `design/previews/`. Bunlar gerçek widget'lardan, ayrı bellek deposunda oluşturulur; kullanıcının cihaz verilerine örnek ürün eklenmez. Önizleme aracı `flutter test tool/preview_test.dart` ile çalışır.

Yeni arayüzün x64 debug ve release APK'ları derlendi. Mevcut emülatöre güncelleme denemeleri `Requested internal only, but not enough space` hatası verdi; uygulama kaldırılmadı, kayıtlar temizlenmedi. En son arayüz bu emülatöre kurulamadığı için gerçek cihaz görsel kontrolü yerine widget render kontrolü yapılmıştır.

## Bu sürüm

- Ürün ekleme/düzenleme/kaldırma, miktar, saklama yeri, alış ve ambalaj tarihi.
- Açıldıktan sonraki tüketim süresi ve açılma tarihi; erken gelen tarihle takip.
- 3/2/1 gün kala, son gün ve ertesi gün için işletim sistemine planlanan yerel bildirimler.
- Bildirim izni ve saat seçimi, cihazın saat dilimi; uygulama açılışı, devam etmesi ve değişikliklerde yeniden planlama.
- Aynı günün hatırlatmaları tek bildirimde toplanır. En yakın 60 farklı tarih planlanır; daha fazla tarih varsa arayüzde bilgi verilir. Uygulamaya tekrar girildiğinde pencere ilerler.
- Bildirim saati geçtikten sonra girilen ürün için geçmiş bildirim gönderilmez; uyarısı uygulama içinde hemen görünür. Süresi çoktan geçmiş ürünler sürekli push ile rahatsız etmez.
- Tüketilen ürün arşivi; tüketilen/kaldırılan ürünler bekleyen planlardan çıkarılır.
- SQLite kalıcı kayıt. Hesap, sunucu veya internet gerekmez. Uygulama silinirse yerel veriler kaybolabilir.

## Bildirim sınırları

Android'de yaklaşık zamanlı bildirim kullanılır; gereksiz kesin alarm yetkisi istenmez. İşletim sistemi, pil yönetimi, cihaz kapalı olması ve bildirim izni teslimi etkileyebilir. Yeniden başlatma için Android receiver yapılandırması vardır. Saat dilimi değişikliği uygulamaya yeniden girildiğinde uygulanır. İzin sonradan telefon ayarlarından kaldırılırsa uygulama içindeki tercih tek başına sistem iznini göstermez; yeniden etkinleştirme sistem iznini kontrol eder.

## Sonraki aşama: OCR

Kamera / galeriden fiş → cihazda ML Kit OCR → satırları ürünlere ayır → kullanıcıya düzenleme/onay ekranı → ürün ambalajından tüketim tarihi girişi → kayıt. OCR bir metin tanıma motorudur; fiş satırlarını ürüne ayırma ayrıca uygulanacaktır. Fişte olmayan tüketim tarihleri gerçekmiş gibi üretilmeyecek. Kamera ve OCR henüz eklenmedi; izinleri de bu sürümde istenmiyor.

## Sonraki aşama: Supabase + FCM

ProductRepository arayüzü veriyi ekranlardan ayırır. Backend tercihi Node.js/NestJS + PostgreSQL olarak güncellendi. Kimlik ve profil API'si `backend/` klasöründe; ürünler halen SQLite'ta hesap başına ayrıdır. Bulut ürün eşitlemesi, cihaz tokenları ve hatırlatma gönderim kayıtları sonraki aşamadır. Senkronizasyon kuyruğu, tombstone silme kayıtları ve çakışma stratejisi gerekir. Supabase kullanılmıyor; gerçek ortam kimlik bilgileri Git'e eklenmiyor.

Cron → Edge Function → FCM hattına geçildiğinde aynı hatırlatma için yerel/push çift gönderim önlenmeli: cihaz başına tek gönderim sahibi seçilmeli. Ürün/sürüm/hatırlatma aşaması bazında benzersiz kayıt, tekrar deneme ve geçersiz token temizliği gerekir. FCM servis hesabı ve varsa model anahtarları yalnız sunucuda tutulur. Fotoğraf saklama gerekirse kullanıcıya özel Storage erişimi ve silme politikası eklenir.

Fiziksel bozulma tespit edilmez. Sistem ambalaj bilgisi ve kullanıcının verdiği açılma süresine göre “bozulmuş olabilir” uyarısı verir.
