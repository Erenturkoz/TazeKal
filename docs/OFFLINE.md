# Yükleme, hareket ve bağlantı davranışı

## Kullanıcı deneyimi

- Oturum güvenli cihaz depolamasından okunurken ve yerel stok hazırlanırken skeleton gösterilir. Gerçek veriler hazırsa yapay bir bekleme eklenmez.
- Kayıtlı kullanıcı kimliği okununca mutfak açılır; sunucuda oturum kontrolü arka planda sürer. İnternet kesilmesi veya yavaş API, cihazdaki stok ekranını engellemez. Sunucu oturumu 401 ile reddederse yerel oturum kaldırılır; önbellek sunucuda yetki sağlamaz.
- Ekran girişleri ve depolama/sekme değişimleri 220 ms'lik hafif geçiş kullanır. Bağlantı bildirimi 180 ms'de açılıp kapanır. Skeleton düşük opaklık değişimiyle yükleme durumunu belirtir. Desteklenen `disableAnimations` / erişilebilir gezinme ayarlarında özel hareketler durur.
- Bağlantı bildirimi, Wi-Fi simgesi üzerinden internet var/yok tahmini yapmaz. Gerçek hesap istekleri ve yapılandırılmış API'nin yanıtı kullanılır. Sunucunun kapalı olması da aynı hizmete erişim durumu olarak gösterilir.
- Uygulama öndeyken 30 saniyede bir hesap kontrolü yapılır; aktif bir istek varken ek kontrol başlatılmaz. Oturumsuz kullanımda yalnız `/health` okunur. Arka planda bu zamanlayıcı durur; uygulamaya dönünce yeniden kontrol edilir. Bildirimde **Tekrar dene** ile elle kontrol mümkündür.

## Neler çevrimdışı çalışır?

| İşlem | Davranış |
|---|---|
| Cihazdaki ürünleri listeleme, ekleme, düzenleme ve tüketildi işaretleme | SQLite üzerinde devam eder. |
| Açılma süresi hesabı | Yerel kurallarla devam eder. |
| Fotoğraf üzerindeki OCR | Fotoğraf cihazda erişilebiliyorsa yerel modelle çalışır. Galerideki bulut fotoğrafının indirilmesi fotoğraf sağlayıcısına bağlıdır. |
| Yerel hatırlatmalar | Cihaz izinleri ve işletim sistemi koşulları geçerliyse devam eder. |
| Yeni giriş/kayıt, Google hesabı doğrulama, profil adı değiştirme ve hesap bağlama | Hesap hizmetine erişim gerektirir. Başarılı gibi gösterilmez ve bağlantı gelince gizlice yazma yapılmaz. |
| Çıkış | Aşağıdaki iki ayrı seçenek kullanılır. |

Hesap ürünleri sunucuya eşitlenir. Çevrimdışı yazılar SQLite ile aynı transaction'da kalıcı kuyruğa alınır; uygulama öne geldiğinde ve hizmete erişilebildiğinde yeniden denenir. Misafir ürünleri otomatik yüklenmez. Çakışan cihaz değişikliklerinde kullanıcı seçim yapar. [Ayrıntılı eşitleme davranışı](SYNC.md).

## Yavaş istek ve tekrar deneme

- API çağrılarında bağlantı, yanıt başlıkları ve gövdesi için birlikte **12 saniyelik** üst sınır vardır. Refresh ve yetkili çağrı tekrarı da aynı işlem bütçesini paylaşır.
- 3 saniyeden uzun isteklerde gecikme açıklanır; düğmeler işlemi ikinci kez göndermez. Form girdileri hata sonrası korunur.
- Zaman aşımı veya kullanıcının girişten vazgeçmesi, `AbortableRequest` ile isteğin iptalini tetikler. Platform istemcisi iptali desteklemese de geç yanıt kullanıcı arayüzünde sonuç üretmez. İptal, sunucuda zaten tamamlanmış bir işlemi geri almaz.
- Sonucu belirsiz POST/PATCH çağrıları otomatik tekrarlanmaz. Kayıt zaman aşımında hesap oluşturulmuş olabileceği açıklanır ve yeniden kayıt yerine giriş denemesi önerilir.
- Hesapsız kullanıma geçiş, bekleyen girişi iptal eder; geç gelen giriş yanıtı oturum açamaz. Güvenli depolamaya başlamış bir giriş yazısı da sıraya alınmış temizleme ile kaldırılır.
- Arka plan profil yanıtı daha yeni bir profil değişikliğini ezemez. Token yenileme ve profil yazıları güvenli depolamada sıralanır; eski hesap yanıtı yeni hesaba taşınmaz.
- API kimlik bilgisi taşıyan çağrılarda otomatik HTTP yönlendirmesi yapılmaz. Yapılandırılmış HTTPS adresi kullanılmalıdır; yerel HTTP yalnız debug geliştirme adreslerinde açıktır.

Google'ın yerel hesap seçicisi işletim sistemi/Google SDK tarafından yönetilir; kullanıcının hesap seçme süresi 12 saniyelik API sınırına dahil değildir. Bu ekrandan işletim sisteminin iptal/geri eylemiyle dönülebilir.

## İki farklı çıkış

**Çıkış yap:** Sunucu oturumunu iptal etmeyi dener. Başarılı yanıt veya zaten reddedilmiş oturumdan sonra cihaz kimlik bilgileri kaldırılır.

**Yalnızca bu cihazdan çıkış yap:** Hesap hizmetine erişilemiyorsa sunulur; kullanıcı ayrı açıklamayı onaylar. Güvenli cihaz oturumu temizlenir, hesaba ait bildirim planı kaldırılır ve giriş ekranı açılır. Ürünler silinmez ve misafir hesabına taşınmaz. **Sunucudaki oturumun iptal edildiği iddia edilmez.** Uzak oturum iptal kuyruğu veya saklanmış bir refresh token bu amaçla oluşturulmaz; uzak oturum mevcut sunucu süresi/iptal kurallarıyla devam edebilir.

## Doğrulama ve kapsam

Testler, gövdesi geciken yanıtı, zaman aşımında iptali, geç yanıtların yok sayılmasını, çevrimdışı kimlik korumasını, bağlantı geri gelişini, kullanıcı izolasyonunu, güvenli depo yazı yarışlarını, çift gönderimi, yerel çıkışı, skeleton erişilebilirliğini ve büyük metin/yatay ekranı kapsar. Backend testleri sunucuda gerçek iptal/yetkilendirme davranışını ayrıca doğrular.

Windows'ta iOS derlemesi ve gerçek cihazdaki ağ kesintisi/Google hesap seçicisi yeniden doğrulanmadı. Flutter 3.41.1'deki erişilebilirlik işaretleri kullanılır; iOS Reduce Motion davranışı cihazda ayrıca değerlendirilmelidir.

Teknik başvurular: [HTTP iptal desteği](https://pub.dev/documentation/http/latest/http/AbortableRequest-class.html), [Flutter animasyon erişilebilirliği](https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html).
