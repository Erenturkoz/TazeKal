import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taze_kal/design/taze_theme.dart';
import 'package:taze_kal/domain/product.dart';
import 'package:taze_kal/screens/receipt_screen.dart';
import 'package:taze_kal/services/receipt_scanner.dart';

class FakeScanner implements ReceiptScanner {
  String? result = 'SÜT 1 L 42,50\nYOĞURT 80,00\nTOPLAM 122,50';
  bool fail = false;
  @override
  Future<String?> scan(ReceiptSource source) async {
    if (fail) throw StateError('Camera unavailable');
    return result;
  }

  @override
  Future<String?> recover() async => null;
}

Widget host(ReceiptScreen screen) => MaterialApp(
  theme: TazeTheme.create(Brightness.light),
  locale: const Locale('tr'),
  supportedLocales: const [Locale('tr')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: screen,
);

void main() {
  testWidgets(
    'Scan, exclude row, confirm expiry then save; failed save preserves reviewed data',
    (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      List<Product> saved = [];
      var attempts = 0;
      await tester.pumpWidget(
        host(
          ReceiptScreen(
            scanner: FakeScanner(),
            initialLocation: 'Kiler',
            onSave: (products) async {
              attempts++;
              if (attempts == 1) throw StateError('Disk failure');
              saved = products;
            },
          ),
        ),
      );
      await tester.tap(find.text('Kamerayla fişi tara'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ürün listesini hazırla'));
      await tester.pumpAndSettle();
      expect(find.text('TOPLAM'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, '2 ürünü stoka ekle'),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bilgileri düzenle'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Son tüketim tarihi'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await Scrollable.ensureVisible(
        tester.element(find.text('Son tüketim tarihi')),
        alignment: .5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Son tüketim tarihi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tamam'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(saved, isEmpty);
      expect(find.text('1 / 1 ürün hazır'), findsOneWidget);
      await tester.tap(find.text('1 ürünü stoka ekle'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Ürünler kaydedilemedi'), findsOneWidget);
      expect(find.text('1 / 1 ürün hazır'), findsOneWidget);
      await tester.tap(find.text('1 ürünü stoka ekle'));
      await tester.pumpAndSettle();
      expect(saved.single.name, 'SÜT 1 L');
      expect(saved.single.location, 'Kiler');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Camera cancellation preserves typed text and scan failures permit manual entry',
    (tester) async {
      final scanner = FakeScanner()..result = null;
      await tester.pumpWidget(
        host(ReceiptScreen(scanner: scanner, onSave: (_) async {})),
      );
      await tester.enterText(find.byType(TextField), 'Pirinç');
      await tester.tap(find.text('Kamerayla fişi tara'));
      await tester.pumpAndSettle();
      expect(find.text('Pirinç'), findsOneWidget);
      scanner.fail = true;
      await tester.tap(find.text('Galeriden fiş seç'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Fotoğraf okunamadı'), findsOneWidget);
      await tester.tap(find.text('Ürün listesini hazırla'));
      await tester.pumpAndSettle();
      expect(find.text('Pirinç'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
