# Ürün ekleme ve fiş okuma

Alt gezinme alanının sağındaki sabit **Ürün ekle** düğmesi iki seçenek sunar. Büyük yazı veya dar ekranda düğme sekmelerin üzerinde tam genişlikte gösterilir; stok içeriğini örtmez.

- **Elle ürün ekle:** alanlar isteğe bağlıdır. Boş ad `Yeni ürün`, boş miktar `1 adet` olarak kaydedilir; alış tarihi bugün, saklama yeri aktif depolama sekmesi veya Buzdolabı olur. Ambalaj tarihi girilirse önceliklidir. Girilmezse desteklenen türlerde kaynaklı planlama tahmini önerilir; diğer ürünler tarihsiz tutulur. Geçmiş tarihlerle eklenenler Geçmiş → Tarihi geçenler bölümüne alınır.
- **Fişten ürün ekle:** kamera, galeri veya satır satır metin girişi. OCR sonucu düzenlenebilir metin olarak açılır. Liste hazırlandığında uygun ürünlere tahmin eklenir, diğerleri tarihsiz kalır. Satırları dışlamak ve bilgileri/tarihi düzenlemek isteğe bağlıdır. Son **Stoka ekle** onayıyla seçili ürünler tek SQLite transaction'ıyla kaydedilir.

Fişten son tüketim tarihi çıkarılmaz. Mağaza başlığı veya kampanya satırları önerilere karışabilir; ayrıştırıcı kural tabanlıdır. Yinelenen satırlar farklı ambalaj/tarih olabileceği için otomatik birleştirilmez. Miktar bulunamazsa `1 adet` önerilir ve kullanıcı düzenler.

Ürün formu ve fiş inceleme ekranı hesaba özel yerel taslak saklar. Tekrar açarken taslağı yüklemek veya yeni başlamak seçilebilir. Fişte kontrol edilmiş satırlar ve dışlanan ürünler korunur; başarılı kayıt taslağı temizler. Hata halinde form kapanmaz. Taslaklar diğer cihazlara eşitlenmez. [Veri ve eşitleme davranışı](SYNC.md).

**Açıldıktan sonra akıllı takip:** İlk katalog UHT ve pastörize süt için, tür ve soğuk saklama bilgisiyle otomatik tüketim süresi hesaplar. Kullanıcıdan gün sayısı beklenmez; yalnız açılma tarihini belirtir. Ambalajda özel talimat varsa gün alanı isteğe bağlı kullanılabilir. Ürün kartı açılmış/açılmamış tarih karşılaştırmasını gösterir. [Kurallar, kaynaklar ve sınırlar](SHELF_LIFE.md). Fiziksel bozulma ölçümü veya eğitilmiş bir model kullanılmaz.

## Teknik yapı

- Fotoğraf: `image_picker`. OCR: `google_mlkit_text_recognition`, Latin yazı modeli.
- Fotoğraf ve metin uygulamanın backend'ine yüklenmez. Kamera fotoğrafı sistemin geçici önbelleğinde kalabilir; kalıcı fiş arşivi tutulmaz.
- Android fotoğraf seçimi sırasında uygulamayı kapatırsa `retrieveLostData()` ile dönen fotoğraf ana ekranda yeniden kontrol akışına alınır. Onaysız ürün kaydedilmez.
- Kamera iptali mevcut metni korur. İzin/okuma hatasında yeniden deneme ve elle giriş açıktır. Ana uygulamada fişten çıkınca taslak saklanır; yeniden açılırken geri yükleme veya yeni başlama seçilir.
- Kayıt hatasında kontrol bilgileri korunur. Batch başka kullanıcıya ait ID ile çakışırsa tamamı geri alınır; kısmi stok kaydı oluşmaz.

## Platform ve deneme

Android emülatör güncellemesinde `mobile/run-emulator.ps1` kullanın. Gerçek fiş için **galeriden** net bir fotoğraf seçmek emülatör kamerasından daha uygundur. İlk denemede birkaç satırlık fiş kullanın; farklı fiş düzenleri ve Türkçe karakter doğruluğu cihazda ayrıca değerlendirilmelidir.

iOS minimum hedefi OCR gereği **15.5** oldu; kamera/fotoğraf izin açıklamaları ve CocoaPods yapılandırması eklendi. Windows'ta iOS doğrulanamaz; macOS/Xcode'da `flutter pub get`, `cd ios`, `pod install` ve cihaz testi gerekir.

Paket belgeleri: [OCR kurulumu](https://pub.dev/packages/google_mlkit_text_recognition/versions/0.15.1), [kamera/galeri](https://pub.dev/packages/image_picker).
