import 'turkish_text.dart';

/// Storage locations used by the app. Kept as strings to match [Product].
const fridge = 'Buzdolabı';
const pantry = 'Kiler';
const freezer = 'Dondurucu';

/// A broad food group with conservative "check by" windows per storage
/// location. These are planning heuristics for products that have no package
/// date or verified rule; they are never a safety guarantee and are not used
/// for scheduled reminders.
///
/// A `null` window means the food should not be kept in that location, so the
/// prediction treats it as risky from the first day.
class FoodCategory {
  const FoodCategory({
    required this.id,
    required this.label,
    required this.keywords,
    this.fridgeDays,
    this.pantryDays,
    this.freezerDays,
    this.openedDays,
    this.excludes = const [],
  });

  final String id, label;

  /// Normalised (ASCII, lower-case) word prefixes. A keyword matches when a
  /// word in the product name starts with it, so "domatesler" hits "domates".
  /// Keywords of three letters or fewer ("et", "un", "tuz") only match the
  /// bare word or a plural/possessive form, so "tuzlu" is not salt.
  final List<String> keywords;

  /// Words that look like a keyword but belong elsewhere ("salatalık" is a
  /// vegetable, not a prepared "salata").
  final List<String> excludes;
  final int? fridgeDays, pantryDays, freezerDays;

  /// Days after opening when kept cold. `null` means opening does not shorten
  /// the storage window in a meaningful way (e.g. whole produce).
  final int? openedDays;

  int? daysFor(String location) => switch (location) {
    fridge => fridgeDays,
    pantry => pantryDays,
    freezer => freezerDays,
    _ => null,
  };

  static final _shortSuffix = RegExp(r'^(ler|lar|i|u|yi|yu|si|su)?$');

  bool matches(String normalizedName) {
    final padded = ' $normalizedName ';
    if (excludes.any((e) => padded.contains(' $e'))) return false;
    for (final k in keywords) {
      var from = 0;
      while (true) {
        final at = padded.indexOf(' $k', from);
        if (at < 0) break;
        from = at + 1;
        if (k.length > 3) return true;
        final end = padded.indexOf(' ', at + 1 + k.length);
        if (_shortSuffix.hasMatch(padded.substring(at + 1 + k.length, end))) {
          return true;
        }
      }
    }
    return false;
  }

  static const source =
      'Genel saklama kılavuzları (ör. FoodSafety.gov Cold Food Storage) '
      'temel alınarak aralığın kısa ucu seçildi.';

