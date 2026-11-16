import 'dart:math' as math;
import 'package:flutter/material.dart';

part 'taze_icon_paths.dart';

/// Taze Kal'ın kendi çizgi ikonları. Kaynak SVG'ler `design/icons/` altında.
enum TazeIcon {
  all,
  fridge,
  pantry,
  freezer,
  dairy,
  cheese,
  egg,
  meat,
  fish,
  fruit,
  vegetable,
  bread,
  grain,
  drink,
  canned,
  frozen,
  other,
  soon,
  today,
  expired,
  noDate,
  consumed,
  opened,
  emptyKitchen,
  noResults,
  allGood,
  history,
  bell,
  bellOff,
  user,
  search,
  sort,
  check,
  plus,
  receipt,
  edit,
  brand,
}

/// [Icon] gibi davranır: rengi ve boyutu [IconTheme]'den alır.
class TazeIconView extends StatelessWidget {
  const TazeIconView(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.strokeWidth = 1.75,
    this.semanticLabel,
  });
  final TazeIcon icon;
  final double? size;
  final Color? color;
  final double strokeWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final side = size ?? theme.size ?? 24;
    final paint = CustomPaint(
      size: Size.square(side),
      painter: _IconPainter(
        _parsed(icon),
        color ?? theme.color ?? const Color(0xff18211c),
        strokeWidth,
      ),
    );
    return semanticLabel == null
        ? ExcludeSemantics(child: paint)
        : Semantics(label: semanticLabel, image: true, child: paint);
  }
}

final _cache = <TazeIcon, Path>{};
Path _parsed(TazeIcon icon) =>
    _cache.putIfAbsent(icon, () => parseSvgPath(_paths[icon]!));

class _IconPainter extends CustomPainter {
  _IconPainter(this.path, this.color, this.strokeWidth);
  final Path path;
  final Color color;
  final double strokeWidth;
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.scale(scale);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_IconPainter old) =>
      old.path != path || old.color != color || old.strokeWidth != strokeWidth;
}

/// Yalnızca ikon setinde kullanılan SVG komutları: M L H V C A Z (büyük ve
/// küçük harf).
Path parseSvgPath(String data) {
  final tokens = RegExp(
    r'[MLHVCAZmlhvcaz]|-?(?:\d+\.?\d*|\.\d+)',
  ).allMatches(data).map((m) => m.group(0)!).toList();
  final path = Path();
  var i = 0, cmd = 'M';
  var x = 0.0, y = 0.0, startX = 0.0, startY = 0.0;
  double next() => double.parse(tokens[i++]);
  bool hasNumber() =>
      i < tokens.length && !RegExp(r'^[A-Za-z]$').hasMatch(tokens[i]);
  while (i < tokens.length) {
    if (!hasNumber()) cmd = tokens[i++];
    final rel = cmd == cmd.toLowerCase();
    switch (cmd.toUpperCase()) {
      case 'M':
        x = (rel ? x : 0) + next();
        y = (rel ? y : 0) + next();
        path.moveTo(x, y);
        startX = x;
        startY = y;
        cmd = rel ? 'l' : 'L';
      case 'L':
        x = (rel ? x : 0) + next();
        y = (rel ? y : 0) + next();
        path.lineTo(x, y);
      case 'H':
        x = (rel ? x : 0) + next();
        path.lineTo(x, y);
      case 'V':
        y = (rel ? y : 0) + next();
        path.lineTo(x, y);
      case 'C':
        final c = [for (var k = 0; k < 6; k++) next()];
        final ox = rel ? x : 0.0, oy = rel ? y : 0.0;
        path.cubicTo(
          ox + c[0],
          oy + c[1],
          ox + c[2],
          oy + c[3],
          ox + c[4],
          oy + c[5],
        );
        x = ox + c[4];
        y = oy + c[5];
      case 'A':
        final rx = next(), ry = next(), rotation = next();
        final large = next() != 0, sweep = next() != 0;
        x = (rel ? x : 0) + next();
        y = (rel ? y : 0) + next();
        path.arcToPoint(
          Offset(x, y),
          radius: Radius.elliptical(rx, ry),
          rotation: rotation * math.pi / 180,
          largeArc: large,
          clockwise: sweep,
        );
      case 'Z':
        path.close();
        x = startX;
        y = startY;
      default:
        throw FormatException('Desteklenmeyen SVG komutu: $cmd');
    }
  }
  return path;
}

