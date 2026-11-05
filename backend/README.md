# Taze Kal API

Node.js 24 LTS, TypeScript, NestJS ve PostgreSQL. Bu klasör canlı bir sunucuya yayımlanmamıştır.

## Yerel kurulum

Docker Desktop/Engine çalışır durumda olmalı. PowerShell'de bu klasörden:

```powershell
Copy-Item .env.example .env
npm ci
node -e "console.log(require('node:crypto').randomBytes(48).toString('base64url'))"
```

Üretilen değeri `.env` içindeki `JWT_SECRET` olarak yazın. `POSTGRES_PASSWORD` ve `DATABASE_URL` aynı yerel parolayı kullanmalı; örnek değerler yalnız yerel geliştirme içindir. Gerçek dosya Git tarafından yok sayılır. Ardından:

Docker PostgreSQL varsayılan olarak bilgisayarın `15432` portuna açılır; konteyner içinde `5432` kullanılır. Böylece bilgisayarda zaten çalışan PostgreSQL'in `5432` portuyla çakışmaz. `.env` içindeki `POSTGRES_PORT` ile `DATABASE_URL` portu aynı olmalıdır.

```powershell
docker compose up -d db
npm run migrate
npm run dev
```

API `http://localhost:3000/v1` adresinde çalışır. Android emülatörü aynı sunucuya `http://10.0.2.2:3000/v1` ile ulaşır. `/v1/health` yalnız uygulamanın ayakta olduğunu belirtir; veritabanı sağlık kontrolü değildir.

`/v1/health/ready` veritabanı bağlantısını ve şema v2'yi kontrol eder; hazır değilse 503 döner. Yeni ürün API'si için mevcut geliştirme veritabanında `npm run migrate` çalıştırılmalıdır; kayıtlar korunur. API + PostgreSQL'i terminalden bağımsız başlatmak için [taşınabilir Docker kurulumu](../docs/DOCKER.md) kullanılabilir. Bu kurulum ayrı veri alanıdır; geliştirme verilerini otomatik taşımaz.

`npm run dev` terminali açık kaldığı sürece API çalışır; terminal kapanırsa bu adres de kapanır. Yeniden açarken yalnız `docker compose up -d db` ve `npm run dev` yeterlidir; `.env` dosyasını yeniden kopyalamayın. Docker Desktop'taki `backend` grubu şu an yalnız veritabanını içerir, Node API'yi başlatmaz.

Üretimde `npm run build` ve `npm start`; HTTPS reverse proxy, güvenilir origin listesi ve özel PostgreSQL bağlantısı gerekir. Proxy arkasında istemci IP yapılandırması ayrıca yapılmalı. Şu anki deneme sınırı süreç belleğindedir; birden fazla API örneğine geçerken ortak rate-limit deposu gerekir. Gizli bilgiler dağıtım ortamından verilir.

## HTTP sözleşmesi

Tüm gövdeler JSON. Korumalı çağrılarda `Authorization: Bearer <accessToken>`.

| Metot / yol | Gövde | Sonuç |
|---|---|---|
| POST `/auth/register` | `email`, `password`, `displayName` | Oturum + profil |
| POST `/auth/login` | `email`, `password` | Oturum + profil |
| POST `/auth/google` | `idToken` | Oturum + profil |
| POST `/auth/refresh` | `refreshToken` | Yenilenmiş iki token + profil |
| POST `/auth/logout` | — | Mevcut oturum iptal, 204 |
| POST `/auth/google/link` | `idToken` | Giriş yapılan profile aynı e-postalı Google hesabını bağlar |
| GET `/users/me` | — | Kendi profilin |
| PATCH `/users/me` | `displayName` | Güncel profil |
| POST `/products/sync` | `mutations` | Onaylar ve sürüm çakışmaları |
| GET `/products/changes?after=0&limit=200` | — | Hesabın değişen ürünleri ve cursor |

Ürün alanları ve kuyruk kuralları: [eşitleme sözleşmesi](../docs/SYNC.md).

