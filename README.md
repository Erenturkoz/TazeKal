# Taze Kal

Flutter ile Android/iOS için mutfak envanteri ve tüketim tarihi takibi. Node.js/TypeScript API kullanıcı hesaplarını, profilleri ve ürün eşitlemesini yönetir.

| Klasör | İçerik |
|---|---|
| `mobile/` | Flutter uygulaması, SQLite, yerel bildirimler, giriş ve profil ekranları |
| `backend/` | NestJS API, PostgreSQL şeması, e-posta/şifre ve Google ID token girişi |
| `docs/ACCOUNTS.md` | Mobil/API ve Google OAuth kurulumu |
| `.github/workflows/` | Yayınlama yapmayan kod/test kontrolleri |
| `tools/` | Git kapsamı kontrolü |

## Başlangıç

1. [API kurulumunu](backend/README.md) izleyin; yerel PostgreSQL ve sunucuyu başlatın.
2. [Mobil hesap kurulumunu](docs/ACCOUNTS.md) izleyin. Google için kendi OAuth istemcilerinizi yapılandırın.
3. Android x64 emülatöründe `mobile/` klasöründen `.\run-emulator.ps1` çalıştırın. Betik kurulum başarısızlığında uygulamayı kaldırmaz. iOS için macOS/Xcode ve `flutter run` kullanılır. Hesapsız kullanım için backend gerekmez.

## Mevcut durum

- Ürün ekleme/düzenleme, depolama sekmeleri, tüketim/açılma süresi takibi ve yerel bildirimler.
- Elle giriş veya kamera/galeri OCR ile fişten ürün önerileri; isteğe bağlı alanlar, kaynaklı alış sonrası tahminler ve tarihsiz stok kaydı. Ambalaj tarihi biliniyorsa önceliklidir. [Ürün ekleme kılavuzu](docs/PRODUCT_ENTRY.md).
- UHT/pastörize süt için kaynaklı açılma süresi tahmini; gün sayısını kullanıcı girmeden takip, açılmış/açılmamış tarih karşılaştırması. [Hesaplama ve sınırlar](docs/SHELF_LIFE.md).
- E-posta/şifre kayıt ve giriş; Google girişi için sunucuda ID token doğrulaması ve güvenli hesap bağlama.
- Güvenli cihaz oturumu, dönen refresh token, sunucuda çıkış, profil adı düzenleme.
- Skeleton yükleme ve hafif geçişler; kayıtlı mutfağa sunucu beklemeden erişim, sınırlı istek süresi, bağlantı durumu/tekrar deneme ve açıklamalı cihazdan çıkış. [Çevrimdışı davranış](docs/OFFLINE.md).
- Kullanıcıya ayrılmış yerel ürün alanları; onayla misafir ürünlerini taşıma.
- Ana stoktan ayrılmış Geçmiş → Tarihi geçenler / Tüketilenler; tarihi geçenler için küçük sekme sayacı.
- Hesaba bağlı PostgreSQL ürünleri, kalıcı çevrimdışı değişiklik kuyruğu, sürüm çakışmalarını inceleyerek çözme ve ürün/fiş taslakları. [Eşitleme sözleşmesi](docs/SYNC.md).
- API ve PostgreSQL için [taşınabilir Docker kurulumu](docs/DOCKER.md), otomatik migration ve veritabanı hazırlık kontrolü.
- **E-posta doğrulama gönderimi, parola sıfırlama ve hesap silme henüz eklenmedi.** [Yayın öncesi kalan işler](docs/RELEASE.md). Google girişi, proje sahibinin yerel Android kurulumunda 25 Ekim 2026'da kullanıcı tarafından doğrulandı; her geliştirici kendi istemci/imza yapılandırmasını yapmalıdır. Gerçek fiş OCR doğruluğu ayrıca cihazda denenmelidir.

## Geliştirme kontrolleri

```sh
node tools/check-repo.mjs
cd backend
npm ci
npm test
cd ../mobile
flutter pub get
flutter analyze
flutter test
```

Gerçek PostgreSQL testleri için `TEST_DATABASE_URL` tanımlayın; aksi halde SQL test adaptörü kullanılır. CI, PostgreSQL servisi ve Flutter kontrollerini çalıştıracak şekilde hazırlanmıştır; bu çalışma sırasında GitHub'a bağlanılmadı.

## Sürüm kontrolü

İlk commit, uzak depo bağlantısı ve sonraki push adımları: [GitHub kılavuzu](docs/GITHUB.md).

Kaynak kodu, migration şeması ve lockfile'lar Git'e uygundur. `.env`, yerel Google/API yapılandırmaları, imzalama anahtarları, kullanıcı verileri, bağımlılıklar ve APK çıktıları yok sayılır. Örnek dosyaları kopyalayıp gerçek değerleri yerel kopyalara yazın. [Katkı kuralları](CONTRIBUTING.md) ve [çalışma anlaşması](AGENTS.md) sonraki değişikliklerde de geçerlidir.

Lisans sahibi tarafından henüz seçilmedi. Commit, push ve yayınlama proje sahibinin kontrolündedir; eklenen CI yalnızca kontrol/test yapar.

## Eski web prototipi

Türkçe mutfak envanteri uygulamasının yerel ilk sürümü. `index.html` dosyasını tarayıcıda açın. Veriler tarayıcının localStorage alanındadır; tarayıcı verilerini temizlemek kayıtları siler. Örnek ürünler yalnızca kullanıcı yüklediğinde eklenir.

### Prototip özellikleri

- Tek tek ürün ekleme; miktar, alış ve son tüketim tarihi, saklama yeri.
- Fiş metninden satır satır ürün listesi hazırlama; ambalajdaki tarihleri kontrol ettikten sonra toplu kayıt.
- Açılma tarihi ve ambalajda belirtilen açıldıktan sonra tüketim süresi.
- İki tarihten önce gelenine göre 3, 2, 1 gün kala, son gün ve süre geçtiğinde uyarı.
- İzin verilirse uygulama açıkken tarayıcı bildirimi; ürün başına günde bir kez. Uygulama kapalıyken çalışmaz. Tarayıcı desteği, güvenli bağlam ve işletim sistemi izinleri gerekir; uygulama içi hatırlatmalar her zaman görünür.
- Arama, saklama yeri filtresi, tarih/ad sıralaması, tüketildi kaydı, kaldırma.

### Prototip sınırları

Fotoğraf/fiş OCR, hesap ve cihazlar arası senkronizasyon, uygulama kapalıyken zamanlanmış push için sunucu ve mobil bildirim altyapısı gerekir. Bu sürüm yapay zekâ ile fiziksel bozulma tespiti yapmaz; tarih ve kullanıcıdan alınan ambalaj bilgisiyle olasılık uyarısı üretir. Alış tarihinden otomatik raf ömrü tahmin edilmez.

### Prototip kontrolü

`node logic.test.js` ile tarih ve açılma süresi hesaplarını doğrulayın.
