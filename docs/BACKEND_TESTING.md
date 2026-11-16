# Backend testleri ve elle doğrulama

Bu sayfa API'nin otomatik testlerini çalıştırmayı ve güvenlik davranışlarını elle denemeyi anlatır. Komutlar PowerShell içindir; macOS/Linux'ta `curl.exe` yerine `curl` yazın.

## 1. Otomatik testler

```powershell
cd backend
npm ci
npm test                     # pg-mem ile, Docker gerekmez
```

Gerçek PostgreSQL ile (CI ile aynı, paralel yazma ve rollback testleri yalnız burada tam çalışır):

```powershell
docker compose up -d db
# Ayrı bir test veritabanı oluşturun; geliştirme veritabanınızı TEST_DATABASE_URL olarak vermeyin.
docker compose exec db createdb -U tazekal tazekal_test
$env:TEST_DATABASE_URL = "postgresql://tazekal:<POSTGRES_PASSWORD>@localhost:15432/tazekal_test"
npm test
Remove-Item Env:TEST_DATABASE_URL
```

Beklenen: `# fail 0`. pg-mem modunda 1 test (paralel kilit) atlanır; gerçek PostgreSQL'de hiçbiri atlanmaz.

## 2. API'yi elle deneme

`docker compose up -d db`, `npm run migrate`, `npm run dev` ile API'yi başlatın. Kolaylık için:

```powershell
$api = "http://localhost:3000/v1"
function Post($path, $body, $token) {
  $h = @{ "Content-Type" = "application/json" }; if ($token) { $h.Authorization = "Bearer $token" }
  try { Invoke-RestMethod -Method Post -Uri "$api$path" -Headers $h -Body ($body | ConvertTo-Json) }
  catch { "HTTP $($_.Exception.Response.StatusCode.value__)" }
}
```

| # | Adım | Beklenen |
|---|---|---|
| 1 | `$s = Post "/auth/register" @{ email="deneme@example.com"; password="cok-guclu-sifre"; displayName="Eren" }` | `accessToken`, `refreshToken`, `user` döner |
| 2 | `$t = Post "/auth/login" @{ email="deneme@example.com"; password="cok-guclu-sifre" }` (ikinci cihaz) | Yeni oturum |
| 3 | Aynı login'i yanlış şifreyle 6 kez hızlıca deneyin | İlk 5'i `HTTP 401`, 6.'sı `HTTP 429` |
| 4 | `$n = Post "/auth/refresh" @{ refreshToken=$s.refreshToken }` | Yeni token çifti |
| 5 | Aynı **eski** `$s.refreshToken` ile tekrar refresh | `HTTP 401` ve `$n.accessToken` ile `GET /users/me` artık `401` (çalıntı token koruması) |
| 6 | `Post "/auth/password" @{ currentPassword="yanlis"; newPassword="yeni-guclu-sifre" } $t.accessToken` | `HTTP 403` |
| 7 | `Post "/auth/password" @{ currentPassword="cok-guclu-sifre"; newPassword="yeni-guclu-sifre" } $t.accessToken` | `revokedSessions` ≥ 0, bu cihazın oturumu açık kalır, diğerleri kapanır |
| 8 | Eski şifreyle login | `HTTP 401`; yeni şifreyle `200` |
| 9 | `Post "/auth/logout-all" @{} $t.accessToken` | Yanıt boş (204); bu token ile `GET /users/me` `401` |
| 10 | `PATCH /users/me` ile `displayName` içine satır sonu (`"Eren`n"`) | `HTTP 400` |

## 3. Proxy arkasında rate limit (deploy öncesi)

Üretimde API, aynı makinedeki HTTPS proxy'nin arkasında `127.0.0.1:3000` üzerinde yayınlanır. `.env.production` içinde `TRUST_PROXY=loopback` olmalıdır. Kontrol:

```powershell
1..6 | % { curl.exe -s -o NUL -w "%{http_code} " -H "X-Forwarded-For: 203.0.113.$_" -H "Content-Type: application/json" -d '{"email":"a@b.co","password":"x"}' http://127.0.0.1:3000/v1/auth/login }
```

Farklı IP'ler için altı yanıtın tümü `401` olmalı (her istemcinin kendi sınırı var). `TRUST_PROXY` boşsa altıncısı `429` olur; bu da tüm kullanıcıların tek bir sınırı paylaştığı anlamına gelir. `TRUST_PROXY=true` yazılırsa API başlamaz (IP sahteciliğine açık olduğu için bilerek reddedilir).