Ürün tarihi isteğe bağlıdır (`expires_at=null`). Yeni ürünlerde `expiry_source` (`label`, `estimated`, `unknown`) ve isteğe bağlı `shelf_life_profile_id` tahminin kaynağını korur. Eski istemcilerin metadata içermeyen tarihli ürünleri ve mutation tekrarları desteklenir. Alanlar JSON ürün gövdesinde tutulduğundan API PostgreSQL şema sürümü v2 olarak kalır.

Access token 15 dakika; refresh token 30 günlük mutlak oturum ömrü içinde döndürülür. Yenileme ömrü her kullanımda sınırsız uzatılmaz. Eski refresh token yeniden kullanılamaz. Çıkış sunucuda oturumu iptal ettiği için mevcut access token da geçersizleşir. Sunucu oturumunun iptalini doğrulamak için API erişimi gerekir. Mobilde bağlantı yokken ayrı onayla yalnız cihaz oturumu kaldırılabilir; bu işlem sunucudaki oturumu iptal etmez. [Mobil bağlantı ve çıkış davranışı](../docs/OFFLINE.md).

Şifreler scrypt (N=32768, r=8, p=3), ayrı rastgele salt ve 64 bayt çıktı ile hash'lenir. Refresh token'ın yalnız SHA-256 özeti tutulur. Kullanıcı girdileri allowlist ile doğrulanır; profil sahibini gövdeden değil doğrulanmış oturumdan alır. SQL sorguları parametrelidir. Yanıtlara şifre hash'i veya Google subject eklenmez.

## Google

Google Cloud'da uygulamaya ait Android, Web ve gerekiyorsa iOS OAuth istemcileri oluşturun. Android istemcisinde `com.tazekal.taze_kal` paket adı ile geliştirme/dağıtım imzalarının SHA-1/SHA-256 parmak izlerini tanımlayın. Mobilde alınan **ID token** sunucuya gönderilir; kullanıcı kimliği metnine güvenilmez.

`.env` içindeki `GOOGLE_CLIENT_IDS`, mobilde `serverClientId` olarak kullanılan Web istemci kimliklerini içerir. Sunucu Google kütüphanesiyle imza, süre, issuer ve audience doğrulaması yapar; doğrulanmış e-posta ister. Boşsa Google girişi 503 döner. OAuth client secret bu akışta mobil uygulamaya konmaz.

Aynı e-postalı yerel hesap Google ile otomatik birleştirilmez. Kullanıcı önce mevcut hesabına giriş yapar, sonra Profilim ekranından aynı e-postalı Google hesabını bağlar.

## Henüz tamamlanmayan hesap servisleri

E-posta/şifre kaydında `emailVerified=false`. SMTP sağlayıcısı ve doğrulama/şifre sıfırlama akışı henüz yoktur; doğrulanmış gibi gösterilmez. Google hesabı doğrulanmış e-posta sağlar. Üretim yayını öncesinde e-posta doğrulama, parola sıfırlama, hesap/veri silme ve operasyonel izleme ayrıca tamamlanmalıdır.

API kimlik, profil ve hesaba özel ürünleri saklar. SQLite çevrimdışı erişim ve kalıcı kuyruk için korunur; ürünler sürüm kontrollü olarak PostgreSQL'e eşitlenir.

## Testler

```powershell
npm test
```

Yerelde Docker zorunlu olmadan pg-mem SQL adaptörü kullanılır. Gerçek PostgreSQL üzerinde aynı HTTP testlerini çalıştırmak için yalnız **ayrı bir test veritabanı** adresini `TEST_DATABASE_URL` olarak verin. Her test ayrı geçici schema oluşturur ve yalnız o schema'yı kaldırır. GitHub CI bunu PostgreSQL 17 servisiyle çalıştırır; bu workflow henüz GitHub'da çalıştırılmadı.

Google testlerinde kimlik doğrulama sınırı taklit edilir; gerçek Google OAuth oturumunun doğrulanması için proje yapılandırması gerekir.