/// Ürün adından gıda grubu ikonu. Dondurucudaki ürünler donuk ürün ikonunu
/// alır; tanınmayan ürünler depolama alanının ikonunu kullanır.
TazeIcon foodIconFor(String name, String location) {
  if (location == 'Dondurucu') return TazeIcon.frozen;
  final words = name
      .replaceAll('İ', 'i')
      .replaceAll('I', 'ı')
      .toLowerCase()
      .split(RegExp(r'[^a-zçğıöşü]+'))
      .where((w) => w.isNotEmpty)
      .toList();
  final text = words.join(' ');
  bool any(List<String> keys) =>
      keys.any((k) => words.any((w) => w.startsWith(k)));
  if (text.contains('meyve suyu') ||
      any(['kola', 'gazoz', 'soda', 'ayran', 'kahve', 'çay']) ||
      words.contains('su')) {
    return TazeIcon.drink;
  }
  if (any(['peynir', 'kaşar', 'lor', 'labne', 'tulum'])) {
    return TazeIcon.cheese;
  }
  if (any(['süt', 'yoğurt', 'kefir', 'krema', 'tereyağ'])) {
    return TazeIcon.dairy;
  }
  if (any(['yumurta'])) return TazeIcon.egg;
  if (any(['balık', 'somon', 'hamsi', 'levrek', 'çipura', 'karides']) ||
      words.contains('ton')) {
    return TazeIcon.fish;
  }
  if (any([
        'kıyma',
        'tavuk',
        'hindi',
        'sucuk',
        'salam',
        'sosis',
        'köfte',
        'pastırma',
        'biftek',
        'kuzu',
        'dana',
      ]) ||
      words.contains('et')) {
    return TazeIcon.meat;
  }
  if (any([
    'konserve',
    'salça',
    'sos',
    'ketçap',
    'mayonez',
    'hardal',
    'zeytin',
    'yağ',
    'bal',
    'reçel',
    'turşu',
    'sirke',
  ])) {
    return TazeIcon.canned;
  }
  if (any([
    'elma',
    'armut',
    'muz',
    'portakal',
    'mandalina',
    'limon',
    'çilek',
    'üzüm',
    'kiraz',
    'avokado',
    'karpuz',
    'kavun',
    'şeftali',
    'kayısı',
    'nar',
    'kivi',
    'ananas',
  ])) {
    return TazeIcon.fruit;
  }
  if (any([
    'domates',
    'salatalık',
    'biber',
    'patlıcan',
    'kabak',
    'havuç',
    'soğan',
    'sarımsak',
    'patates',
    'ıspanak',
    'marul',
    'maydanoz',
    'brokoli',
    'karnabahar',
    'lahana',
    'roka',
    'dereotu',
  ])) {
    return TazeIcon.vegetable;
  }
  if (any([
    'ekmek',
    'simit',
    'poğaça',
    'lavaş',
    'yufka',
    'kek',
    'bisküvi',
    'kraker',
  ])) {
    return TazeIcon.bread;
  }
  if (any([
        'pirinç',
        'bulgur',
        'makarna',
        'mercimek',
        'nohut',
        'fasulye',
        'yulaf',
        'irmik',
        'şehriye',
        'kinoa',
      ]) ||
      words.contains('un')) {
    return TazeIcon.grain;
  }
  return switch (location) {
    'Buzdolabı' => TazeIcon.fridge,
    'Kiler' => TazeIcon.pantry,
    _ => TazeIcon.other,
  };
}
