/// Terms of Use and Privacy Policy shown in the app.
///
/// TASLAK: Bu metinler hukuki inceleme için yer tutucudur. Yayından önce bir
/// hukukçu tarafından gözden geçirilmeli ve köşeli parantezli alanlar
/// doldurulmalıdır. Metin değiştiğinde [termsVersion] değerini ve backend'deki
/// `TERMS_VERSION` sabitini birlikte güncelle.
library;

/// Must match `TERMS_VERSION` in `backend/src/auth.service.ts`.
const termsVersion = '2026-11-16';

class LegalSection {
  const LegalSection(this.title, this.body);
  final String title, body;
}

class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.updated,
    required this.sections,
  });
  final String title, updated;
  final List<LegalSection> sections;
}

const _updated = 'Son güncelleme: 16 Kasım 2026 · Sürüm $termsVersion';

const termsOfUse = LegalDocument(
  title: 'Kullanım Koşulları',
  updated: _updated,
  sections: [
    LegalSection(
      'Taslak metin',
      'Bu metin bir taslaktır ve hukuki inceleme sonrasında güncellenecektir. '
          'Köşeli parantez içindeki alanlar yayından önce doldurulacaktır.',
    ),
    LegalSection(
      '1. Taraflar ve kapsam',
      'Bu koşullar, [ŞİRKET / GELİŞTİRİCİ ADI] ("biz") tarafından sunulan '
          'Taze Kal mobil uygulamasının ("Uygulama") kullanımını düzenler. '
          'Hesap oluşturarak veya Google ile devam ederek bu koşulları kabul '
          'etmiş olursun.',
    ),
    LegalSection(
      '2. Hizmetin niteliği',
      'Taze Kal, mutfağındaki ürünleri ve son tüketim tarihlerini takip '
          'etmene yardımcı olan bir envanter aracıdır. Uygulamanın gösterdiği '
          'tahmini raf ömrü ve hatırlatmalar yalnızca bilgilendirme amaçlıdır; '
          'ambalaj üzerindeki tarih ve saklama talimatlarının yerini tutmaz. '
          'Bir ürünün tüketime uygun olup olmadığına ilişkin karar ve sorumluluk '
          'sana aittir.',
    ),
    LegalSection(
      '3. Hesap',
      'Hesap bilgilerinin doğru olmasından ve şifrenin gizli tutulmasından '
          'sen sorumlusun. Hesabını dilediğin zaman Profilim > Hesabımı sil '
          'adımlarıyla kalıcı olarak silebilirsin. Hesabını oluşturmadan da '
          'Uygulamayı yalnızca bu cihazda kullanabilirsin.',
    ),
    LegalSection(
      '4. Kabul edilebilir kullanım',
      'Uygulamayı hukuka aykırı amaçlarla kullanamaz, hizmete yetkisiz '
          'erişmeye, başkalarının hesaplarına girmeye veya hizmeti aksatacak '
          'otomatik istekler göndermeye çalışamazsın. Bu koşulların ihlali '
          'halinde hesabını askıya alabilir veya kapatabiliriz.',
    ),
    LegalSection(
      '5. Hizmetin sürekliliği',
      'Hizmeti kesintisiz sunmaya çalışırız ancak bakım, bağlantı sorunları '
          'veya öngörülemeyen nedenlerle kesinti yaşanabilir. Uygulama '
          '"olduğu gibi" sunulur; yürürlükteki mevzuatın izin verdiği ölçüde '
          'dolaylı zararlardan sorumlu değiliz.',
    ),
    LegalSection(
      '6. Değişiklikler',
      'Bu koşulları güncelleyebiliriz. Önemli değişikliklerde Uygulama '
          'içinde bilgilendirir ve gerektiğinde yeniden onayını isteriz.',
    ),
    LegalSection(
      '7. Uygulanacak hukuk ve iletişim',
      'Bu koşullar Türkiye Cumhuriyeti hukukuna tabidir. Sorularını '
          '[İLETİŞİM E-POSTASI] adresine iletebilirsin.',
    ),
  ],
);

const privacyPolicy = LegalDocument(
  title: 'Gizlilik Politikası',
  updated: _updated,
  sections: [
    LegalSection(
      'Taslak metin',
      'Bu metin 6698 sayılı KVKK ve uygulama mağazası gereksinimleri '
          'dikkate alınarak hazırlanmış bir taslaktır; hukuki inceleme '
          'sonrasında güncellenecektir.',
    ),
    LegalSection(
      '1. Veri sorumlusu',
      '[ŞİRKET / GELİŞTİRİCİ ADI], [ADRES]. İletişim: [İLETİŞİM E-POSTASI].',
    ),
    LegalSection(
      '2. Topladığımız veriler',
      'Hesap: ad, e-posta adresi, şifrenin geri döndürülemez özeti (şifrenin '
          'kendisi saklanmaz) ve Google ile girişte Google hesap kimliği.\n'
          'Mutfak verileri: eklediğin ürünlerin adı, miktarı, saklama yeri, '
          'alış/açılış/son tüketim tarihleri.\n'
          'Oturum: oturum kayıtları ve kabul ettiğin koşul sürümü.\n'
          'Fiş tarama: Fiş fotoğrafları cihazında işlenir; fotoğraf '
          'sunucularımıza gönderilmez.',
    ),
    LegalSection(
      '3. Verileri kullanma amacımız',
      'Hesabını oluşturmak ve oturumunu güvenle yönetmek, ürünlerini '
          'cihazların arasında eşitlemek, hatırlatma bildirimleri göstermek ve '
          'hizmetin güvenliğini sağlamak. Verilerini reklam amacıyla '
          'kullanmayız ve satmayız.',
    ),
    LegalSection(
      '4. Hukuki sebep',
      'Verilerin, hizmet sözleşmesinin kurulması ve ifası ile meşru '
          'menfaatimiz (hizmet güvenliği) kapsamında işlenir.',
    ),
    LegalSection(
      '5. Aktarım ve saklama',
      'Veriler [BARINDIRMA SAĞLAYICISI / ÜLKE] üzerindeki sunucularda '
          'saklanır. Google ile giriş yaptığında kimliğin Google tarafından '
          'doğrulanır. Yasal zorunluluklar dışında verilerin üçüncü kişilerle '
          'paylaşılmaz.',
    ),
    LegalSection(
      '6. Hesap ve veri silme',
      'Profilim > Hesabımı sil adımlarıyla hesabını istediğin an silebilirsin. '
          'Silme işlemi hesabını, oturumlarını ve sunucudaki tüm ürün '
          'kayıtlarını kalıcı olarak kaldırır ve geri alınamaz. Hesaba ait '
          'ürünlerin bu cihazdaki kopyası da silinir. Yedeklerdeki kopyalar en '
          'geç [SÜRE] içinde yedek döngüsüyle temizlenir.',
    ),
    LegalSection(
      '7. Hakların',
      'KVKK madde 11 kapsamında verilerinin işlenip işlenmediğini öğrenme, '
          'düzeltilmesini veya silinmesini isteme ve itiraz etme haklarına '
          'sahipsin. Taleplerini [İLETİŞİM E-POSTASI] adresine iletebilirsin.',
    ),
    LegalSection(
      '8. Çocuklar',
      'Uygulama 13 yaşından küçük çocuklara yönelik değildir.',
    ),
  ],
);
