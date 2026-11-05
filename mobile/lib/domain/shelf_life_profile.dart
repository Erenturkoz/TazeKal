/// Conservative planning estimates after purchase, never a safety guarantee.
class ShelfLifeProfile {
  const ShelfLifeProfile(this.id, this.label, this.days, this.source, this.url);
  final String id, label, source, url;
  final int days;
  static const coldChart =
      'https://www.foodsafety.gov/food-safety-charts/cold-food-storage-charts';
  static const all = [
    ShelfLifeProfile(
      'fresh_milk_v1',
      'Pastörize / günlük süt',
      5,
      'CSIRO • Refrigerated storage',
      'https://www.csiro.au/en/research/production/food/refrigerating-foods',
    ),
    ShelfLifeProfile(
      'shell_eggs_v1',
      'Çiğ, kabuklu yumurta',
      21,
      'FoodSafety.gov • Cold Food Storage',
      coldChart,
    ),
    ShelfLifeProfile(
      'raw_ground_meat_v1',
      'Taze, çiğ kıyma',
      1,
      'FoodSafety.gov • Cold Food Storage',
      coldChart,
    ),
    ShelfLifeProfile(
      'raw_poultry_v1',
      'Taze, çiğ tavuk / hindi',
      1,
      'FoodSafety.gov • Cold Food Storage',
      coldChart,
    ),
    ShelfLifeProfile(
      'raw_fish_v1',
      'Taze, çiğ balık',
      1,
      'FoodSafety.gov • Cold Food Storage',
      coldChart,
    ),
    ShelfLifeProfile(
      'raw_meat_v1',
      'Taze, çiğ parça et',
      3,
      'FoodSafety.gov • Cold Food Storage',
      coldChart,
    ),
  ];
  static ShelfLifeProfile? find(String? id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  static ShelfLifeProfile? suggest(
    String name,
    String location,
    String? openingProfile,
  ) {
    if (location != 'Buzdolabı') return null;
    final text = name
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ç', 'c')
        .replaceAll('ğ', 'g')
        .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
    if (RegExp(
      r'\b(toz|bebek|bitkisel|badem|yulaf|soya|hindistan|uht|uzun|pismis|pisirilmis|haslanmis|salata[a-z]*|corba[a-z]*|konserve|dondurulmus|fume|sosis|salam|sucuk|kofte|kavrulmus)\b',
    ).hasMatch(text)) {
      return null;
    }
    if (text.contains('cig') && text.contains('sut')) return null;
    if (openingProfile == 'milk_pasteurized_v1' ||
        (text.contains('sut') &&
            (text.contains('gunluk') || text.contains('pastorize')))) {
      return all[0];
    }
    if (RegExp(r'\byumurta\b').hasMatch(text)) return all[1];
    if (RegExp(r'\bkiyma\b').hasMatch(text)) return all[2];
    if (RegExp(r'\b(tavuk|hindi)\b').hasMatch(text)) return all[3];
    if (RegExp(r'\b(balik|somon|hamsi|levrek|cipura)\b').hasMatch(text)) {
      return all[4];
    }
    if (RegExp(r'\b(biftek|pirzola|kusbasi)\b').hasMatch(text)) return all[5];
    return null;
  }
}
