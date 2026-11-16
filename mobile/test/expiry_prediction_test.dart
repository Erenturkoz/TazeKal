import 'package:flutter_test/flutter_test.dart';
import 'package:taze_kal/domain/expiry_prediction.dart';
import 'package:taze_kal/domain/food_category.dart';
import 'package:taze_kal/domain/product.dart';
import 'package:taze_kal/domain/reminder.dart';
import 'package:taze_kal/domain/shelf_life_profile.dart';

final now = DateTime(2026, 11, 16, 9, 30);

Product item(
  String name, {
  String location = 'Buzdolabı',
  DateTime? purchased,
  DateTime? expires,
  String? expirySource,
  DateTime? opened,
  int? labelDays,
  String? openingProfile,
  bool cold = false,
}) => Product(
  id: name,
  name: name,
  quantity: '1',
  location: location,
  purchasedAt: purchased ?? DateTime(2026, 11, 14),
  expiresAt: expires,
  expirySource: expirySource,
  openedAt: opened,
  afterOpeningDays: labelDays,
  openingProfileId: openingProfile,
  coldStorageConfirmed: cold,
);

void main() {
  group('Category inference', () {
    final cases = {
      'Süt': 'milk',
      'Günlük süt 1L': 'milk',
      'Badem sütü': 'plant_or_uht_milk',
      'UHT süt': 'plant_or_uht_milk',
      'Toz süt': 'dry_goods',
      'İnek peyniri': 'soft_cheese',
      'Tuzlu beyaz peynir': 'soft_cheese',
      'Eski kaşar': 'hard_cheese',
      'Tavuklu pilav': 'cooked_leftovers',
      'Tavuk göğsü': 'poultry',
      'Dana eti': 'red_meat',
      'Kıyma': 'ground_meat',
      'Sosis': 'processed_meat',
      'Ton balığı': 'canned',
      'Somon': 'fish',
      'Salatalık': 'vegetables',
      'Çoban salatası': 'cooked_leftovers',
      'DOMATESLER': 'vegetables',
      'Tereyağı': 'butter',
      'Taze soğan': 'leafy_greens',
      'Kuru soğan': 'root_vegetables',
      'Kuru fasulye': 'dry_goods',
      'Taze fasulye': 'vegetables',
      'Çilek': 'berries',
      'Elma': 'hard_fruit',
      'Ekmek': 'bread',
      'Yumurta 10lu': 'eggs',
      'Dondurulmuş bezelye': 'frozen_food',
      'Bal': 'condiments',
      'Pirinç': 'dry_goods',
    };
    cases.forEach((name, id) {
      test('$name → $id', () {
        expect(FoodCategory.infer(name)?.id, id);
      });
    });

    test('Short keywords do not match inside unrelated words', () {
      // "tuz" must not swallow "tuzlu", "et" must not match "etiket".
      expect(FoodCategory.infer('Tuzlu fıstık')?.id, 'snacks');
      expect(FoodCategory.infer('Etiketsiz kutu'), isNull);
      expect(FoodCategory.infer('Bulaşık deterjanı'), isNull);
      expect(FoodCategory.infer('   '), isNull);
    });

    test('Category ids are unique and every category has a window', () {
      final ids = FoodCategory.all.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final c in FoodCategory.all) {
        expect(
          [c.fridgeDays, c.pantryDays, c.freezerDays].any((d) => d != null),
          isTrue,
          reason: c.id,
        );
        expect(FoodCategory.find(c.id), same(c));
      }
    });
  });

  group('Known dates', () {
    test('Package date gives a certain answer', () {
      final p = predictExpiry(
        item('Yoğurt', expires: DateTime(2026, 11, 20)),
        now,
      );
      expect(p.basis, PredictionBasis.packageDate);
      expect(p.confidence, PredictionConfidence.high);
      expect(p.daysLeft, 4);
      expect(p.risk, ExpiryRisk.fresh);
      expect(p.headline, '4 gün var');
    });

    test('Risk thresholds around today', () {
      ExpiryRisk risk(int days) => predictExpiry(
        item('Yoğurt', expires: addCalendarDays(now, days)),
        now,
      ).risk;
      expect(risk(-1), ExpiryRisk.expired);
      expect(risk(0), ExpiryRisk.expiresToday);
      expect(risk(1), ExpiryRisk.soon);
      expect(risk(3), ExpiryRisk.soon);
      expect(risk(4), ExpiryRisk.fresh);
      final custom = predictExpiry(
        item('Yoğurt', expires: addCalendarDays(now, 5)),
        now,
        soonDays: 7,
      );
      expect(custom.risk, ExpiryRisk.soon);
    });

    test('Label opening instruction wins when it comes first', () {
      final p = predictExpiry(
        item(
          'Krema',
          expires: DateTime(2026, 12, 1),
          opened: DateTime(2026, 11, 15),
          labelDays: 3,
        ),
        now,
      );
      expect(p.basis, PredictionBasis.labelOpening);
      expect(p.confidence, PredictionConfidence.high);
      expect(p.date, DateTime(2026, 11, 18));
    });

    test('Opening rule is a medium-confidence estimate', () {
      final p = predictExpiry(
        item(
          'Süt',
          expires: DateTime(2026, 11, 30),
          opened: DateTime(2026, 11, 14),
          openingProfile: 'milk_uht_v1',
          cold: true,
        ),
        now,
      );
      expect(p.basis, PredictionBasis.openingRule);
      expect(p.confidence, PredictionConfidence.medium);
      expect(p.risk, ExpiryRisk.expiresToday);
      expect(p.headline, 'Tahmini son gün bugün');
    });

    test('Passed estimate is "may have spoiled", not certain', () {
      final p = predictExpiry(
        item(
          'Süt',
          expires: DateTime(2026, 11, 30),
          opened: DateTime(2026, 11, 10),
          openingProfile: 'milk_pasteurized_v1',
          cold: true,
        ),
        now,
      );
      expect(p.risk, ExpiryRisk.likelyExpired);
      expect(p.isPast, isTrue);
    });

    test('Purchase rule estimate is medium confidence', () {
      final profile = ShelfLifeProfile.find('raw_meat_v1')!;
      final purchased = DateTime(2026, 11, 14);
      final p = predictExpiry(
        item(
          'Kuşbaşı',
          purchased: purchased,
          expires: addCalendarDays(purchased, profile.days),
          expirySource: 'estimated',
          labelDays: null,
        ),
        now,
      );
      expect(p.basis, PredictionBasis.purchaseRule);
      expect(p.confidence, PredictionConfidence.medium);
      expect(p.daysLeft, 1);
    });

    test(
      'Passed package date is decisive even with unknown opening window',
      () {
        final p = predictExpiry(
          item(
            'Bilinmeyen ürün',
            expires: DateTime(2026, 11, 10),
            opened: DateTime(2026, 11, 9),
          ),
          now,
        );
        expect(p.risk, ExpiryRisk.expired);
        expect(p.basis, PredictionBasis.packageDate);
      },
    );
  });

  group('Category heuristic', () {
    test('Undated fridge yogurt gets a low-confidence check date', () {
      final p = predictExpiry(item('Yoğurt'), now);
      expect(p.basis, PredictionBasis.categoryHeuristic);
      expect(p.confidence, PredictionConfidence.low);
      expect(p.date, DateTime(2026, 11, 21));
      expect(p.risk, ExpiryRisk.fresh);
      expect(p.headline, startsWith('Tahmini'));
      expect(p.reasons.last, contains('fiziksel bozulmayı ölçmez'));
    });

    test('Storage location changes the window', () {
      DateTime? date(String location) =>
          predictExpiry(item('Ekmek', location: location), now).date;
      expect(date('Kiler'), DateTime(2026, 11, 17));
      expect(date('Buzdolabı'), DateTime(2026, 11, 21));
      expect(date('Dondurucu'), DateTime(2027, 2, 12));
    });

    test('Freezer reason explains quality vs safety', () {
      final p = predictExpiry(item('Tavuk', location: 'Dondurucu'), now);
      expect(p.reasons.join(' '), contains('kalite'));
      expect(p.risk, ExpiryRisk.fresh);
    });

    test('Unsuitable storage is flagged immediately', () {
      final p = predictExpiry(item('Kıyma', location: 'Kiler'), now);
      expect(p.date, DateTime(2026, 11, 14));
      expect(p.risk, ExpiryRisk.likelyExpired);
      expect(p.reasons.first, contains('uygun değil'));
    });

    test('Opening shortens the window', () {
      final p = predictExpiry(
        item('Yoğurt', opened: DateTime(2026, 11, 13)),
        now,
      );
      expect(p.date, DateTime(2026, 11, 16));
      expect(p.risk, ExpiryRisk.expiresToday);
      expect(p.reasons.first, contains('Açıldıktan sonra'));
    });

    test('Opened product without a rule falls back to the category', () {
      // hasTrackingDate is false: opened, no opening rule.
      final product = item(
        'Beyaz peynir',
        expires: DateTime(2026, 12, 20),
        opened: DateTime(2026, 11, 10),
      );
      expect(product.hasTrackingDate, isFalse);
      final p = predictExpiry(product, now);
      expect(p.basis, PredictionBasis.categoryHeuristic);
      expect(p.date, DateTime(2026, 11, 15));
      expect(p.risk, ExpiryRisk.likelyExpired);
    });

    test('Heuristic never extends a known package date', () {
      final product = item(
        'Kaşar',
        expires: DateTime(2026, 11, 18),
        opened: DateTime(2026, 11, 15),
      );
      final p = predictExpiry(product, now);
      expect(p.date, DateTime(2026, 11, 18));
      expect(p.reasons.first, contains('Ambalaj tarihi'));
    });

    test('Heuristic guesses never create reminders', () {
      final product = item('Yoğurt');
      expect(predictExpiry(product, now).date, isNotNull);
      expect(buildReminders([product], now, 10, 0), isEmpty);
    });

    test('Unknown products say so instead of inventing a date', () {
      final p = predictExpiry(item('Mutfak havlusu'), now);
      expect(p.risk, ExpiryRisk.unknown);
      expect(p.confidence, PredictionConfidence.none);
      expect(p.date, isNull);
      expect(p.headline, 'Tahmin için bilgi yok');
    });
  });

  test('Ranking puts the most urgent first and unknown last', () {
    final ranked = rankByUrgency([
      item('Mutfak havlusu'),
      item('Pirinç', location: 'Kiler'),
      item('Yoğurt', expires: DateTime(2026, 11, 15)),
      item('Ekmek', location: 'Kiler'),
    ], now);
    expect(ranked.map((r) => r.$1.name).toList(), [
      'Yoğurt',
      'Ekmek',
      'Pirinç',
      'Mutfak havlusu',
    ]);
  });
}
