import 'product.dart';

class Reminder {
  const Reminder(this.product, this.at, this.daysLeft);
  final Product product;
  final DateTime at;
  final int daysLeft;
  String get message => daysLeft < 0
      ? '${product.name}: Bu ürün bozulmuş olabilir. ${product.usesEstimate ? 'Tahmini tüketim süresi' : 'Tüketim süresi'} geçti.'
      : daysLeft == 0
      ? '${product.name}: ${product.usesEstimate ? 'Tahmini tüketim süresi' : 'Tüketim süresi'} bugün doluyor.'
      : '${product.name}: ${product.usesEstimate ? 'Tahmini tüketim süresine' : 'Tüketim süresine'} $daysLeft gün kaldı.';
}

List<Reminder> buildReminders(
  List<Product> products,
  DateTime now,
  int hour,
  int minute,
) {
  final result = <Reminder>[];
  for (final p in products.where((p) => p.status == 'active')) {
    if (!p.hasTrackingDate) continue;
    for (final days in [3, 2, 1, 0, -1]) {
      final date = addCalendarDays(p.effectiveExpiry!, -days);
      final at = DateTime(date.year, date.month, date.day, hour, minute);
      if (at.isAfter(now)) result.add(Reminder(p, at, days));
    }
  }
  result.sort((a, b) => a.at.compareTo(b.at));
  return result;
}
