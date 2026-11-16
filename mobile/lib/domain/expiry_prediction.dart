import 'food_category.dart';
import 'product.dart';

/// How urgent a product is, from most to least urgent.
enum ExpiryRisk {
  /// A package date or label instruction has passed.
  expired,

  /// An estimate (rule or category) has passed: the product may have spoiled.
  likelyExpired,
  expiresToday,
  soon,
  fresh,

  /// Not enough information to say anything.
  unknown,
}

enum PredictionConfidence { high, medium, low, none }

/// Where the predicted date came from, strongest first.
enum PredictionBasis {
  /// Date printed on the package.
  packageDate,

  /// "Consume within N days after opening" from the package label.
  labelOpening,

  /// Versioned, source-based opening rule ([OpeningProfile]).
  openingRule,

  /// Versioned, source-based purchase rule ([ShelfLifeProfile]).
  purchaseRule,

  /// Broad food group inferred from the name ([FoodCategory]).
  categoryHeuristic,
  none,
}

class ExpiryPrediction {
  const ExpiryPrediction({
    required this.risk,
    required this.confidence,
    required this.basis,
    required this.reasons,
    this.date,
    this.daysLeft,
    this.category,
  });

  final ExpiryRisk risk;
  final PredictionConfidence confidence;
  final PredictionBasis basis;

  /// Last day the product should be used (or checked, for heuristics).
  final DateTime? date;

  /// Calendar days from today to [date]; negative once it has passed.
  final int? daysLeft;
  final FoodCategory? category;

  /// Short Turkish explanations, most important first.
  final List<String> reasons;

  /// True when the date has passed, whether certain or estimated.
  bool get isPast =>
      risk == ExpiryRisk.expired || risk == ExpiryRisk.likelyExpired;

  bool get isEstimate =>
      basis != PredictionBasis.packageDate &&
      basis != PredictionBasis.labelOpening &&
      basis != PredictionBasis.none;

  String get headline {
    final n = daysLeft;
    return switch (risk) {
      ExpiryRisk.expired => 'Tarihi geçti',
      ExpiryRisk.likelyExpired => 'Bozulmuş olabilir, kontrol et',
      ExpiryRisk.expiresToday =>
        isEstimate ? 'Tahmini son gün bugün' : 'Bugün son gün',
      ExpiryRisk.soon =>
        isEstimate ? 'Tahmini $n gün içinde tüket' : '$n gün içinde tüket',
      ExpiryRisk.fresh => isEstimate ? 'Tahmini $n gün var' : '$n gün var',
      ExpiryRisk.unknown => 'Tahmin için bilgi yok',
    };
  }

  String get confidenceLabel => switch (confidence) {
    PredictionConfidence.high => 'Yüksek güven',
    PredictionConfidence.medium => 'Orta güven',
    PredictionConfidence.low => 'Düşük güven',
    PredictionConfidence.none => 'Tahmin yok',
  };
}

/// Predicts whether [product] has passed, or will soon pass, its expiry.
///
/// Evidence is used strongest first: package date, label opening instruction,
/// source-based opening/purchase rules (all via [Product.effectiveExpiry]),
/// then a broad food-group heuristic. The heuristic never extends a known
/// package date and its result is advisory only: reminders keep using
/// [Product.effectiveExpiry], so no notification is sent for a guess.
ExpiryPrediction predictExpiry(
  Product product,
  DateTime now, {
  int soonDays = 3,
}) {
  final today = calendarDay(now);

  if (product.hasTrackingDate) {
    final date = product.effectiveExpiry!;
    final basis = _trackedBasis(product, date);
    final confidence = switch (basis) {
      PredictionBasis.packageDate ||
      PredictionBasis.labelOpening => PredictionConfidence.high,
      _ => PredictionConfidence.medium,
    };
    return _build(
      date: date,
      today: today,
      basis: basis,
      confidence: confidence,
      soonDays: soonDays,
      reasons: [_trackedReason(product, basis)],
      category: FoodCategory.infer(product.name),
    );
  }

  // A passed package date is decisive even when the opening window is unknown.
  final package = product.expiresAt;
  if (package != null &&
      !product.usesPurchaseEstimate &&
      calendarDifference(package, today) < 0) {
    return _build(
      date: calendarDay(package),
      today: today,
      basis: PredictionBasis.packageDate,
      confidence: PredictionConfidence.high,
      soonDays: soonDays,
      reasons: const ['Ambalaj tarihi geçti.'],
      category: FoodCategory.infer(product.name),
    );
  }

  final category = FoodCategory.infer(product.name);
  if (category == null) {
    return ExpiryPrediction(
      risk: ExpiryRisk.unknown,
      confidence: PredictionConfidence.none,
      basis: PredictionBasis.none,
      date: package == null ? null : calendarDay(package),
      daysLeft: package == null ? null : calendarDifference(package, today),
      reasons: [
        package == null
            ? 'Ambalaj tarihi yok ve ürün adı tanınan bir gruba uymuyor.'
            : 'Ürün açılmış ama açıldıktan sonraki süre bilinmiyor.',
        'Ambalajdaki tarihi veya "açıldıktan sonra … gün" talimatını ekle.',
      ],
    );
  }

  final reasons = <String>[];
  final storageDays = category.daysFor(product.location);
  DateTime date;
  if (storageDays == null) {
    date = calendarDay(product.purchasedAt);
    reasons.add(
      '${category.label} ${_locationName(product.location)} saklanmaya '
      'uygun değil; en kısa sürede kontrol et.',
    );
  } else {
    date = addCalendarDays(product.purchasedAt, storageDays);
    reasons.add(
      '${category.label}, ${_locationName(product.location)} alıştan sonra '
      'yaklaşık $storageDays gün.',
    );
  }

  final opened = product.openedAt;
  final openedDays = category.openedDays;
  if (opened != null && openedDays != null && product.location != freezer) {
    final afterOpening = addCalendarDays(opened, openedDays);
    if (afterOpening.isBefore(date)) {
      date = afterOpening;
      reasons.insert(0, 'Açıldıktan sonra yaklaşık $openedDays gün.');
    }
  }

  // Never predict past a known package date.
  if (package != null && calendarDay(package).isBefore(date)) {
    date = calendarDay(package);
    reasons.insert(0, 'Ambalaj tarihi tahminden önce geliyor.');
  }

  if (product.location == freezer) {
    reasons.add('Dondurucuda süre güvenlikten çok lezzet/kalite içindir.');
  }
  reasons.add(
    'Kategori adına göre tahmin; fiziksel bozulmayı ölçmez. Ambalaj tarihi '
    'varsa onu ekle.',
  );

  return _build(
    date: date,
    today: today,
    basis: PredictionBasis.categoryHeuristic,
    confidence: PredictionConfidence.low,
    soonDays: soonDays,
    reasons: reasons,
    category: category,
  );
}

