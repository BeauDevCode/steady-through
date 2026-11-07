import 'package:flutter/material.dart';

ThemeData steadyTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final colors =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF21695E),
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xFFA7D8C9) : const Color(0xFF1D655B),
        onPrimary: dark ? const Color(0xFF103B32) : Colors.white,
        primaryContainer: dark
            ? const Color(0xFF254D40)
            : const Color(0xFFDDECE5),
        onPrimaryContainer: dark
            ? const Color(0xFFDDEFE6)
            : const Color(0xFF153F36),
        onSecondary: dark ? const Color(0xFF442514) : Colors.white,
        tertiary: dark ? const Color(0xFFD5C4EF) : const Color(0xFF665681),
        onTertiary: dark ? const Color(0xFF352646) : Colors.white,
        tertiaryContainer: dark
            ? const Color(0xFF403549)
            : const Color(0xFFEAE3F3),
        onTertiaryContainer: dark
            ? const Color(0xFFF0E2FF)
            : const Color(0xFF40304F),
        outline: dark ? const Color(0xFF91A599) : const Color(0xFF748078),
        secondary: dark ? const Color(0xFFF1B58E) : const Color(0xFF9B4E35),
        secondaryContainer: dark
            ? const Color(0xFF51392C)
            : const Color(0xFFF6E4D7),
        onSecondaryContainer: dark
            ? const Color(0xFFFFE4D1)
            : const Color(0xFF613521),
        surface: dark ? const Color(0xFF192A23) : const Color(0xFFFFFEFA),
        onSurface: dark ? const Color(0xFFEAF2EA) : const Color(0xFF21372F),
        onSurfaceVariant: dark
            ? const Color(0xFFB8C9BE)
            : const Color(0xFF52635A),
        outlineVariant: dark
            ? const Color(0xFF435A4F)
            : const Color(0xFFDCE2DB),
        surfaceContainerLow: dark
            ? const Color(0xFF20362D)
            : const Color(0xFFF0F2EA),
        surfaceContainerHighest: dark
            ? const Color(0xFF304B3E)
            : const Color(0xFFE8EDE4),
      );
  final base = ThemeData(useMaterial3: true, colorScheme: colors);
  final text = base.textTheme.apply(fontFamily: 'Manrope');
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  return base.copyWith(
    scaffoldBackgroundColor: dark
        ? const Color(0xFF101D19)
        : const Color(0xFFF6F4EF),
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
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 16, height: 1.55),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 14, height: 1.55),
      labelLarge: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    ),
    cardTheme: CardThemeData(
      color: colors.surface,
      elevation: .4,
      shadowColor: colors.primary.withValues(alpha: .09),
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .7)),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF101D19) : const Color(0xFFF6F4EF),
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
      style:
          FilledButton.styleFrom(
            minimumSize: const Size(48, 50),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            shape: shape,
          ).copyWith(
            side: WidgetStateProperty.resolveWith(
              (states) => BorderSide(
                color: states.contains(WidgetState.focused)
                    ? colors.onPrimary
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style:
          OutlinedButton.styleFrom(
            minimumSize: const Size(48, 50),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: shape,
            side: BorderSide(color: colors.outline),
          ).copyWith(
            side: WidgetStateProperty.resolveWith(
              (states) => BorderSide(
                color: states.contains(WidgetState.focused)
                    ? colors.primary
                    : colors.outline,
                width: states.contains(WidgetState.focused) ? 2 : 1,
              ),
            ),
          ),
    ),
    textButtonTheme: TextButtonThemeData(
      style:
          TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: shape,
          ).copyWith(
            side: WidgetStateProperty.resolveWith(
              (states) => BorderSide(
                color: states.contains(WidgetState.focused)
                    ? colors.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
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
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.primary, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
    ),
    dividerTheme: DividerThemeData(color: colors.outlineVariant, space: 32),
    navigationBarTheme: NavigationBarThemeData(
      height: 78,
      surfaceTintColor: Colors.transparent,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
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
      backgroundColor: Colors.transparent,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
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
