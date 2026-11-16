// Run with `flutter test tool/preview_test.dart`. Preview data stays in memory.
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taze_kal/app.dart';
import 'package:taze_kal/domain/product.dart';
import '../test/mobile_flow_test.dart' show MemoryRepository, FakeNotifications;

void main() {
  testWidgets('Render interface previews without changing device data', (
    tester,
  ) async {
    final config = File('.dart_tool/package_config.json').absolute;
    final packages = jsonDecode(config.readAsStringSync())['packages'] as List;
    final flutterPackage = packages.firstWhere((p) => p['name'] == 'flutter');
    final sdk = Directory.fromUri(
      config.uri.resolve(flutterPackage['rootUri'] as String),
    ).parent.parent.path;
    // SDK sürümüne göre dosya adları büyük/küçük harf farklı olabilir.
    final fontDir = Directory('$sdk/bin/cache/artifacts/material_fonts');
    File font(String name) => fontDir.listSync().whereType<File>().firstWhere(
      (f) => f.uri.pathSegments.last.toLowerCase() == name,
    );
    final fonts = FontLoader('Roboto');
    for (final name in [
      'roboto-regular.ttf',
      'roboto-bold.ttf',
      'roboto-medium.ttf',
    ]) {
      fonts.addFont(
        Future.value(ByteData.sublistView(font(name).readAsBytesSync())),
      );
    }
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            font('materialicons-regular.otf').readAsBytesSync(),
          ),
        ),
      );
    await icons.load();
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = true);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final now = calendarDay(DateTime.now());
    Future<MemoryRepository> stocked() async {
      final repo = MemoryRepository();
      final samples = [
        ('Günlük süt', '1 litre', 'Buzdolabı', 1),
        ('Avokado', '2 adet', 'Buzdolabı', 2),
        ('Baldo pirinç', '1 kg', 'Kiler', 200),
        ('Bezelye', '450 g', 'Dondurucu', 120),
        ('Yoğurt', '500 g', 'Buzdolabı', -1),
      ];
      for (final (name, quantity, location, days) in samples) {
        await repo.save(
          Product(
            id: name,
            name: name,
            quantity: quantity,
            location: location,
            purchasedAt: addCalendarDays(now, -3),
            expiresAt: addCalendarDays(now, days),
            afterOpeningDays: name == 'Günlük süt' ? 3 : null,
          ),
        );
      }
      await repo.save(
        Product(
          id: 'Zeytinyağı',
          name: 'Zeytinyağı',
          quantity: '1 şişe',
          location: 'Kiler',
          purchasedAt: now,
        ),
      );
      return repo;
    }

    final key = GlobalKey();
    Future<void> show(
      MemoryRepository repo, {
      Brightness brightness = Brightness.light,
      double textScale = 1,
    }) async {
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: TazeKalApp(
            repository: repo,
            notifications: FakeNotifications(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull, reason: name);
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('design/previews/$name.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(data!.buffer.asUint8List());
        image.dispose();
      });
    }

    Future<void> scrollTo(String text, double delta) async {
      await tester.scrollUntilVisible(
        find.text(text),
        delta,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
    }

    await show(MemoryRepository());
    await capture('bos-mutfak');

    await show(await stocked());
    await capture('mutfagim');
    await scrollTo('Zeytinyağı', 140);
    await capture('urunler');
    await scrollTo('Kiler', -160);
    await tester.tap(find.text('Kiler').first);
    await tester.pumpAndSettle();
    await capture('kiler');
    await tester.tap(find.text('Hatırlatmalar'));
    await tester.pumpAndSettle();
    await capture('hatirlatmalar');
    await tester.tap(find.text('Geçmiş'));
    await tester.pumpAndSettle();
    await capture('gecmis');
    await tester.tap(find.text('Mutfağım'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ürün ekle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elle ürün ekle'));
    await tester.pumpAndSettle();
    await capture('urun-formu');

    await show(await stocked(), brightness: Brightness.dark);
    await capture('mutfagim-koyu');

    await show(await stocked(), textScale: 1.6);
    await capture('buyuk-metin');
    await scrollTo('Bezelye', 200);
    await capture('buyuk-metin-urunler');

    debugDisableShadows = true;
    await tester.pumpWidget(const SizedBox());
  });
}
