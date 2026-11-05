import 'package:flutter/material.dart';

abstract final class TazeTheme {
  static const green = Color(0xff245b43);
  static ThemeData create(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: green,
      brightness: brightness,
      primary: dark ? const Color(0xff9bd5b2) : green,
      surface: dark ? const Color(0xff14211c) : const Color(0xfff7f8f3),
    );
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Roboto',
    );
    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: base.textTheme.copyWith(
        headlineLarge: base.textTheme.headlineLarge?.copyWith(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          height: 1.16,
          letterSpacing: -1.2,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -.8,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontSize: 21,
          fontWeight: FontWeight.w700,
          letterSpacing: -.4,
        ),
        titleMedium: base.textTheme.titleMedium?.copyWith(
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(
          fontSize: 14,
          height: 1.5,
        ),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(
          fontSize: 16,
          height: 1.45,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xff20322a) : Colors.white,
        contentPadding: const EdgeInsets.all(18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: .5),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xff1c2d24) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: dark
            ? const Color(0xff354e3d)
            : const Color(0xffe7efdf),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: dark
            ? const Color(0xff1c2d24)
            : const Color(0xfff7f8f3),
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

class StorageStyle {
  const StorageStyle(
    this.name,
    this.label,
    this.icon,
    this.accent,
    this.tint,
    this.description,
  );
  final String name, label, description;
  final IconData icon;
  final Color accent, tint;
  static const all = StorageStyle(
    'Tümü',
    'Mutfağım',
    Icons.grid_view_rounded,
    Color(0xff245b43),
    Color(0xffe8efdf),
    'Her şey yerli yerinde.',
  );
  static const fridge = StorageStyle(
    'Buzdolabı',
    'Buzdolabım',
    Icons.kitchen_outlined,
    Color(0xff35684d),
    Color(0xffe4eee3),
    'Günlük tazelik, elinin altında.',
  );
  static const pantry = StorageStyle(
    'Kiler',
    'Kilerim',
    Icons.shelves,
    Color(0xff885b24),
    Color(0xfff4ead8),
    'Raflarında ne var, bir bakışta gör.',
  );
  static const freezer = StorageStyle(
    'Dondurucu',
    'Dondurucum',
    Icons.ac_unit_rounded,
    Color(0xff366b85),
    Color(0xffe2eff5),
    'Bugünden sakla, yarına hazır ol.',
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
