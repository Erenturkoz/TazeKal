import 'package:flutter_test/flutter_test.dart';
import 'package:taze_kal/domain/product.dart';
import 'package:taze_kal/domain/reminder.dart';

Product sample({DateTime? opened, int? days, String status = 'active'}) =>
    Product(
      id: 'milk',
      name: 'Süt',
      quantity: '1 L',
      location: 'Buzdolabı',
      purchasedAt: DateTime(2026, 10, 20),
      expiresAt: DateTime(2026, 10, 26),
      openedAt: opened,
      afterOpeningDays: days,
      status: status,
    );

void main() {
  test('3, 2, 1, son gün ve geçme hesapları', () {
    for (var day = 23; day <= 27; day++) {
      expect(sample().daysLeft(DateTime(2026, 10, day, 23, 59)), 26 - day);
    }
  });
  test('Açılma süresi daha erkense onu kullanır', () {
    expect(
      sample(opened: DateTime(2026, 10, 20), days: 3).effectiveExpiry,
      DateTime(2026, 10, 23),
    );
  });
  test('Açılma ambalaj tarihini ileri taşımaz', () {
    expect(
      sample(opened: DateTime(2026, 10, 25), days: 3).effectiveExpiry,
      DateTime(2026, 10, 26),
    );
  });
  test('Açılmamış ürünün süresi başlamaz', () {
    expect(sample(days: 3).effectiveExpiry, DateTime(2026, 10, 26));
  });
  test('Veritabanı dönüşümü alanları korur', () {
    final p = sample(opened: DateTime(2026, 10, 20), days: 3);
    expect(Product.fromMap(p.toMap()).toMap(), p.toMap());
  });
  test('Hatırlatmalar beş aşamada ve seçilen saatte', () {
    final rows = buildReminders([sample()], DateTime(2026, 10, 22), 10, 15);
    expect(rows.map((r) => r.daysLeft), [3, 2, 1, 0, -1]);
    expect(rows.first.at, DateTime(2026, 10, 23, 10, 15));
    expect(rows.last.message, contains('bozulmuş olabilir'));
  });
  test('Geçmiş saati yeniden bildirmez, tüketilenler planlanmaz', () {
    expect(
      buildReminders([sample()], DateTime(2026, 10, 23, 11), 10, 0).length,
      4,
    );
    expect(
      buildReminders(
        [sample(status: 'consumed')],
        DateTime(2026, 10, 22),
        10,
        0,
      ),
      isEmpty,
    );
  });
  test('Açılma yeni planın tarihini değiştirir', () {
    final rows = buildReminders(
      [sample(opened: DateTime(2026, 10, 20), days: 3)],
      DateTime(2026, 10, 19),
      10,
      0,
    );
    expect(rows.first.at, DateTime(2026, 10, 20, 10));
    expect(rows.last.at, DateTime(2026, 10, 24, 10));
  });
  test('Artık yıl ve yıl geçişi takvim hesabı', () {
    expect(addCalendarDays(DateTime(2028, 2, 28), 2), DateTime(2028, 3, 1));
    expect(addCalendarDays(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 1));
  });
}
