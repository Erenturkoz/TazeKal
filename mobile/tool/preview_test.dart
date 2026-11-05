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
    final fonts = FontLoader('Roboto');
    for (final name in [
      'roboto-regular.ttf',
      'roboto-bold.ttf',
      'roboto-medium.ttf',
    ]) {
      fonts.addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '$sdk/bin/cache/artifacts/material_fonts/$name',
            ).readAsBytesSync(),
          ),
        ),
      );
    }
    await fonts.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '$sdk/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
            ).readAsBytesSync(),
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
    final repo = MemoryRepository(), now = calendarDay(DateTime.now());
    final samples = [
      ('Günlük süt', '1 litre', 'Buzdolabı', 1),
      ('Avokado', '2 adet', 'Buzdolabı', 2),
      ('Baldo pirinç', '1 kg', 'Kiler', 200),
      ('Bezelye', '450 g', 'Dondurucu', 120),
    ];
    for (final (name, quantity, location, days) in samples) {
      await repo.save(
        Product(
          id: name,
          name: name,
          quantity: quantity,
          location: location,
          purchasedAt: now,
          expiresAt: addCalendarDays(now, days),
          afterOpeningDays: name == 'Günlük süt' ? 3 : null,
        ),
      );
    }
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: TazeKalApp(repository: repo, notifications: FakeNotifications()),
      ),
    );
    await tester.pumpAndSettle();
    Future<void> capture(String name) async {
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

    await capture('mutfagim');
    await tester.scrollUntilVisible(
      find.text('Günlük süt'),
      140,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await capture('urunler');
    await tester.scrollUntilVisible(
      find.text('Kiler'),
      -160,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kiler'));
    await tester.pumpAndSettle();
    await capture('kiler');
    expect(tester.takeException(), isNull);
    debugDisableShadows = true;
    await tester.pumpWidget(const SizedBox());
  });
}
