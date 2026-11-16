import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taze_kal/design/taze_icons.dart';

void main() {
  test('ürün adından gıda grubu ikonu seçilir', () {
    expect(foodIconFor('Günlük süt', 'Buzdolabı'), TazeIcon.dairy);
    expect(foodIconFor('İNEK PEYNİRİ', 'Buzdolabı'), TazeIcon.cheese);
    expect(foodIconFor('Dana kıyma', 'Buzdolabı'), TazeIcon.meat);
    expect(foodIconFor('Etli ekmek', 'Kiler'), TazeIcon.bread);
    expect(foodIconFor('Bezelye', 'Dondurucu'), TazeIcon.frozen);
    expect(foodIconFor('Zeytinyağı', 'Kiler'), TazeIcon.canned);
    expect(foodIconFor('Bilinmeyen', 'Kiler'), TazeIcon.pantry);
  });

  testWidgets('tüm ikonlar hatasız çizilir', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Wrap(
          children: [for (final icon in TazeIcon.values) TazeIconView(icon)],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(TazeIconView), findsNWidgets(TazeIcon.values.length));
  });
}
