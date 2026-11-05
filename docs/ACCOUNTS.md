# Mobil hesap kurulumu

## E-posta ve şifre

Önce `backend/README.md` ile PostgreSQL'i ve API'yi başlatın. Ardından proje kökünden:

```powershell
Copy-Item mobile/config/development.example.json mobile/config/local.json
cd mobile
flutter pub get
.\run-emulator.ps1
```

`config/local.json` Git'e girmez. API adresi bir gizli anahtar değildir; örnek dosyalar bunun biçimini gösterir. Üretim derlemelerinde `API_BASE_URL` varsayılan olarak boş bırakılır ve hesap çağrıları kapalı kalır; gerçek HTTPS adresi yapılandırılmalıdır. Yerel HTTP yalnız debug modunda localhost/127.0.0.1/Android emülatör hostunda kabul edilir.

Betik yerel yapılandırmayı otomatik kullanır, en az 1 GB emülatör boş alanını kontrol eder ve başarısız kurulumda uygulamayı kaldırmaz. Varsayılan olarak çalışan `TazeKal_API36` AVD'sini seçer; gerekirse `-DeviceId emulator-5556` belirtin.

Kayıt, giriş, profil adı düzenleme ve çıkış eklendi. Ana ekranın sağ üstündeki profil simgesi hesabı açar; profil ekranının sabit alt bölümündeki **Çıkış yap** düğmesi kaydırmadan erişilebilir. Başarılı çıkış giriş ekranına döndürür ve cihazdaki ürünleri korur. Hesapsız kullanım korunur. Token'lar Keychain/Android güvenli depolama ile tek oturum kaydı olarak tutulur. Şifre cihazda saklanmaz. 401 yanıtında bir ortak refresh çağrısı yapılır; reddedilirse yerel oturum kaldırılır. Bağlantı kesildiğinde önceden kaydedilmiş kimlikle cihazdaki ürünlere erişim devam eder; bu, sunucuda yeni yetki vermez.

## Bağlantı ve çıkış

Kayıtlı cihaz kimliği okununca mutfak sunucuyu beklemeden açılır; oturum arka planda doğrulanır. Normal **Çıkış yap** sunucu oturumunu iptal eder. Hizmete erişilemiyorsa açıklama/onayla **Yalnızca bu cihazdan çıkış yap** sunulur; ürünler korunur, bu seçenek uzak oturumu iptal etmiş sayılmaz. API istekleri toplam 12 saniye ile sınırlıdır; başarısız profil/kayıt yazıları kendiliğinden tekrar gönderilmez. [Ayrıntılı bağlantı davranışı](OFFLINE.md).

## Google Android

Proje sahibi, yerel Android kurulumunda Google hesabıyla girişin çalıştığını 25 Ekim 2026'da doğruladı. Bu doğrulama diğer geliştiricilerin istemci/imza yapılandırmasının yerine geçmez.

1. [Google Cloud kimlik bilgileri](https://console.cloud.google.com/apis/credentials) sayfasında bir proje oluşturun/seçin. OAuth consent ekranını ve test kullanıcılarını yapılandırın.
2. Bir **Android** OAuth istemcisi oluşturun. Paket adı `com.tazekal.taze_kal`. Android Studio'nun Gradle `signingReport` göreviyle geliştirme imzasının SHA-1 değerini bulun ve istemciye kaydedin. Debug ve dağıtım imzaları farklı olabilir; her imza için eşleme gerekir.
3. Aynı projede bir **Web application** OAuth istemcisi oluşturun. Android istemci kimliğini değil, Web istemci kimliğini sunucu kitlesi için kullanıyoruz.
4. Web OAuth istemcisi kimliğini `local.json` içindeki `GOOGLE_WEB_CLIENT_ID` alanına ve API `.env` içindeki `GOOGLE_CLIENT_IDS` alanına yazın. Client secret değerini uygulamaya eklemeyin; bu ID token akışı onu istemez.
5. API'yi yeniden başlatıp uygulamayı tekrar derleyin. Kullanıcının Google hesabından alınan ID token API tarafından doğrulanır.

Bu proje `google-services.json` kullanmadan `serverClientId` ile yapılandırılır. Resmî [Android paket kılavuzu](https://pub.dev/packages/google_sign_in_android) ve [iOS paket kılavuzu](https://pub.dev/packages/google_sign_in_ios) platform ayarlarını açıklar. OAuth ekranı test modundaysa deneyeceğiniz Google hesabını test kullanıcısı olarak ekleyin.

## Google iOS

Google Cloud'da bundle ID `com.tazekal.tazeKal` / Xcode projesindeki gerçek `PRODUCT_BUNDLE_IDENTIFIER` ile eşleşen iOS istemcisi kullanın; proje kimliğini Xcode'dan kontrol edin. `GOOGLE_IOS_CLIENT_ID` alanını yapılandırın. `mobile/ios/Flutter/Google.example.xcconfig` dosyasını `Google.local.xcconfig` olarak kopyalayın ve ters istemci kimliğini yazın. Debug ve Release xcconfig dosyaları bu yerel dosyayı isteğe bağlı içerir; Info.plist dönüş URL şemasını buradan alır. Gerçek kimlikleri `.example` dosyasına yazmayın. iOS derleme ve Google oturumu macOS/Xcode ile ayrıca doğrulanmalıdır.

## Mevcut ürünler

SQLite v1 kayıtları v2 geçişinde silinmez; `guest` sahibine atanır. v4 geçişi mevcut sahipleri ve ürünleri korur; hesap ürünlerini eşitleme kuyruğuna alır. Her hesap ürün ve hatırlatma tercihlerini ayrı görür. Eski misafir ürünleri otomatik olarak hesaba alınmaz. Profilim → Misafir ürünlerimi taşı, onaydan sonra kayıtları seçili hesaba taşır ve sunucuya eşitleme kuyruğuna alır. Hesap değişirken önce eski bildirim planı iptal edilir, sonra yeni hesabın planı kurulur. [Eşitleme ayrıntıları](SYNC.md).

## Sınırlar

API veya Google yapılandırılmadığında gerçek hesap girişi çalışmaz; uygulama bunu hata mesajıyla belirtir ve hesapsız kullanım sunar. Bu sürümde e-posta doğrulama mesajı ve şifre sıfırlama e-postası gönderilmez. Google akışı yapılandırmasız veya sahte bir yerel oturumla başarılı gösterilmez.