/// Predictions for [products], most urgent first. Unknown ones go last.
List<(Product, ExpiryPrediction)> rankByUrgency(
  Iterable<Product> products,
  DateTime now, {
  int soonDays = 3,
}) {
  final list = [
    for (final p in products) (p, predictExpiry(p, now, soonDays: soonDays)),
  ];
  list.sort((a, b) {
    final ar = a.$2, br = b.$2;
    if ((ar.daysLeft == null) != (br.daysLeft == null)) {
      return ar.daysLeft == null ? 1 : -1;
    }
    if (ar.daysLeft != null && ar.daysLeft != br.daysLeft) {
      return ar.daysLeft!.compareTo(br.daysLeft!);
    }
    return ar.confidence.index.compareTo(br.confidence.index);
  });
  return list;
}

ExpiryPrediction _build({
  required DateTime date,
  required DateTime today,
  required PredictionBasis basis,
  required PredictionConfidence confidence,
  required int soonDays,
  required List<String> reasons,
  FoodCategory? category,
}) {
  final n = calendarDifference(date, today);
  final certain = confidence == PredictionConfidence.high;
  final risk = n < 0
      ? (certain ? ExpiryRisk.expired : ExpiryRisk.likelyExpired)
      : n == 0
      ? ExpiryRisk.expiresToday
      : n <= soonDays
      ? ExpiryRisk.soon
      : ExpiryRisk.fresh;
  return ExpiryPrediction(
    risk: risk,
    confidence: confidence,
    basis: basis,
    date: date,
    daysLeft: n,
    category: category,
    reasons: List.unmodifiable(reasons),
  );
}

PredictionBasis _trackedBasis(Product p, DateTime effective) {
  final opening = p.openingExpiry;
  final package = p.expiresAt;
  final openingWins =
      opening != null &&
      calendarDifference(opening, effective) == 0 &&
      (package == null || opening.isBefore(calendarDay(package)));
  if (openingWins) {
    return p.afterOpeningDays != null && p.afterOpeningDays! > 0
        ? PredictionBasis.labelOpening
        : PredictionBasis.openingRule;
  }
  return p.usesPurchaseEstimate
      ? PredictionBasis.purchaseRule
      : PredictionBasis.packageDate;
}

String _trackedReason(Product p, PredictionBasis basis) => switch (basis) {
  PredictionBasis.packageDate => 'Ambalaj tarihine göre.',
  PredictionBasis.labelOpening =>
    'Ambalajdaki "açıldıktan sonra ${p.afterOpeningDays} gün" talimatına göre.',
  PredictionBasis.openingRule =>
    'Açılma kuralına göre (${p.openingProfile?.label ?? 'kaynaklı kural'}).',
  PredictionBasis.purchaseRule =>
    'Alış tarihinden kaynaklı saklama süresine göre.',
  _ => '',
};

String _locationName(String location) => switch (location) {
  fridge => 'buzdolabında',
  pantry => 'kilerde',
  freezer => 'dondurucuda',
  _ => location,
};
