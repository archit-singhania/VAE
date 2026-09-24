import 'package:flutter/material.dart';
import 'design_tokens.dart';

/// ---------------------------------------------------------------------
/// AEVRA — "Nocturne" design system (mobile).
///
/// One source of truth for colour, type, radius, spacing and elevation,
/// mirroring the CSS custom properties in apps/web/app/globals.css so the
/// two clients read as one product rather than two ports of it.
///
/// Direction: cool obsidian ground, porcelain type, a premium crimson
/// signal, and jade / frost / amber / rose carrying state. Chroma is kept
/// deliberately low everywhere except the one accent, which is what makes
/// the accent read as information instead of decoration.
/// ---------------------------------------------------------------------

class AevraColors {
  AevraColors._();

  // ---- Ground ------------------------------------------------------
  /// Page obsidian. Faint blue cast; never pure black, never warm grey.
  static const bg = VaeTokens.darkBackground;

  /// Sunken wells — inputs, code, inset rows.
  static const surface1 = VaeTokens.darkInput;

  /// The working plane. Panels and cards sit here.
  static const panel = VaeTokens.darkSurface;

  /// Raised objects on top of a panel.
  static const surface3 = VaeTokens.darkRaised;

  /// Elevated chrome — chips, field fills, hovered rows.
  static const surface4 = Color(0xFF393A35);

  // ---- Hairlines ---------------------------------------------------
  static const line = Color(0x12C6D0E2);
  static const lineStrong = Color(0x26C6D0E2);

  /// The specular tint used for catching edges and sheen gradients.
  static const sheen = Color(0xFFC6D0E2);

  // ---- Type --------------------------------------------------------
  /// Porcelain, not white. A trace of warmth stops dark UI reading clinical.
  static const text = VaeTokens.darkText;
  static const textSoft = Color(0xFFB6BAC4);
  static const muted = Color(0xFF878D9A);
  static const muted2 = Color(0xFF95998F);

  // ---- Signal ------------------------------------------------------
  /// Crimson. The single warm note against the cold ground — the whole
  /// palette is built so this is the only thing that can shout.
  static const accent = VaeTokens.darkAccent;
  static const accentStrong = Color(0xFFFF6378);

  /// Text/iconography placed on top of a filled accent surface.
  static const accentInk = Color(0xFFFFF8F9);

  /// Positive / approved / connected.
  static const jade = VaeTokens.darkSuccess;

  /// Informational / neutral-cool / analytics.
  static const frost = VaeTokens.darkInfo;

  /// Pending / awaiting a human.
  static const amber = Color(0xFFD4A244);

  /// Failed / rejected / destructive.
  static const rose = VaeTokens.darkError;

  // ---- Legacy aliases ---------------------------------------------
  // The previous palette named its three accents lime/violet/cyan. Those
  // names are kept pointing at the new tokens so nothing outside this file
  // can silently fall back to an unthemed colour, but new code should use
  // the semantic names above.
  static const lime = accent;
  static const violet = jade;
  static const cyan = frost;
  static const onAccent = accentInk;
}

/// Light-mode counterpart — warm paper rather than grey, so the two themes
/// feel like day and night in the same room instead of two products.
class AevraLightColors {
  AevraLightColors._();

  static const bg = VaeTokens.lightBackground;
  static const surface1 = VaeTokens.lightInput;
  static const panel = VaeTokens.lightSurface;
  static const surface3 = VaeTokens.lightRaised;
  static const surface4 = Color(0xFFE4E0D7);

  static const line = Color(0x1A1A1C21);
  static const lineStrong = Color(0x331A1C21);

  static const text = VaeTokens.lightText;
  static const textSoft = Color(0xFF4A505C);
  static const muted = Color(0xFF6A7180);
  static const muted2 = Color(0xFF62665E);

  static const accent = VaeTokens.lightAccent;
  static const accentStrong = Color(0xFFE5485D);
  static const accentInk = Color(0xFFFFF8F9);

  static const jade = VaeTokens.lightSuccess;
  static const frost = VaeTokens.lightInfo;
  static const amber = Color(0xFF9A6F16);
  static const rose = VaeTokens.lightError;
}