  /// Ordered from most to least specific: the first match wins, so prepared
  /// dishes beat their ingredients ("tavuklu pilav" is a leftover, not raw
  /// poultry) and "sosis" is processed meat rather than a sauce.
  static const all = [
    FoodCategory(
      id: 'frozen_food',
      label: 'Dondurulmuş ürün',
      keywords: ['dondurulmus', 'dondurma', 'donuk'],
      freezerDays: 180,
      fridgeDays: 1,
    ),
    FoodCategory(
      id: 'cooked_leftovers',
      label: 'Pişmiş yemek / artık',
      keywords: [
        'pismis',
        'pisirilmis',
        'haslanmis',
        'yemek',
        'artik',
        'corba',
        'pilav',
        'salata',
        'sutlac',
        'puding',
        'tatli',
      ],
      excludes: ['salatalik'],
      fridgeDays: 3,
      freezerDays: 60,
    ),
    FoodCategory(
      id: 'canned',
      label: 'Konserve',
      keywords: ['konserve', 'ton baligi', 'tursu'],
      pantryDays: 365,
      fridgeDays: 365,
      freezerDays: 365,
      openedDays: 4,
    ),
    FoodCategory(
      id: 'plant_or_uht_milk',
      label: 'UHT / bitkisel süt',
      keywords: [
        'uht',
        'uzun omurlu',
        'badem sut',
        'yulaf sut',
        'soya sut',
        'hindistan cevizi sut',
        'bitkisel sut',
      ],
      pantryDays: 90,
      fridgeDays: 90,
      openedDays: 2,
    ),
    FoodCategory(
      id: 'dry_goods',
      label: 'Kuru gıda / bakliyat',
      keywords: [
        'toz sut',
        'pirinc',
        'makarna',
        'eriste',
        'bulgur',
        'un',
        'irmik',
        'sehriye',
        'mercimek',
        'nohut',
        'kuru fasulye',
        'barbunya',
        'yulaf',
        'kinoa',
        'seker',
        'tuz',
        'cay',
        'kahve',
        'baharat',
        'kekik',
        'pul biber',
      ],
      pantryDays: 180,
      fridgeDays: 180,
      freezerDays: 365,
    ),
    FoodCategory(
      id: 'processed_meat',
      label: 'Şarküteri (sucuk, salam, sosis)',
      keywords: ['sucuk', 'salam', 'sosis', 'jambon', 'pastirma', 'fume'],
      fridgeDays: 7,
      freezerDays: 60,
      openedDays: 5,
    ),
    FoodCategory(
      id: 'ground_meat',
      label: 'Çiğ kıyma / köfte',
      keywords: ['kiyma', 'kofte'],
      fridgeDays: 1,
      freezerDays: 90,
    ),
    FoodCategory(
      id: 'poultry',
      label: 'Çiğ tavuk / hindi',
      keywords: ['tavuk', 'hindi', 'pilic', 'kanat', 'baget'],
      fridgeDays: 1,
      freezerDays: 270,
    ),
    FoodCategory(
      id: 'fish',
      label: 'Çiğ balık / deniz ürünü',
      keywords: [
        'balik',
        'somon',
        'hamsi',
        'levrek',
        'cipura',
        'palamut',
        'uskumru',
        'karides',
        'midye',
      ],
      fridgeDays: 1,
      freezerDays: 90,
    ),
    FoodCategory(
      id: 'red_meat',
      label: 'Çiğ kırmızı et',
      keywords: [
        'et',
        'biftek',
        'pirzola',
        'kusbasi',
        'antrikot',
        'bonfile',
        'kuzu',
        'dana',
        'ciger',
      ],
      fridgeDays: 3,
      freezerDays: 120,
    ),
    FoodCategory(
      id: 'eggs',
      label: 'Yumurta',
      keywords: ['yumurta'],
      fridgeDays: 21,
      pantryDays: 7,
    ),
    FoodCategory(
      id: 'yogurt',
      label: 'Yoğurt / ayran / kefir',
      keywords: ['yogurt', 'ayran', 'kefir'],
      fridgeDays: 7,
      freezerDays: 30,
      openedDays: 3,
    ),
    FoodCategory(
      id: 'hard_cheese',
      label: 'Sert peynir (kaşar, tulum)',
      keywords: ['kasar', 'parmesan', 'gravyer', 'tulum', 'cheddar'],
      fridgeDays: 21,
      freezerDays: 120,
      openedDays: 14,
    ),
    FoodCategory(
      id: 'soft_cheese',
      label: 'Yumuşak peynir (beyaz, lor, labne)',
      keywords: [
        'peynir',
        'lor',
        'labne',
        'cokelek',
        'hellim',
        'mozzarella',
        'krem peynir',
      ],
      fridgeDays: 7,
      freezerDays: 60,
      openedDays: 5,
    ),
    FoodCategory(
      id: 'butter',
      label: 'Tereyağı / margarin',
      keywords: ['tereyag', 'margarin'],
      fridgeDays: 30,
      pantryDays: 2,
      freezerDays: 180,
    ),
    FoodCategory(
      id: 'cream',
      label: 'Krema / kaymak',
      keywords: ['krema', 'kaymak'],
      fridgeDays: 5,
      freezerDays: 60,
      openedDays: 3,
    ),
    FoodCategory(
      id: 'milk',
      label: 'Süt',
      keywords: ['sut'],
      fridgeDays: 5,
      freezerDays: 60,
      openedDays: 2,
    ),
    FoodCategory(
      id: 'juice',
      label: 'Meyve suyu',
      keywords: ['meyve suyu', 'portakal suyu', 'limonata', 'smoothie'],
      fridgeDays: 7,
      pantryDays: 90,
      openedDays: 3,
    ),
    FoodCategory(
      id: 'bread',
      label: 'Ekmek / unlu mamul',
      keywords: [
        'ekmek',
        'simit',
        'pide',
        'lavas',
        'bazlama',
        'pogaca',
        'borek',
        'tortilla',
      ],
      pantryDays: 3,
      fridgeDays: 7,
      freezerDays: 90,
    ),
    FoodCategory(
      id: 'condiments',
      label: 'Sos / reçel / salça',
      keywords: [
        'ketcap',
        'mayonez',
        'hardal',
        'sos',
        'salca',
        'recel',
        'bal',
        'pekmez',
        'tahin',
        'zeytin',
      ],
      pantryDays: 180,
      fridgeDays: 180,
      openedDays: 30,
    ),
    FoodCategory(
      id: 'leafy_greens',
      label: 'Yeşillik',
      keywords: [
        'marul',
        'maydanoz',
        'roka',
        'ispanak',
        'dereotu',
        'nane',
        'tere',
        'semizotu',
        'kivircik',
        'yesillik',
        'taze sogan',
      ],
      fridgeDays: 4,
      pantryDays: 1,
    ),
    FoodCategory(
      id: 'berries',
      label: 'Hassas meyve (çilek, kiraz)',
      keywords: [
        'cilek',
        'ahududu',
        'bogurtlen',
        'yaban mersini',
        'kiraz',
        'visne',
        'dut',
      ],
      fridgeDays: 3,
      pantryDays: 1,
      freezerDays: 240,
    ),
    FoodCategory(
      id: 'soft_fruit',
      label: 'Yumuşak meyve',
      keywords: [
        'muz',
        'seftali',
        'kayisi',
        'erik',
        'incir',
        'uzum',
        'kavun',
        'karpuz',
        'avokado',
        'mango',
      ],
      fridgeDays: 5,
      pantryDays: 3,
      freezerDays: 240,
    ),
    FoodCategory(
      id: 'hard_fruit',
      label: 'Dayanıklı meyve',
      keywords: [
        'elma',
        'armut',
        'portakal',
        'mandalina',
        'limon',
        'greyfurt',
        'nar',
        'ayva',
        'kivi',
      ],
      fridgeDays: 21,
      pantryDays: 7,
    ),
    FoodCategory(
      id: 'root_vegetables',
      label: 'Kök sebze / soğan',
      keywords: ['patates', 'sogan', 'sarimsak', 'havuc', 'pancar', 'zencefil'],
      fridgeDays: 21,
      pantryDays: 14,
    ),
    FoodCategory(
      id: 'vegetables',
      label: 'Sebze',
      keywords: [
        'domates',
        'biber',
        'salatalik',
        'hiyar',
        'patlican',
        'kabak',
        'fasulye',
        'bezelye',
        'brokoli',
        'karnabahar',
        'mantar',
        'lahana',
        'pirasa',
        'enginar',
        'bamya',
      ],
      fridgeDays: 5,
      pantryDays: 2,
      freezerDays: 240,
    ),
    FoodCategory(
      id: 'snacks',
      label: 'Atıştırmalık',
      keywords: [
        'cikolata',
        'biskuvi',
        'kraker',
        'cips',
        'gofret',
        'kuruyemis',
        'findik',
        'fistik',
        'ceviz',
        'badem',
        'leblebi',
      ],
      pantryDays: 90,
      fridgeDays: 90,
      freezerDays: 180,
    ),
  ];

  static FoodCategory? find(String? id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Best-effort category from a free-text product name, or `null` when no
  /// keyword matches. Never guesses beyond the keyword table.
  static FoodCategory? infer(String name) {
    final text = normalizeTurkish(name).replaceAll(RegExp(r' +'), ' ').trim();
    if (text.isEmpty) return null;
    for (final c in all) {
      if (c.matches(text)) return c;
    }
    return null;
  }
}
