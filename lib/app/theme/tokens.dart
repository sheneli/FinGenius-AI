import 'package:flutter/material.dart';

/// Semantic design tokens — single source of truth for visual values.
/// v2 palette: "Neon Lime on Forest Black" (Spendly-inspired, FinGenius-owned).
abstract final class FgTokens {
  // Brand palette
  static const navy =
      Color(0xFF0A0F08); // forest-black base (name kept for API stability)
  static const navyRaised = Color(0xFF131A0F);
  static const navyOverlay = Color(0xFF1B2614);
  static const green = Color(0xFF9BE15D); // neon lime — primary
  static const greenDeep = Color(0xFF6DBB3C);
  static const cyan = Color(0xFFDDF9BF); // pale mint — secondary highlight
  static const gold = Color(0xFFF4C542);
  static const white = Color(0xFFFFFFFF);
  static const gray = Color(0xFFADBBA1); // muted green-grey text

  // Semantic — dark (default)
  static const surfaceDark = navy;
  static const surfaceRaisedDark = navyRaised;
  static const surfaceOverlayDark = navyOverlay;
  static const textPrimaryDark = Color(0xFFF4FFE8);
  static const textSecondaryDark = gray;
  static const textDisabledDark = Color(0x99ADBBA1);

  // Semantic — light
  static const surfaceLight = Color(0xFFF3FAEA);
  static const surfaceRaisedLight = white;
  static const textPrimaryLight = Color(0xFF15230D);
  static const textSecondaryLight = Color(0xFF4C6140);

  // State colours
  static const success = Color(0xFF86E063);
  static const warning = Color(0xFFF5A623);
  static const error = Color(0xFFF06D64);
  static const info = Color(0xFF7FD9C9);

  // Gradients
  static const growthGradient = LinearGradient(
    begin: Alignment.bottomLeft,
    end: Alignment.topRight,
    colors: [greenDeep, Color(0xFFD3F98A)],
  );
  static const cardGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A2911), Color(0xFF101A09)],
  );

  // Chart palette (colour-blind aware ordering; state never colour-only)
  static const chartPalette = <Color>[
    green,
    Color(0xFF7FD99A),
    gold,
    Color(0xFF9F7AEA),
    Color(0xFFF06D64),
    Color(0xFF63B3ED),
    Color(0xFFED8936),
    Color(0xFF4FD1C5),
  ];

  // Spacing scale (dp)
  static const s1 = 4.0,
      s2 = 8.0,
      s3 = 12.0,
      s4 = 16.0,
      s5 = 20.0,
      s6 = 24.0,
      s8 = 32.0,
      s10 = 40.0;

  // Corner radii
  static const rSm = 8.0, rMd = 12.0, rLg = 16.0, rXl = 24.0, rPill = 999.0;

  // Elevation
  static const e0 = 0.0, e1 = 1.0, e2 = 3.0;

  // Motion (respect reduced-motion: durations collapse to zero)
  static const dFast = Duration(milliseconds: 120);
  static const dMed = Duration(milliseconds: 240);
  static const dSlow = Duration(milliseconds: 400);

  // Opacity
  static const oDisabled = 0.5,
      oMuted = 0.7,
      oGlassFill = 0.08,
      oGlassBorder = 0.16;

  // Icon sizes / touch targets
  static const iconSm = 18.0, iconMd = 24.0, iconLg = 32.0;
  static const minTouchTarget = 48.0;

  // ── v3 fintech refresh (additive; nothing above changed) ────────────────
  // Softer, larger radii for the card-led layouts modern fintech UIs use.
  static const rCard = 20.0, r2Xl = 28.0;

  /// Standard control height for primary CTAs.
  static const controlHeight = 54.0;

  /// Ambient shadow under raised cards. Dark themes need a deeper, softer
  /// shadow because a light drop shadow is invisible on near-black surfaces.
  static List<BoxShadow> cardShadow(Brightness b) => [
        BoxShadow(
          color: b == Brightness.dark
              ? const Color(0xFF000000).withValues(alpha: 0.45)
              : const Color(0xFF15230D).withValues(alpha: 0.08),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ];

  /// Coloured glow behind the hero balance card and the primary action button.
  static List<BoxShadow> glow(Color c, {double alpha = 0.35}) => [
        BoxShadow(
          color: c.withValues(alpha: alpha),
          blurRadius: 28,
          spreadRadius: -6,
          offset: const Offset(0, 12),
        ),
      ];

  /// Hero balance wash. Deliberately stays in the *light* half of the lime
  /// ramp end-to-end: the card carries dark ink, so a dark gradient stop
  /// would fail contrast for anything sitting on the far side of the card.
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFB9EC7E), Color(0xFF9BE15D), Color(0xFF77C742)],
    stops: [0.0, 0.5, 1.0],
  );

  /// Subtle sheen laid over glass surfaces.
  static LinearGradient sheen(Brightness b) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: b == Brightness.dark
            ? [
                Colors.white.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.02)
              ]
            : [
                Colors.white.withValues(alpha: 0.90),
                Colors.white.withValues(alpha: 0.55)
              ],
      );

  /// Accent tints for quick-action tiles (kept distinct for scannability).
  static const actionTints = <Color>[
    green,
    Color(0xFF7FD9C9),
    gold,
    Color(0xFF9F7AEA)
  ];
}
