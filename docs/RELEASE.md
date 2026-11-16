# Yayın öncesi durum

Tam sürüme geçişin veri altyapısı: hesap ürün API'si, kalıcı çevrimdışı kuyruk, sürüm çakışmaları, yerel taslaklar ve taşınabilir Docker kurulumu eklendi. Bu kayıt uygulamanın mağazada yayımlandığı veya tüm yayın koşullarının sağlandığı anlamına gelmez.

## Tamamlanacak işler

- E-posta doğrulama ve şifre sıfırlama akışları. Uygulama içi hesap silme (Apple 5.1.1(v)) ve kayıtta koşul onayı eklendi. E-posta sağlayıcısı ve alan adı henüz seçilmedi; bugün e-posta gönderildiği iddia edilmez.
- Canlı sunucu, HTTPS, izleme, dış yedek ve geri yükleme tatbikatı; Docker volume'ü başka makineye kendiliğinden aktarılmaz.
- Android dağıtım imzası ve Google OAuth üretim imza eşlemesi; iOS derleme, Google girişi ve bildirim kontrolleri macOS/gerçek cihazda.
- Kullanım Koşulları ve Gizlilik Politikası uygulamada **taslak** olarak var (`mobile/lib/legal/legal_texts.dart`); köşeli parantezli alanlar (şirket adı, adres, iletişim e-postası, barındırma ülkesi, yedek saklama süresi) doldurulmalı ve metin hukuken incelenmeli. Mağazalar için gizlilik politikasının herkese açık bir web adresi de gerekir. Mağaza veri beyanları ve yayın içerikleri proje sahibiyle tamamlanacak.
- İki gerçek cihazla çevrimdışı düzenleme/yeniden bağlanma ve uygulama güncellemesi; yeni SQLite geçişi testlerde veri korunarak doğrulanır, gerçek kullanıcı cihazı ayrıca denenir.
- Farklı gerçek market fişleriyle OCR doğruluğu. Açılma tahmini şu anda yalnız kaynaklı UHT/pastörize süt kurallarını kapsar; fiziksel bozulmayı tespit eden eğitilmiş model yoktur.

## Kontroller

`node tools/check-repo.mjs`, Flutter analiz/testleri, PostgreSQL üzerinde API testleri ve Docker hazırlık kontrolü çalıştırılır. GitHub'a push ve yayınlama proje sahibine aittir. Güncel yerel sonuçlar [doğrulama kaydında](VERIFICATION.md) tutulur.
