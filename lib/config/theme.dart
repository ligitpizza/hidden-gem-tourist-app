import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Field Journal" design tokens for Hidden Gems of Malaysia — Module 6
/// (Gamification & Travel Journal). Forest-green/gold "Modern Explorer"
/// palette with tonal surfaces instead of heavy shadows/borders.
class AppColors {
  AppColors._();

  static const Color surface = Color(0xFFFAF9F5);
  static const Color surfaceDim = Color(0xFFDBDAD6);
  static const Color surfaceBright = Color(0xFFFAF9F5);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF4F4F0);
  static const Color surfaceContainer = Color(0xFFEFEEEA);
  static const Color surfaceContainerHigh = Color(0xFFE9E8E4);
  static const Color surfaceContainerHighest = Color(0xFFE3E2DF);
  static const Color onSurface = Color(0xFF1B1C1A);
  static const Color onSurfaceVariant = Color(0xFF414844);
  static const Color inverseSurface = Color(0xFF2F312E);
  static const Color inverseOnSurface = Color(0xFFF2F1ED);
  static const Color outline = Color(0xFF717973);
  static const Color outlineVariant = Color(0xFFC1C8C2);
  static const Color surfaceTint = Color(0xFF3E6653);

  static const Color primary = Color(0xFF00160C);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFF012D1D);
  static const Color onPrimaryContainer = Color(0xFF6D9681);
  static const Color inversePrimary = Color(0xFFA5D0B8);

  static const Color secondary = Color(0xFF735C00);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFFED65B);
  static const Color onSecondaryContainer = Color(0xFF745C00);

  static const Color tertiary = Color(0xFF00151B);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFF002B36);
  static const Color onTertiaryContainer = Color(0xFF6395A6);

  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  static const Color primaryFixed = Color(0xFFC1ECD4);
  static const Color primaryFixedDim = Color(0xFFA5D0B8);
  static const Color onPrimaryFixed = Color(0xFF002114);
  static const Color onPrimaryFixedVariant = Color(0xFF264E3C);

  static const Color secondaryFixed = Color(0xFFFFE085);
  static const Color secondaryFixedDim = Color(0xFFE3C466);
  static const Color onSecondaryFixed = Color(0xFF231B00);
  static const Color onSecondaryFixedVariant = Color(0xFF574500);

  static const Color tertiaryFixed = Color(0xFFB7EBFD);
  static const Color tertiaryFixedDim = Color(0xFF9BCEE0);
  static const Color onTertiaryFixed = Color(0xFF001F27);
  static const Color onTertiaryFixedVariant = Color(0xFF144D5C);

  static const Color background = Color(0xFFFAF9F5);
  static const Color onBackground = Color(0xFF1B1C1A);
  static const Color surfaceVariant = Color(0xFFE3E2DF);

  /// Light tonal fill for chips/cards that need a soft primary tint —
  /// a low-opacity read of [primaryContainer] over [surface].
  static const Color primaryContainerTint = Color(0xFFE7F0EA);

  /// Light tonal fill for the "Local Guide/Transport" journal category —
  /// a low-opacity read of [tertiaryContainer] over [surface].
  static const Color tertiaryContainerTint = Color(0xFFE5F1F3);
}

/// Field Journal type scale — Montserrat for headlines, Inter for
/// functional text, per the design spec.
class AppTypography {
  AppTypography._();

  static TextStyle get headlineXl => GoogleFonts.montserrat(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    height: 48 / 40,
    letterSpacing: -0.02 * 40,
    color: AppColors.onSurface,
  );

  static TextStyle get headlineLg => GoogleFonts.montserrat(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 40 / 32,
    letterSpacing: -0.01 * 32,
    color: AppColors.onSurface,
  );

  static TextStyle get headlineLgMobile => GoogleFonts.montserrat(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    height: 34 / 28,
    color: AppColors.onSurface,
  );

  static TextStyle get headlineMd => GoogleFonts.montserrat(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 32 / 24,
    color: AppColors.onSurface,
  );

  static TextStyle get headlineSm => GoogleFonts.montserrat(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 28 / 20,
    color: AppColors.onSurface,
  );

  static TextStyle get bodyLg => GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w400,
    height: 28 / 18,
    color: AppColors.onSurface,
  );

  static TextStyle get bodyMd => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
    color: AppColors.onSurface,
  );

  static TextStyle get bodySm => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
    color: AppColors.onSurfaceVariant,
  );

  static TextStyle get labelMd => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 16 / 14,
    letterSpacing: 0.05 * 14,
    color: AppColors.onSurface,
  );

  static TextStyle get labelSm => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 14 / 12,
    letterSpacing: 0.05 * 12,
    color: AppColors.onSurfaceVariant,
  );
}

/// Corner radii, in logical pixels, matching the spec's `rounded` scale
/// (values given in rem, 1rem = 16px).
class AppRadius {
  AppRadius._();

  static const double sm = 4;
  static const double base = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 9999;
}

/// Spacing scale, in logical pixels.
class AppSpacing {
  AppSpacing._();

  static const double base = 8;
  static const double marginMobile = 16;
  static const double gutter = 16;
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final textTheme = TextTheme(
      headlineLarge: AppTypography.headlineXl,
      headlineMedium: AppTypography.headlineLg,
      headlineSmall: AppTypography.headlineLgMobile,
      titleLarge: AppTypography.headlineMd,
      titleMedium: AppTypography.headlineSm,
      bodyLarge: AppTypography.bodyLg,
      bodyMedium: AppTypography.bodyMd,
      bodySmall: AppTypography.bodySm,
      labelMedium: AppTypography.labelMd,
      labelSmall: AppTypography.labelSm,
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.surface,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimaryContainer,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.onSecondaryContainer,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        tertiaryContainer: AppColors.tertiaryContainer,
        onTertiaryContainer: AppColors.onTertiaryContainer,
        error: AppColors.error,
        onError: AppColors.onError,
        errorContainer: AppColors.errorContainer,
        onErrorContainer: AppColors.onErrorContainer,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
        inverseSurface: AppColors.inverseSurface,
        onInverseSurface: AppColors.inverseOnSurface,
        inversePrimary: AppColors.inversePrimary,
        surfaceTint: AppColors.surfaceTint,
        brightness: Brightness.light,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: AppTypography.headlineSm,
        surfaceTintColor: Colors.transparent,
      ),
      // NOTE: minimumSize uses a finite width floor (64), not
      // Size.fromHeight (which is Size(double.infinity, height)) — that
      // default previously crashed any button placed directly in a Row
      // (not wrapped in Expanded/SizedBox) with "BoxConstraints forces an
      // infinite width". Screens that want a full-width button already
      // wrap it in SizedBox(width: double.infinity, ...) explicitly.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onSurface,
          side: const BorderSide(color: AppColors.outline, width: 1.5),
          minimumSize: const Size(64, 48),
          textStyle: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryContainer,
          textStyle: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLow,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: const BorderSide(color: AppColors.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.outlineVariant, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.outlineVariant, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.outline),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primaryContainerTint,
        labelStyle: AppTypography.labelMd.copyWith(color: AppColors.primaryContainer),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        side: BorderSide.none,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceContainerLowest,
        indicatorColor: AppColors.primaryContainerTint,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return AppTypography.labelSm.copyWith(
            color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.primary : AppColors.onSurfaceVariant,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outlineVariant,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
