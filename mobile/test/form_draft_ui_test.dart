import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:taze_kal/design/taze_theme.dart';
import 'package:taze_kal/domain/product.dart';
import 'package:taze_kal/screens/product_form.dart';
import 'package:taze_kal/screens/receipt_screen.dart';
import 'mobile_flow_test.dart' show MemoryRepository;
import 'receipt_flow_test.dart' show FakeScanner;

Widget host(Widget child) => MaterialApp(
  theme: TazeTheme.create(Brightness.light),
  locale: const Locale('tr'),
  supportedLocales: const [Locale('tr')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: child,
);

void main() {
  testWidgets(
    'Restored product dates validate and failed persistence keeps the form and draft',
    (tester) async {
      final repo = MemoryRepository();
      final now = calendarDay(DateTime.now());
      repo.settings['draft:product:new'] = jsonEncode({
        'id': 'draft-milk',
        'name': 'Taslak süt',
        'quantity': '1 L',
        'days': '',
        'purchased': dateKey(now),
        'expiry': dateKey(addCalendarDays(now, 5)),
        'opened': null,
        'location': 'Buzdolabı',
        'cold': false,
      });
      var attempts = 0;
      await tester.pumpWidget(
        host(
          ProductForm(
            repository: repo,
            onSave: (p) async {
              attempts++;
              expect(p.name, 'Taslak süt');
              throw StateError('Disk unavailable');
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Taslağı yükle'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Taslak süt'), findsOneWidget);
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      expect(attempts, 1);
      expect(find.textContaining('Ürün kaydedilemedi.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(
        jsonDecode(repo.settings['draft:product:new']!)['name'],
        'Taslak süt',
      );
    },
  );

  testWidgets(
    'Receipt text and reviewed/excluded rows survive closing and restoring the screen',
    (tester) async {
      final repo = MemoryRepository();
      final p = Product(
        id: 'reviewed-milk',
        name: 'Kontrol edilmiş süt',
        quantity: '1 L',
        location: 'Buzdolabı',
        purchasedAt: DateTime(2026, 11, 1),
        expiresAt: DateTime(2026, 11, 10),
      );
      repo.settings['draft:receipt'] = jsonEncode({
        'text': 'SÜT\nPİRİNÇ',
        'items': [
          {'name': 'SÜT', 'quantity': '1 adet'},
          {'name': 'PİRİNÇ', 'quantity': '1 adet'},
        ],
        'reviewed': {'0': p.toMap()},
        'excluded': [1],
      });
      await tester.pumpWidget(
        host(
          ReceiptScreen(
            scanner: FakeScanner(),
            repository: repo,
            onSave: (_) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Taslağı yükle'));
      await tester.pumpAndSettle();
      expect(find.text('Kontrol edilmiş süt'), findsOneWidget);
      expect(find.text('Eklenmeyecek'), findsOneWidget);
      expect(find.textContaining('Ürünler'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(
        jsonDecode(repo.settings['draft:receipt']!)['reviewed']['0']['id'],
        'reviewed-milk',
      );
    },
  );
}