/// Corner geometry. Tighter than the previous system on small objects and
/// more generous on sheets, which is what gives an interface a sense of
/// scale rather than one uniform roundness everywhere.
class AevraRadius {
  AevraRadius._();

  static const double xs = 6;
  static const double sm = 12;
  static const double md = 20;
  static const double lg = 18;
  static const double xl = 32;
  static const double pill = 999;
}

/// A 4pt rhythm. Every gap in the app should be one of these.
class AevraSpace {
  AevraSpace._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  /// Horizontal screen gutter.
  static const double gutter = 20;
}

/// ---------------------------------------------------------------------
/// Type. Three families doing three jobs:
///
///   Playfair Display — display only, high stroke contrast, editorial.
///   Manrope         — every piece of UI text.
///   JetBrains Mono  — numerals, eyebrows, timestamps, anything tabular.
///
/// Headline sizes are the only place the serif appears, and always with
/// negative tracking; at default tracking a didone serif reads as a book,
/// not an instrument panel.
/// ---------------------------------------------------------------------
class AevraType {
  AevraType._();

  /// Serif display. [size] is the optical size you actually want on screen.
  static TextStyle display(
    double size, {
    Color color = AevraColors.text,
    FontWeight weight = FontWeight.w500,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'PlayfairDisplay',
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height ?? (size > 30 ? 1.04 : 1.14),
      letterSpacing: size * -0.022,
    );
  }

