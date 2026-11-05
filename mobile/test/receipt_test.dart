import 'package:flutter_test/flutter_test.dart';
import 'package:taze_kal/domain/receipt.dart';

void main() {
  test(
    'Turkish receipt removes totals, payment, tax and prices, preserving package size',
    () {
      final items = parseReceipt('''FİŞ NO: 123
TARİH: 25.10.2026
SÜT 1 L %1 *42,50
2 x YOĞURT 500G 80,00
PİRİNÇ 1 KG 59,90 TL
TOPLAM 182,40
KDV 2,00
KREDİ KARTI 182,40
TEŞEKKÜRLER
2 x 12,50
0532 123 45 67''');
      expect(items.map((e) => e.name), [
        'SÜT 1 L',
        'YOĞURT 500G',
        'PİRİNÇ 1 KG',
      ]);
      expect(items[1].quantity, '2 adet');
    },
  );
  test('Repeated items remain separate and plain product text works', () {
    final items = parseReceipt('Süt\r\nSüt\nPirinç\n');
    expect(items.map((e) => e.name), ['Süt', 'Süt', 'Pirinç']);
    expect(parseReceipt('TOPLAM 12,00\n12,00\n'), isEmpty);
  });
}
