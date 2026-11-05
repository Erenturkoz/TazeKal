import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taze_kal/design/taze_theme.dart';
import 'package:taze_kal/screens/product_form.dart';
import 'package:taze_kal/domain/product.dart';

Widget host({
  Brightness brightness = Brightness.light,
  double scale = 1,
  Future<void> Function(Product)? onSave,
  Product? product,
}) => MaterialApp(
  theme: TazeTheme.create(brightness),
  locale: const Locale('tr'),
  supportedLocales: const [Locale('tr')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
    child: child!,
  ),
  home: ProductForm(
    initialLocation: 'Dondurucu',
    onSave: onSave,
    product: product,
  ),
);

void main() {
  testWidgets(
    'Editing a deliberately undated product does not silently enable an estimate',
    (tester) async {
      final p = Product(
        id: 'undated',
        name: 'Günlük süt',
        quantity: '1 L',
        location: 'Buzdolabı',
        purchasedAt: DateTime.now(),
        expirySource: 'unknown',
      );
      Product? saved;
      await tester.pumpWidget(
        host(
          product: p,
          onSave: (value) async {
            saved = value;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(saved!.expiresAt, isNull);
      expect(saved!.expirySource, 'unknown');
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Empty optional fields save with sensible defaults and no invented expiry',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Product? saved;
      await tester.pumpWidget(
        host(
          onSave: (p) async {
            saved = p;
          },
        ),
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1200),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(saved!.name, 'Yeni ürün');
      expect(saved!.quantity, '1 adet');
      expect(saved!.expiresAt, isNull);
      expect(saved!.expirySource, 'unknown');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets('Product form supports large text in $brightness theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(host(brightness: brightness, scale: 1.8));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -1400),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
