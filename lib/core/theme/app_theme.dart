import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_design_tokens.dart';

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.blue500,
      onPrimary: AppColors.blue50,
      secondary: AppColors.secondaryButtonFill,
      onSecondary: AppColors.secondaryButtonText,
      error: AppColors.rose500,
      onError: AppColors.rose50,
      surface: AppColors.white,
      onSurface: AppColors.neutral700,
    ),
    scaffoldBackgroundColor: AppColors.background,
  );
  final textTheme = GoogleFonts.interTextTheme(
    base.textTheme,
  ).apply(bodyColor: AppColors.titleText, displayColor: AppColors.titleText);

  return base.copyWith(
    textTheme: textTheme,
    primaryTextTheme: GoogleFonts.interTextTheme(base.primaryTextTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.titleText,
      surfaceTintColor: AppColors.background,
      titleTextStyle: GoogleFonts.inter(
        color: AppColors.titleText,
        fontSize: AppTypography.sizeBase,
        fontWeight: AppTypography.weightSemibold,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.cardFill,
      surfaceTintColor: AppColors.cardFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.cardFill,
      surfaceTintColor: AppColors.cardFill,
      titleTextStyle: TextStyle(
        color: AppColors.titleText,
        fontFamily: AppTypography.sansFamily,
        fontSize: AppTypography.sizeXl,
        fontWeight: AppTypography.weightSemibold,
      ),
      contentTextStyle: TextStyle(
        color: AppColors.subHeaderText,
        fontFamily: AppTypography.sansFamily,
        fontSize: AppTypography.sizeBase,
        fontWeight: AppTypography.weightNormal,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryButtonFill,
        foregroundColor: AppColors.primaryButtonText,
        disabledBackgroundColor: AppColors.blue200,
        disabledForegroundColor: AppColors.primaryButtonText,
        minimumSize: const Size.fromHeight(AppSizes.onboardingButtonHeight),
        textStyle: GoogleFonts.inter(
          fontSize: AppTypography.sizeBase,
          fontWeight: AppTypography.weightSemibold,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.twoXl),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.titleText,
        disabledForegroundColor: AppColors.subHeaderText,
        minimumSize: const Size.fromHeight(AppSizes.onboardingButtonHeight),
        side: const BorderSide(color: AppColors.cardBorder),
        textStyle: GoogleFonts.inter(
          fontSize: AppTypography.sizeBase,
          fontWeight: AppTypography.weightSemibold,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.twoXl),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      hintStyle: GoogleFonts.inter(
        color: AppColors.neutral400,
        fontSize: AppTypography.sizeBase,
        fontWeight: AppTypography.weightNormal,
      ),
      filled: true,
      fillColor: AppColors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.twoXl),
        borderSide: const BorderSide(color: AppColors.neutral200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.twoXl),
        borderSide: const BorderSide(color: AppColors.neutral200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.twoXl),
        borderSide: const BorderSide(color: AppColors.blue500),
      ),
    ),
  );
}
