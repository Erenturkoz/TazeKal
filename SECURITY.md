# Güvenlik ve hesap durumları

Güvenlik sorunlarını açık issue içine şifre, token, fiş veya kişisel veri koymadan proje sahibine bildirin. Henüz ayrı güvenlik iletişim kanalı belirlenmedi.

Kod; hash'li şifreler, sunucuda doğrulanan Google ID token'ları, oturum iptali, dönen refresh token, parametreli SQL ve kullanıcıya ayrılan yerel kayıtlar içerir. Gerçek kimlik bilgileri örnek dosyalara yazılmaz.

Mevcut sürüm bir geliştirme MVP'sidir. Canlı dağıtım öncesinde e-posta doğrulama/sıfırlama, hesap/veri silme, HTTPS, veri tabanı yedekleme ve ortak rate-limit/izleme düzenlenmelidir. PostgreSQL schema değişiklikleri ve mobil veri geçişleri kullanıcı kayıtlarını korumalıdır. Google'ın gerçek proje yapılandırması ayrı doğrulanmalıdır.
