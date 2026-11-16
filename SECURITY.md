# Güvenlik ve hesap durumları

Güvenlik sorunlarını açık issue içine şifre, token, fiş veya kişisel veri koymadan proje sahibine bildirin. Henüz ayrı güvenlik iletişim kanalı belirlenmedi.

Kod; hash'li şifreler, sunucuda doğrulanan Google ID token'ları, oturum iptali, dönen refresh token (tekrar kullanımda oturumun iptali), şifre değiştirme ve tüm cihazlardan çıkış, proxy arkasında doğru istemci IP'siyle rate limit, hesap başına ürün sınırı, parametreli SQL ve kullanıcıya ayrılan yerel kayıtlar içerir. Gerçek kimlik bilgileri örnek dosyalara yazılmaz.

Mevcut sürüm bir geliştirme MVP'sidir. Canlı dağıtım öncesinde e-posta doğrulama/sıfırlama, hesap/veri silme, HTTPS, veri tabanı yedekleme ve ortak rate-limit/izleme düzenlenmelidir. Elle doğrulama adımları: [docs/BACKEND_TESTING.md](docs/BACKEND_TESTING.md). PostgreSQL schema değişiklikleri ve mobil veri geçişleri kullanıcı kayıtlarını korumalıdır. Google'ın gerçek proje yapılandırması ayrı doğrulanmalıdır.
