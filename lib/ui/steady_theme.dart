import 'package:flutter/material.dart';

ThemeData steadyTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colors =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF28675C),
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xFFA6D7C1) : const Color(0xFF246354),
        onPrimary: dark ? const Color(0xFF143D31) : Colors.white,
        primaryContainer: dark
            ? const Color(0xFF284B3C)
            : const Color(0xFFE0EDE3),
        onPrimaryContainer: dark
            ? const Color(0xFFDDEFE2)
            : const Color(0xFF244D3B),
        secondary: dark ? const Color(0xFFF1B58E) : const Color(0xFF9C4E31),
        secondaryContainer: dark
            ? const Color(0xFF4B382A)
            : const Color(0xFFF7E3D5),
        onSecondaryContainer: dark
            ? const Color(0xFFFFE4D1)
            : const Color(0xFF753A25),
        surface: dark ? const Color(0xFF182820) : const Color(0xFFFFFDF8),
        onSurface: dark ? const Color(0xFFEAF0E6) : const Color(0xFF213B30),
        onSurfaceVariant: dark
            ? const Color(0xFFB3C2B6)
            : const Color(0xFF536357),
        outlineVariant: dark
            ? const Color(0xFF3A4D40)
            : const Color(0xFFDFE5DB),
        surfaceContainerLow: dark
            ? const Color(0xFF203127)
            : const Color(0xFFF0F3E9),
        surfaceContainerHighest: dark
            ? const Color(0xFF304236)
            : const Color(0xFFE8EDE2),
      );
  final base = ThemeData(useMaterial3: true, colorScheme: colors);
  final text = base.textTheme.apply(fontFamily: 'Manrope');
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  return base.copyWith(
    scaffoldBackgroundColor: dark
        ? const Color(0xFF101F18)
        : const Color(0xFFF6F5EF),
    textTheme: text.copyWith(
      displaySmall: text.displaySmall?.copyWith(
        fontSize: 46,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.6,
        height: 1.15,
      ),
      headlineLarge: text.headlineLarge?.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.1,
        height: 1.2,
      ),
      headlineMedium: text.headlineMedium?.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.7,
        height: 1.25,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: text.titleLarge?.copyWith(
        fontSize: 21,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleMedium: text.titleMedium?.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 16, height: 1.65),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 1.6),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .7)),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF101F18) : const Color(0xFFF6F5EF),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: 76,
      titleSpacing: 24,
      titleTextStyle: text.titleLarge?.copyWith(
        color: colors.onSurface,
        fontWeight: FontWeight.w700,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: shape,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: shape,
        side: BorderSide(color: colors.outlineVariant),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: shape,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colors.surface,
      contentPadding: const EdgeInsets.all(18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
    ),
    dividerTheme: DividerThemeData(color: colors.outlineVariant, space: 32),
    navigationBarTheme: NavigationBarThemeData(
      height: 80,
      elevation: 0,
      backgroundColor: colors.surface,
      indicatorColor: colors.primaryContainer,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? colors.primary
              : colors.onSurfaceVariant,
        ),
      ),
      labelTextStyle: WidgetStatePropertyAll(
        text.labelSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: colors.surface,
      indicatorColor: colors.primaryContainer,
      selectedIconTheme: IconThemeData(color: colors.primary),
      unselectedIconTheme: IconThemeData(color: colors.onSurfaceVariant),
      selectedLabelTextStyle: text.labelLarge?.copyWith(color: colors.primary),
      unselectedLabelTextStyle: text.labelLarge?.copyWith(
        color: colors.onSurfaceVariant,
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
