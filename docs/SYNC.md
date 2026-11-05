# Hesaba bağlı ürün eşitleme

Hesap ürünleri PostgreSQL'de tutulur; SQLite hızlı erişim ve çevrimdışı çalışma için korunur. Misafir kayıtları kendiliğinden sunucuya gönderilmez. Profilde açıkça onaylanan misafir aktarımı, ürünleri seçili hesaba taşır ve eşitleme kuyruğuna alır. Bildirim tercihleri ve form taslakları bu sürümde cihazda kalır.

## Telefon davranışı

Yerel ürün kaydı ve outbox aynı SQLite transaction'ında yazılır. İnternet gerekmez. Uygulama kapanınca kuyruk kaybolmaz. Başlatma/öndeyken hesap bağlantısının yeniden doğrulanması, yerel değişiklik veya ana ekrandaki **Eşitle** denemeyi tetikler. Arka planda sürekli ağ işlemi garantisi yoktur; uygulamaya dönüldüğünde devam eder. Gelen ürünler yerel listeyi ve bildirim planını yeniler.

Gönderilen mutation'ın kimliği ve içeriği yanıt alınana kadar sabit kalır. Yanıt kaybolursa aynı istek yinelenir; bu sırada yeni düzenlemeler ayrı kuyruk kaydında korunur. Sunucu onayından sonra yalnız onaylanan kayıt kaldırılır. Yeni düzenlemenin temel sürümü güncellenir. Tek gönderimde en fazla 50 ürün, indirmede sayfa başına 200 değişiklik kullanılır.

Her ürünün sunucu sürümü ve yerel düzenleme sayacı vardır. İki cihaz aynı sürümü düzenlerse sonraki yazı sessizce üstüne yazmaz. Ana ekranda **Farkları incele** ile kullanıcı cihazdaki veya sunucudaki sürümü seçer. Eski açık form, daha yeni ürünün üzerine yazamaz; hata formun içinde gösterilir ve taslak saklanır. Kaldırılan ürünler silme kaydı olarak eşitlenir.

## API

- `POST /v1/products/sync`: `{ "mutations": [...] }`; her kayıt `mutationId`, `productId`, `baseVersion`, `deleted`, `product` içerir. Ürün tarihleri `YYYY-MM-DD`; alanlar Flutter `Product.toMap()` biçimindedir. Yeni ürün temel sürümü 0'dır. Silmede `product=null` gönderilir.
- Yanıt `results` dizisidir; her sonuç `mutationId`, `outcome` (`applied` / `conflict`), `remote` içerir. `remote`: `id`, `version`, `cursor`, `deleted`, `product`. Çakışmada sunucuda ürün yoksa `remote=null` olabilir. Aynı mutation kimliğini farklı içerikle kullanmak 409'dur.
- `GET /v1/products/changes?after=0&limit=200`: `changes`, `cursor`, `hasMore`. Her sayfa kayıtlarla birlikte yerelde transaction içinde uygulanır. Her ürünün güncel hali gönderilir; ara sürümlerin denetim günlüğü değildir.
- Sahip kimliği JSON'dan kabul edilmez, aktif oturumdan türetilir. Aynı hesap yazıları PostgreSQL satır kilidiyle sıralanır. Oturum iptali ürün uçlarını da kapatır.

Sunucu verisi ve silme/idempotency kayıtları henüz otomatik budanmaz. Sunucu geçmişinden ileri bir cihaz cursor'u 409 alır; cihaz kayıtları otomatik sıfırlanmaz. Yedekten dönme için ayrıca operasyon planı gerekir.

## Şema ve taslaklar

API şeması v2, SQLite v5. Mobil yükseltme mevcut ürünleri sahibiyle korur; kopyalanan satır sayısı doğrulanır. v4 geçişi mevcut hesap ürünlerini kuyruğa alır; misafirleri almaz. v5 mevcut kuyruk/mutation kimliklerini ve sürümleri korur; nullable `expires_at`, `expiry_source` ve `shelf_life_profile_id` alanlarını destekler. Eski tarihli istekler yeni metadata olmadan aynı içerikle tekrarlanabilir. Geri dönüş öncesinde sürüm uyumluluğu kontrol edilmelidir.

API ürününde `expires_at=null` desteklenir. Yeni kayıtlarda `expiry_source`: `label`, `estimated`, `unknown`; tahminde desteklenen `shelf_life_profile_id` ve tarih birlikte bulunur. Eski istemci gövdelerinde bu metadata alanları isteğe bağlıdır. Mobil sürüm yükseltilmeden önce API kodunun yeni sürümü çalıştırılmalıdır.

Ürün ve fiş formları hesaba özel yerel taslak saklar. Fişte metin, seçilen satırlar ve kontrol edilmiş ürün bilgileri saklanır; fotoğraf sunucuya yüklenmez. Tekrar açarken yüklemek veya yeni başlamak seçilir. Başarılı ürün kaydından sonra taslak temizlenir; başarısız kayıtta form açık kalır. Cihaz depolaması hata verirse taslak saklandı denmez. Son 350 ms içindeki yazı, işletim sistemi işlemi aniden öldürürse kaybolabilir; normal arka plana geçişte ve ekran kapanışında yazma tamamlanmaya çalışılır.
