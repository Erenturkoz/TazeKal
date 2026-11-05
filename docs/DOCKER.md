# Taşınabilir API kurulumu

Bu kurulum API ve PostgreSQL'i birlikte çalıştırır. Herhangi bir sunucuya yayınlama yapmaz. Docker Engine/Desktop ve Compose v2 gerekir. Komutları `backend/` klasöründe çalıştırın.

## İlk hazırlık

```powershell
Copy-Item .env.production.example .env.production
node -e "console.log(require('node:crypto').randomBytes(48).toString('base64url'))"
```

Komutu iki kez çalıştırıp farklı değerleri `POSTGRES_PASSWORD` ve `JWT_SECRET` alanlarına yazın. Parolada URL güvenli karakterler kullanın; yukarıdaki komut bunu sağlar. `GOOGLE_CLIENT_IDS` alanına mobildeki `serverClientId` ile aynı Web OAuth istemcisini yazın. Boş bırakılırsa Google girişi etkin değildir. Gerçek `.env.production` dosyası Git ve Docker derleme kapsamına girmez.

```powershell
docker compose --env-file .env.production -f compose.production.yaml up -d --build
docker compose --env-file .env.production -f compose.production.yaml ps
Invoke-RestMethod http://localhost:3000/v1/health/ready
```

`status=ok`, `database=ready`, `schemaVersion=2` beklenir. `/v1/health` yalnız süreç kontrolüdür. API veritabanının sağlıklı olmasını bekler; açılırken migration'ı transaction ve PostgreSQL kilidiyle uygular. API root kullanıcısı olmadan, salt okunur dosya sistemiyle çalışır. Bağımlılık kilit dosyası imajda kullanılır. [Compose başlangıç sırası](https://docs.docker.com/compose/how-tos/startup-order/) sağlık bağımlılığını açıklar.

Terminal kapansa da `-d` ile başlayan servisler çalışır. Docker Engine açıldığında `unless-stopped` ilkesiyle yeniden başlar; bilgisayar kapalıyken hizmet sunulmaz.

## Veri alanları ve güncelleme

- Geliştirme `compose.yaml` ile bu dosya farklı proje/volume kullanır. Mevcut geliştirme kayıtlarını otomatik taşımaz. Aynı makinede iki API için farklı `API_PORT` seçin; varsayılan 3000 çakışabilir.
- Aynı `.env.production`, Compose proje adı ve volume korunarak `up -d --build` tekrar çalıştırılır. Veriler imajda değil `production_data` volume'ündedir. Veriyi korumak için `down -v`, volume silme veya veritabanını sıfırlama kullanmayın.
- Var olan PostgreSQL volume'ünde `.env` parolasını değiştirmek veritabanı parolasını değiştirmez. Parola dönüşümünü veritabanı ve API'de koordineli yapın.
- Şema güncellemelerinden önce yedek alın. Eski API imajına dönmek şemayı otomatik geri almaz.

## Yedek ve geri yükleme

```powershell
.\backup.ps1
```

Betik PostgreSQL özel formatında benzersiz dosya oluşturur; PowerShell metin yönlendirmesi üzerinden ikili veriyi geçirmez. `backups/` Git dışında tutulur. Yedekler kullanıcı bilgileri içerir; şifreli ayrı depoda saklayın, düzenli kopyalayın. Bir yerel volume tek başına yedek değildir.

Geri yüklemeyi önce **ayrı boş bir veritabanında** `pg_restore --exit-on-error --no-owner --no-privileges` ile sınayın; kaynak veritabanının üzerine otomatik geri yükleme betiği yoktur. Kontroller: hesap/ürün sayıları, giriş, `/health/ready`, aynı hesapla iki cihaz eşitlemesi. Eski yedek sunucu cursor'unu geriye alabilir; uygulama bu durumda cihaz verilerini silmez, hata gösterir. Yedek geri dönüşünden sonra cihaz eşitlemesi planlanarak yapılmalıdır; kör cursor sıfırlaması yapılmaz.

## Sunucu seçildiğinde

API şimdilik yalnız `127.0.0.1` üzerinde yayınlanır; PostgreSQL host portu açılmaz. Alan adı, HTTPS reverse proxy, güvenlik duvarı, izleme ve dış yedek depolama seçilmeden internete açmayın. Mobil üretim yapılandırmasında HTTPS API adresi kullanılmalıdır. Emülatörde yerel test için `http://10.0.2.2:3000/v1` kullanılır. Bu kurulum tek API örneğidir; süreç içi rate limit birden fazla örnekte ortak depoyla değiştirilmelidir. IP tabanlı limit için güvenilen proxy zinciri ayrıca tanımlanmalıdır.

Canlı sunucu/TLS, dış e-posta servisi, iOS ve mağaza imzaları bu yerel Docker kontrolüyle doğrulanmış sayılmaz. [Yayın öncesi kalan işler](RELEASE.md).
