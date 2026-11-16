import 'package:flutter/material.dart';

/// 4 dp tabanlı aralık ölçeği. Ekranlarda serbest sayı yerine bunlar kullanılır.
abstract final class TazeSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Ekran kenarı boşluğu.
  static const page = 20.0;
}

/// Köşe yarıçapları: küçük öğe, kart, büyük yüzey.
abstract final class TazeRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 28.0;
}

/// Uyarı renkleri depolama renklerinden bağımsızdır ve hep metin/ikonla birlikte
/// kullanılır; renk tek başına anlam taşımaz.
@immutable
class TazeStatusColors extends ThemeExtension<TazeStatusColors> {
  const TazeStatusColors({
    required this.caution,
    required this.onCautionContainer,
    required this.cautionContainer,
    required this.danger,
    required this.dangerContainer,
    required this.onDangerContainer,
    required this.card,
  });
  final Color caution, cautionContainer, onCautionContainer;
  final Color danger, dangerContainer, onDangerContainer;

  /// Liste kartları ve özet yüzeyi.
  final Color card;

  static const light = TazeStatusColors(
    caution: Color(0xff8a5a1c),
    cautionContainer: Color(0xfff6ead6),
    onCautionContainer: Color(0xff5c3a0e),
    danger: Color(0xffa2382b),
    dangerContainer: Color(0xfff8e1dc),
    onDangerContainer: Color(0xff6e1f16),
    card: Colors.white,
  );
  static const dark = TazeStatusColors(
    caution: Color(0xffedc17e),
    cautionContainer: Color(0xff3d2f1c),
    onCautionContainer: Color(0xfff6dcb3),
    danger: Color(0xffffb4a8),
    dangerContainer: Color(0xff4a2420),
    onDangerContainer: Color(0xffffdad4),
    card: Color(0xff1b2a23),
  );

  static TazeStatusColors of(BuildContext context) =>
      Theme.of(context).extension<TazeStatusColors>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  @override
  TazeStatusColors copyWith() => this;

  @override
  TazeStatusColors lerp(TazeStatusColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return TazeStatusColors(
      caution: mix(caution, other.caution),
      cautionContainer: mix(cautionContainer, other.cautionContainer),
      onCautionContainer: mix(onCautionContainer, other.onCautionContainer),
      danger: mix(danger, other.danger),
      dangerContainer: mix(dangerContainer, other.dangerContainer),
      onDangerContainer: mix(onDangerContainer, other.onDangerContainer),
      card: mix(card, other.card),
    );
  }
}

abstract final class TazeTheme {
  static const green = Color(0xff245b43);
  static ThemeData create(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final status = dark ? TazeStatusColors.dark : TazeStatusColors.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: green,
      brightness: brightness,
      primary: dark ? const Color(0xff9bd5b2) : green,
      surface: dark ? const Color(0xff14211c) : const Color(0xfff7f8f3),
      error: status.danger,
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Roboto',
    );
    final text = base.textTheme;
    final outline = scheme.outlineVariant.withValues(alpha: .6);
    final field = OutlineInputBorder(
      borderRadius: BorderRadius.circular(TazeRadius.md),
      borderSide: BorderSide(color: outline),
    );
    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(TazeRadius.md),
    );
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      extensions: [status],
      // Tek ölçek: 28 / 22 / 18 / 16 / 14 / 13 / 12. 12'nin altı kullanılmaz.
      textTheme: text.copyWith(
        headlineLarge: text.headlineLarge?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          height: 1.2,
          letterSpacing: -.6,
        ),
        headlineMedium: text.headlineMedium?.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.25,
          letterSpacing: -.4,
        ),
        headlineSmall: text.headlineSmall?.copyWith(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: -.3,
        ),
        titleLarge: text.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -.2,
        ),
        titleMedium: text.titleMedium?.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        titleSmall: text.titleSmall?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: text.bodyLarge?.copyWith(fontSize: 16, height: 1.45),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
        bodySmall: text.bodySmall?.copyWith(
          fontSize: 13,
          height: 1.4,
          color: scheme.onSurfaceVariant,
        ),
        labelLarge: text.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: text.labelMedium?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: status.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TazeRadius.lg),
          side: BorderSide(color: outline),
        ),
      ),
      dividerTheme: DividerThemeData(color: outline, space: 1, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: status.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: TazeSpace.lg,
          vertical: TazeSpace.lg,
        ),
        border: field,
        enabledBorder: field,
        disabledBorder: field,
        focusedBorder: field.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: field.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: TazeSpace.xl),
          shape: buttonShape,
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: TazeSpace.xl),
          shape: buttonShape,
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: buttonShape,
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: status.card,
        selectedColor: scheme.secondaryContainer,
        side: BorderSide(color: outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TazeRadius.sm),
        ),
        labelStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        padding: const EdgeInsets.symmetric(horizontal: TazeSpace.xs),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TazeRadius.md),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: status.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorColor: scheme.secondaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: 'Roboto',
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(TazeRadius.xl),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TazeRadius.xl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TazeRadius.md),
        ),
      ),
    );
  }
}

class StorageStyle {
  const StorageStyle(this.name, this.icon, this.accent, this.tint);
  final String name;
  final IconData icon;
  final Color accent, tint;
  static const all = StorageStyle(
    'Tümü',
    Icons.grid_view_rounded,
    Color(0xff245b43),
    Color(0xffe8efdf),
  );
  static const fridge = StorageStyle(
    'Buzdolabı',
    Icons.kitchen_outlined,
    Color(0xff35684d),
    Color(0xffe4eee3),
  );
  static const pantry = StorageStyle(
    'Kiler',
    Icons.shelves,
    Color(0xff885b24),
    Color(0xfff4ead8),
  );
  static const freezer = StorageStyle(
    'Dondurucu',
    Icons.ac_unit_rounded,
    Color(0xff366b85),
    Color(0xffe2eff5),
  );
  static const values = [all, fridge, pantry, freezer];
  static StorageStyle of(String name) =>
      values.firstWhere((s) => s.name == name, orElse: () => all);
  Color foreground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Color.lerp(accent, Colors.white, .60)!
      : accent;
  Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? Color.lerp(accent, const Color(0xff14211c), .76)!
      : tint;
}
