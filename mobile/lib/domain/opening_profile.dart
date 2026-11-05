/// Versioned, source-based planning rules. These are not spoilage measurements.
class OpeningProfile {
  const OpeningProfile({
    required this.id,
    required this.label,
    required this.days,
    required this.source,
    required this.url,
    required this.explanation,
  });
  final String id, label, source, url, explanation;
  final int days;

  static const all = [
    OpeningProfile(
      id: 'milk_uht_v1',
      label: 'UHT / uzun ömürlü süt',
      days: 2,
      source: 'Pınar • Merak Ettikleriniz',
      url:
          'https://www.pinar.com.tr/yasam_kaliteniz/detay/Merak-Ettikleriniz/47/274/0',
      explanation:
          'Kaynakta açılmış UHT süt için +4°C’de 2 gün belirtilir. Bu ilk sürüm bunu ihtiyatlı bir başlangıç tahmini olarak kullanır; markanın ambalaj talimatı önceliklidir.',
    ),
    OpeningProfile(
      id: 'milk_pasteurized_v1',
      label: 'Pastörize / günlük süt',
      days: 1,
      source: 'Çorum İl Sağlık Müdürlüğü',
      url:
          'https://corumism.saglik.gov.tr/TR-37567/sut-ve-sut-urunlerini-tuketirken-nelere-dikkat-edilmelidir.html',
      explanation:
          'Kaynak, buzdolabındaki pastörize süt için 1–2 gün belirtir. İlk sürüm ihtiyatlı takip için aralığın kısa ucunu, 1 günü kullanır.',
    ),
  ];

  static OpeningProfile? find(String? id) {
    for (final profile in all) {
      if (profile.id == id) return profile;
    }
    return null;
  }
}
