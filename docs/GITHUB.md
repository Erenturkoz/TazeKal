# GitHub'a ilk yükleme ve sonraki adımlar

PowerShell komutlarını **proje kökünde** çalıştırın. `mobile/` altında ayrı depo açmayın; Flutter, backend, kurulum belgeleri ve CI aynı depoda tutulur. Bu rehber komutları kendiliğinden çalıştırmaz.

## Tarayıcıdan doğrudan yüklemeden önce

`.gitignore` Git'in dosya seçimini yönetir; orijinal çalışma klasörünü tarayıcıya sürüklediğinizde yerel `.env` ve cihaz dosyalarının korunacağını varsaymayın. [GitHub ignore açıklaması](https://docs.github.com/en/get-started/git-basics/ignoring-files) ve [web yükleme yöntemi](https://docs.github.com/en/repositories/working-with-files/managing-files/adding-a-file-to-a-repository).

```powershell
node tools/check-repo.mjs
node --test tools/repo-audit.test.mjs
node tools/prepare-github.mjs
```

Son komut `github-upload/TazeKal-.../TazeKal-source.zip` altında yalnız denetimden geçen dosyaları arşivler; Git'e ekleme, commit veya ağ yüklemesi yapmaz. ZIP yeniden açılarak dosya listesi, boyutları ve SHA-256 özetleri doğrulanır. Yanındaki `manifest.json` yalnız yerel envanterdir, kaynak kodun parçası değildir. Kaynak değişirse yeni arşiv oluşturun; eski kopya kendiliğinden güncellenmez. Noktayla başlayan `.github`, `.gitignore` gibi gerekli dosyalar arşivde korunur.

ZIP'i etkin Flutter çalışma alanının dışında ayrı bir klasöre çıkarın; IDE/Flutter araçlarını orada çalıştırmadan **çıkan dosya ve klasörleri** depo köküne yükleyin. ZIP'i tek dosya olarak yüklemek kaynak kodunu GitHub'da otomatik açmaz. Flutter araçları açılmış bir kopyada `.dart_tool`, `local.properties` gibi dosyaları yeniden üretebilir; bunları seçmeyin. `DO-NOT-UPLOAD` olarak işaretli eski deneme klasörlerini kullanmayın.

GitHub web arayüzü aynı anda en fazla 100 dosya kabul eder. Proje bu sınırı aştığından tarayıcıda dizin yapısını koruyarak birkaç yükleme gerekir; bütün proje için Git veya GitHub Desktop kullanmak daha uygundur. Orijinal `.git/`, `backend/.env`, `mobile/config/local.json`, veritabanı, APK ve bağımlılık klasörlerini elle eklemeyin.

Yeni fiş/etiket fotoğraflarını veya kişisel deneme verilerini `/local-data/` altında tutun. İncelenmemiş ham veri indirmeleri `/data/raw/` altında tutulabilir. Bu alanlar Git dışında; uygulamanın kaynak görselleriyle karıştırılmamalıdır.

Denetim hem eklenmiş hem eklenmemiş adayları inceler, ignore kuralına rağmen önceden takibe alınmış dosyalarda durur ve bilinen anahtar/token biçimlerini içerikte arar. Eşleşen değerler terminale yazılmaz. Her tür gizli veriyi bulma garantisi değildir; gerçek parolaları örnek dosyalara/testlere yazmayın. Örneklerde yalnız yer tutucu değerler kullanın.

## 1. İlk kontrol

```powershell
cd C:\Users\erenn\Documents\ChatGPT\Uygulama
git status --short
node tools/check-repo.mjs
git check-ignore backend/.env mobile/config/local.json mobile/build
```

Son komut yerel dosyaların yok sayıldığını göstermelidir. `.env`, `local.json`, şifreler, imzalama dosyaları, fiş fotoğrafları, cihaz verileri ve APK'lar depoya eklenmez. `pubspec.lock` ve `package-lock.json` eklenir. `git add -f` kullanmayın.

## 2. İlk commit

Henüz commit yoksa:

```powershell
git add .
node tools/check-repo.mjs
git diff --cached --stat
git diff --cached --check
git diff --cached
git commit -m "feat: initialize Taze Kal mobile app and API"
git branch -M main
```

Commit öncesi eklenen dosyaları gözden geçirin. Yanlışlıkla eklenen dosya varsa commit etmeyin. Git kullanıcı adını/e-postasını isterse kendi bilgilerinizi `git config user.name` ve `git config user.email` ile bu depo için ayarlayın.

## 3. GitHub'a bağlama

GitHub'da boş depo oluşturun; burada bulunduğu için GitHub üzerinden README, `.gitignore` veya lisans eklemeyin. Görünürlüğü siz seçin. URL'yi **kendi deponuzun URL'siyle** değiştirin:

```powershell
git remote add origin https://github.com/KULLANICI_ADIN/taze-kal.git
git remote -v
git push -u origin main
```

`origin` zaten varsa tekrar eklemeyin; `git remote -v` ile hedefi kontrol edin. GitHub parolasını/token'ını koda yazmayın; Git Credential Manager veya GitHub giriş ekranını kullanın.

## 4. Sonraki değişiklikler

İlgili testlerden sonra her tamamlanan özellik için ayrı commit hazırlayın:

```powershell
git status --short
node tools/check-repo.mjs
git add .
git diff --cached --stat
git diff --cached --check
git commit -m "feat: improve product entry and receipt review"
git push
```

Test komutları kök README'dedir. `.github/workflows/ci.yml` push sonrası kaynak kapsamı, backend testleri, Flutter formatı/analizi/testlerini kontrol eder; uygulamayı mağazaya veya sunucuya yayınlamaz. Sonuçları GitHub **Actions** sekmesinden kontrol edin.

Ürünler cihazda hesap bazında önbelleğe alınır ve API üzerinden PostgreSQL'e eşitlenir. GitHub'a push etmek ürünleri yedeklemez veya backend'i yayımlamaz. Her geliştirici Google girişi için kendi yerel yapılandırmasını ve Android imza eşlemesini yapar.
