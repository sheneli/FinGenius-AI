import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Material 3 themes built from FgTokens. Dark is the product default.
///
/// Both themes are built once and reused. They are pure functions of the
/// tokens, but the root widget rebuilds whenever the signed-in profile stream
/// emits, and each rebuild previously re-ran `ColorScheme.fromSeed` — which
/// derives a full tonal palette — plus a Google Fonts text theme, for *both*
/// brightnesses, on the UI thread. Memoising costs nothing and removes that
/// work from every frame after the first.
abstract final class FgTheme {
  static ThemeData? _darkCache;
  static ThemeData? _lightCache;

  static ThemeData dark() => _darkCache ??= _buildDark();
  static ThemeData light() => _lightCache ??= _buildLight();

  static ThemeData _buildDark() => _base(
        ColorScheme.fromSeed(
          seedColor: FgTokens.green,
          brightness: Brightness.dark,
          primary: FgTokens.green,
          onPrimary: const Color(0xFF122005),
          secondary: FgTokens.cyan,
          onSecondary: const Color(0xFF122005),
          tertiary: FgTokens.gold,
          error: FgTokens.error,
          surface: FgTokens.surfaceDark,
          surfaceContainerHighest: FgTokens.surfaceOverlayDark,
          surfaceContainer: FgTokens.surfaceRaisedDark,
          onSurface: FgTokens.textPrimaryDark,
          onSurfaceVariant: FgTokens.textSecondaryDark,
        ),
      );

  static ThemeData _buildLight() => _base(
        ColorScheme.fromSeed(
          seedColor: FgTokens.green,
          brightness: Brightness.light,
          primary: Color(0xFF4E8F2F),
          secondary: Color(0xFF3D7A5A),
          tertiary: Color(0xFFB8860B),
          error: Color(0xFFC53030),
          surface: FgTokens.surfaceLight,
          surfaceContainer: FgTokens.surfaceRaisedLight,
          onSurface: FgTokens.textPrimaryLight,
          onSurfaceVariant: FgTokens.textSecondaryLight,
        ),
      );

  static ThemeData _base(ColorScheme scheme) {
    final textTheme = GoogleFonts.manropeTextTheme(
      ThemeData(brightness: scheme.brightness).textTheme,
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: FgTokens.e0,
        scrolledUnderElevation: FgTokens.e0,
        centerTitle: false,
        titleTextStyle:
            textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      // Cards carry the layout in a fintech UI: larger radius, hairline
      // border for definition on near-black surfaces, no Material tint.
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: FgTokens.e0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FgTokens.rCard),
          side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.06)),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize:
              const Size(FgTokens.minTouchTarget, FgTokens.controlHeight),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FgTokens.rLg)),
          textStyle: textTheme.labelLarge
              ?.copyWith(fontWeight: FontWeight.w800, fontSize: 15),
          padding: const EdgeInsets.symmetric(horizontal: FgTokens.s6),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize:
              const Size(FgTokens.minTouchTarget, FgTokens.controlHeight),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FgTokens.rLg)),
          side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.18)),
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle:
              textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FgTokens.rLg),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FgTokens.rLg),
          borderSide:
              BorderSide(color: scheme.onSurface.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FgTokens.rLg),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FgTokens.rLg),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FgTokens.rLg),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: FgTokens.s4, vertical: FgTokens.s4),
        labelStyle:
            textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.surfaceContainerHighest,
        contentTextStyle:
            textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FgTokens.rLg)),
        insetPadding: const EdgeInsets.all(FgTokens.s4),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        indicatorShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FgTokens.rPill)),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 72,
        elevation: FgTokens.e0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.labelSmall?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: FgTokens.iconMd,
            color: states.contains(WidgetState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.primary.withValues(alpha: 0.18),
        side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.10)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FgTokens.rPill)),
        labelStyle:
            textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(
            horizontal: FgTokens.s3, vertical: FgTokens.s2),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(
            textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: scheme.onSurface.withValues(alpha: 0.12)),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(FgTokens.rPill)),
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        unselectedLabelStyle: textTheme.labelLarge,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FgTokens.rXl)),
        titleTextStyle:
            textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.onSurface.withValues(alpha: 0.08),
        space: 1,
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        minVerticalPadding: FgTokens.s3,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FgTokens.rLg)),
        titleTextStyle:
            textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
        subtitleTextStyle:
            textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.onSurface.withValues(alpha: 0.10),
        linearMinHeight: 8,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: FgTokens.e2,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FgTokens.rLg)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(FgTokens.r2Xl)),
        ),
      ),
    );
  }
}
