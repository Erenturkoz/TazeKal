import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taze_kal/domain/product.dart';
import 'package:taze_kal/widgets/shelf_life_panel.dart';

Future<void> pump(WidgetTester tester, Product product) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: ShelfLifePanel(
        product: product,
        now: DateTime(2026, 11, 16),
        showSource: true,
      ),
    ),
  ),
);

Product undated(String name, {String location = 'Buzdolabı'}) => Product(
  id: name,
  name: name,
  quantity: '1',
  location: location,
  purchasedAt: DateTime(2026, 11, 14),
);

void main() {
  testWidgets('Undated product shows a labelled category guess', (
    tester,
  ) async {
    await pump(tester, undated('Yoğurt'));
    expect(
      find.text('Tahmini 5 gün var • Kontrol tarihi: 21.11.2026'),
      findsOneWidget,
    );
    expect(find.textContaining('Düşük güven'), findsOneWidget);
    expect(find.textContaining('Bildirim gönderilmez'), findsOneWidget);

    await tester.tap(find.text('Nasıl hesaplandı?'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('tahmin edilen grup: Yoğurt / ayran / kefir'),
      findsOneWidget,
    );
  });

  testWidgets('Dated or unknown products show no guess', (tester) async {
    await pump(
      tester,
      Product(
        id: 'y',
        name: 'Yoğurt',
        quantity: '1',
        location: 'Buzdolabı',
        purchasedAt: DateTime(2026, 11, 14),
        expiresAt: DateTime(2026, 11, 20),
      ),
    );
    expect(find.byKey(const Key('category-guess')), findsNothing);

    await pump(tester, undated('Mutfak havlusu'));
    expect(find.byKey(const Key('category-guess')), findsNothing);
  });
}