  /// Uppercase eyebrow / kicker above a heading.
  static TextStyle eyebrow({Color color = AevraColors.accent}) {
    return TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: 9.5,
      fontWeight: FontWeight.w500,
      letterSpacing: 1.6,
      color: color,
    );
  }

  /// Big tabular figures — metrics, scores, counters.
  static TextStyle metric(double size, {Color color = AevraColors.text}) {
    return TextStyle(
      fontFamily: 'Manrope',
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: size * -0.03,
      height: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Small monospaced metadata — times, ids, status codes.
  static TextStyle mono({double size = 10, Color color = AevraColors.muted2}) {
    return TextStyle(
      fontFamily: 'JetBrainsMono',
      fontSize: size,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.2,
      color: color,
    );
  }
}

class AevraTheme {
  AevraTheme._();

  // Built once and reused. These getters are read on every MaterialApp
  // build, and each call otherwise reconstructs a full ThemeData plus a
  // dozen text-style lookups — cheap individually, wasteful every frame
  // a rebuild happens to pass through the root.
  static ThemeData? _darkCache;
  static ThemeData? _lightCache;
  static ThemeData? _adminDarkCache;

  static ThemeData get dark => _darkCache ??= _buildDark();
  static ThemeData get light => _lightCache ??= _buildLight();
  static ThemeData get adminDark => _adminDarkCache ??= _build(
        brightness: Brightness.dark,
        background: const Color(0xFF080E1A),
        surface: const Color(0xFF111C30),
        fieldFill: const Color(0xFF0D1728),
        line: const Color(0x24709FFF),
        lineStrong: const Color(0x52709FFF),
        text: const Color(0xFFF4F8FF),
        muted: const Color(0xFF94A5C2),
        muted2: const Color(0xFF7D8DA8),
        accent: const Color(0xFF4F8CFF),
        accentInk: const Color(0xFFF7FAFF),
        secondary: const Color(0xFF58C7AA),
        tertiary: const Color(0xFF8BB6FF),
        error: const Color(0xFFEF6678),
      );

  static ThemeData _buildDark() => _build(
        brightness: Brightness.dark,
        background: AevraColors.bg,
        surface: AevraColors.panel,
        fieldFill: AevraColors.surface1,
        line: AevraColors.line,
        lineStrong: AevraColors.lineStrong,
        text: AevraColors.text,
        muted: AevraColors.muted,
        muted2: AevraColors.muted2,
        accent: AevraColors.accent,
        accentInk: AevraColors.accentInk,
        secondary: AevraColors.jade,
        tertiary: AevraColors.frost,
        error: AevraColors.rose,
      );

  static ThemeData _buildLight() => _build(
        brightness: Brightness.light,
        background: AevraLightColors.bg,
        surface: AevraLightColors.panel,
        fieldFill: AevraLightColors.surface1,
        line: AevraLightColors.line,
        lineStrong: AevraLightColors.lineStrong,
        text: AevraLightColors.text,
        muted: AevraLightColors.muted,
        muted2: AevraLightColors.muted2,
        accent: AevraLightColors.accent,
        accentInk: AevraLightColors.accentInk,
        secondary: AevraLightColors.jade,
        tertiary: AevraLightColors.frost,
        error: AevraLightColors.rose,
      );

  /// Both themes are produced by the same builder so a change to density,
  /// radius or motion can never land in one mode and not the other — the
  /// single most common way a two-theme app drifts apart.
  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color fieldFill,
    required Color line,
    required Color lineStrong,
    required Color text,
    required Color muted,
    required Color muted2,
    required Color accent,
    required Color accentInk,
    required Color secondary,
    required Color tertiary,
    required Color error,
  }) {
    final base = ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: accent,
        onPrimary: accentInk,
        secondary: secondary,
        onSecondary: accentInk,
        tertiary: tertiary,
        onTertiary: accentInk,
        surface: surface,
        onSurface: text,
        error: error,
        onError: accentInk,
      ),
      useMaterial3: true,
    );

    final textTheme = base.textTheme.apply(
      fontFamily: 'Manrope',
      bodyColor: text,
      displayColor: text,
    );

    return base.copyWith(
      textTheme: textTheme.copyWith(
        displayLarge: AevraType.display(44, color: text),
        displayMedium: AevraType.display(36, color: text),
        displaySmall: AevraType.display(30, color: text),
        headlineMedium: AevraType.display(26, color: text),
        headlineSmall: AevraType.display(22, color: text),
        titleLarge: AevraType.display(19, color: text),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontSize: 14.5,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
        titleSmall: textTheme.titleSmall?.copyWith(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.05,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(fontSize: 14.5, height: 1.55),
        bodyMedium:
            textTheme.bodyMedium?.copyWith(fontSize: 13.5, height: 1.55),
        bodySmall: textTheme.bodySmall
            ?.copyWith(fontSize: 11.5, height: 1.5, color: muted),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        labelSmall: textTheme.labelSmall?.copyWith(fontSize: 10, color: muted2),
      ),

      // Motion: no ink splash anywhere. Ripples are Android-native, not
      // brand-native, and they fight the tilt/glass language.
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      dividerColor: line,
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: muted, size: 19),
      primaryIconTheme: IconThemeData(color: accent, size: 19),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),

      cardTheme: CardThemeData(
        color: surface.withValues(alpha: 0.7),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AevraRadius.md),
          side: BorderSide(color: line),
        ),
      ),

      // Fields read as wells cut into the panel, not as boxes sitting on it.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        hintStyle: TextStyle(color: muted2, fontSize: 13),
        labelStyle: TextStyle(color: muted, fontSize: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AevraRadius.sm),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AevraRadius.sm),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AevraRadius.sm),
          borderSide: BorderSide(color: accent, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AevraRadius.sm),
          borderSide: BorderSide(color: error.withValues(alpha: 0.6)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AevraRadius.sm),
          borderSide: BorderSide(color: error, width: 1.4),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: accentInk,
          disabledBackgroundColor: accent.withValues(alpha: 0.3),
          disabledForegroundColor: accentInk.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AevraRadius.sm)),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: lineStrong),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(
              fontFamily: 'Manrope', fontSize: 13, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AevraRadius.sm)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: muted,
          textStyle: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12.5,
              fontWeight: FontWeight.w600),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: surface,
        side: BorderSide(color: line),
        labelStyle:
            TextStyle(fontFamily: 'JetBrainsMono', fontSize: 9.5, color: muted),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        shape: const StadiumBorder(),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AevraRadius.xl)),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AevraRadius.xl)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle:
            TextStyle(fontFamily: 'Manrope', fontSize: 12.5, color: text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AevraRadius.md)),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: line,
        circularTrackColor: line,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: accent.withValues(alpha: 0.13),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AevraRadius.sm),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: 'Manrope',
            fontSize: 10.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.15,
            color: selected ? text : muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? accent : muted, size: 21);
        }),
      ),

      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: text,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AevraRadius.sm)),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(AevraRadius.xs),
          border: Border.all(color: line),
        ),
        textStyle: TextStyle(fontFamily: 'Manrope', fontSize: 11, color: text),
      ),
    );
  }
}
