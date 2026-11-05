# GitHub yükleme öncesi denetim

Tarih: 5 Kasım 2026. Yalnız yerel dosyalar denetlendi; GitHub'a bağlantı, yükleme, commit, push veya depo oluşturma yapılmadı.

## Sonuç

- Çalışma ağacının Git kapsamına girebilecek kaynakları dosya yolu ve tanınan gizli anahtar/token biçimleri açısından denetlendi. İncelenen kapsamda eşleşme bulunmadı. Bu, her tür hassas verinin otomatik tespit edilebildiği anlamına gelmez.
- Bu yerel depoda denetim anında commit ve takibe alınmış dosya yoktu; ignore kuralına rağmen takip edilen dosya bulunmadı. Bu sonuç başka bir uzak deponun geçmişi hakkında bilgi vermez.
- Gerçek `backend/.env`, `backend/.env.before-port-change`, `mobile/config/local.json` ve Android `local.properties` dosyalarının Git dışında olduğu doğrulandı. Yerel dosyalar silinmedi veya değiştirilmedi.
- Veritabanı/dump yedekleri, APK/AAB/IPA, build/dist, bağımlılıklar, SDK önbellekleri, geçici ekran görüntüleri ve imzalama malzemeleri kapsam dışında kaldı.
- Yeni ignore kuralları registry giriş dosyaları, OAuth indirmeleri, arşiv/yedekler, Python ortamları, temiz yükleme çıktısı, özel fotoğraf/veri alanları için genişletildi.
- Flutter/Node kaynakları, uygulama simgeleri, SQL şeması, kurulum belgeleri, yapılandırma örnekleri, `pubspec.lock`, `package-lock.json` ve CI dosyaları korundu. Saklanan eski HTML/JS/CSS prototipi repository anlaşmasına uygun olarak tutuldu.

## Kontroller ve yeni araçlar

- `node tools/check-repo.mjs`: aday dosya yolları, tanınan gizli içerik biçimleri, dışarı yönlenen dosya/symlink ve önceden takip edilen ignored dosyaları denetler. Hata mesajları gizli değeri içermez.
- `node --test tools/repo-audit.test.mjs`: 5 test; özel dosyaların engellenmesi, örnek dosya istisnalarının kapsamı, kaynakların korunması, değer sızdırmadan eşleşme bildirimi ve dizin dışına çıkış koruması.
- `node tools/prepare-github.mjs`: denetimden geçen dosyalarla yeni bir yerel ZIP ve dosya/SHA-256 manifesti oluşturur. Hiçbir eski arşivin üzerine yazmaz; kullanıcı verisini taşımaz veya silmez. ZIP yeniden açılarak dosya listesi, boyutlar ve bütün dosya özetleri doğrulanır. Noktalı dosyalar korunur.
- CI'ya aynı denetim testleri eklendi. GitHub üzerinde workflow çalıştırılmadı.

## Yükleme şekli

Orijinal çalışma klasörünü tarayıcıya sürüklemeyin. `.gitignore` yalnız Git işlemlerinde dosya kapsamını belirler; doğrulanmış ZIP'in içeriğini kullanın veya [Git/GitHub Desktop akışını](GITHUB.md) izleyin. Tarayıcı tek seferde 100 dosya kabul ettiğinden tüm proje birkaç grupta yüklenir. ZIP arşivi yüklemek kaynakları depoda otomatik açmaz.

İlk düz klasör denemesinde Flutter araçlarının kopyaya otomatik olarak 12 yerel/generated dosya eklediği tespit edildi. Bu deneme `DO-NOT-UPLOAD` olarak işaretlendi; yükleme için kullanılmamalıdır. Son yöntem yalnız allowlist dosyalarını doğrudan ZIP'e yazar. Arşivi etkin Flutter çalışma alanı dışında çıkarın; o kopyada araçları çalıştırıp yeniden üretilen yerel dosyaları yüklemeyin.

Snapshot yalnız oluşturulduğu andaki dosyaları içerir; sonraki değişikliklerde yeniden üretin. Özel fiş/etiket fotoğrafları `/local-data/` altında tutulmalı; kaynak ikonları/görselleri oraya taşınmamalıdır. Yerel örnekleri gerçek parolalarla doldurmak yerine ignored yapılandırmaları kullanın.

Bu değişiklikte Flutter/API iş mantığı değiştirilmedi; uygulama testleri yeniden çalıştırılmadı. Denetim ve dışa aktarma kontrolleri göreve uygun olarak çalıştırıldı. Uygulama verileri, emülatör ve veritabanı korunmuştur.
