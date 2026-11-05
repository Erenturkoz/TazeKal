import 'package:flutter_test/flutter_test.dart';
import 'package:taze_kal/domain/product.dart';
import 'package:taze_kal/domain/reminder.dart';

Product milk({
  String? profile = 'milk_uht_v1',
  bool cold = true,
  String location = 'Buzdolabı',
  DateTime? opened,
  DateTime? expiry,
  int? labelDays,
}) => Product(
  id: 'milk',
  name: 'Süt',
  quantity: '1 L',
  location: location,
  purchasedAt: DateTime(2026, 10, 22),
  expiresAt: expiry ?? DateTime(2026, 10, 30),
  openedAt: opened,
  openingProfileId: profile,
  coldStorageConfirmed: cold,
  afterOpeningDays: labelDays,
);

void main() {
  final now = DateTime(2026, 10, 25);
  test(
    'Unopened date stays on package date; purchase is not production date',
    () {
      expect(milk().daysLeft(now), 5);
      expect(milk().openingDays, 2);
      expect(milk().openingExpiry, isNull);
      expect(milk().usesOpeningEstimate, isFalse);
    },
  );
  test(
    'Opening automatically shortens window without a user supplied duration',
    () {
      final p = milk(opened: DateTime(2026, 10, 24));
      expect(p.daysLeft(now), 1);
      expect(p.unopenedDaysLeft(now), 5);
      expect(p.usesOpeningEstimate, isTrue);
      expect(p.remainingText(now), 'Tahmini 1 gün kaldı');
      expect(relativeDay(p.purchasedAt, now), '3 gün önce');
      expect(relativeDay(p.openedAt!, now), 'Dün');
      expect(Product.fromMap(p.toMap()).toMap(), p.toMap());
      expect(p.copyWith(status: 'consumed').openingDays, 2);
    },
  );
  test(
    'Label instruction overrides generic rule and package date is never extended',
    () {
      final opened = DateTime(2026, 10, 24);
      expect(milk(opened: opened, labelDays: 3).daysLeft(now), 2);
      expect(milk(opened: opened, labelDays: 1).daysLeft(now), 0);
      expect(
        milk(opened: opened, labelDays: 30, expiry: now).effectiveExpiry,
        now,
      );
    },
  );
  test(
    'Unconfirmed conditions, unknown profiles and storage do not invent a window',
    () {
      for (final p in [
        milk(cold: false, opened: now),
        milk(location: 'Kiler', opened: now),
        milk(location: 'Dondurucu', opened: now),
        milk(profile: null, opened: now),
        milk(profile: 'unknown', opened: now),
      ]) {
        expect(p.hasTrackingDate, isFalse);
        expect(p.remainingText(now), contains('hesaplanamıyor'));
        expect(buildReminders([p], now, 10, 0), isEmpty);
      }
    },
  );
  test(
    'Pasteurized rule differs, expiry and reminder copy remain conditional',
    () {
      final p = milk(profile: 'milk_pasteurized_v1', opened: now);
      expect(p.openingDays, 1);
      expect(p.effectiveExpiry, DateTime(2026, 10, 26));
      final reminders = buildReminders([p], now, 10, 0);
      expect(reminders.first.message, contains('Tahmini'));
      expect(reminders.last.message, contains('bozulmuş olabilir'));
    },
  );
}
