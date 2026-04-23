import 'package:flutter/material.dart';

abstract final class AppColors {
  static const neutral50 = Color(0xFFFAFAFA);
  static const neutral100 = Color(0xFFF5F5F5);
  static const neutral200 = Color(0xFFE5E5E5);
  static const neutral500 = Color(0xFF737373);
  static const neutral400 = Color(0xFFA3A3A3);
  static const neutral700 = Color(0xFF404040);
  static const white = Color(0xFFFFFFFF);

  static const blue50 = Color(0xFFEFF6FF);
  static const blue100 = Color(0xFFDBEAFE);
  static const blue200 = Color(0xFFBFDBFE);
  static const blue500 = Color(0xFF3B82F6);
  static const blue600 = Color(0xFF2563EB);
  static const indigo500 = Color(0xFF6366F1);

  static const rose100 = Color(0xFFFFE4E6);
  static const rose50 = Color(0xFFFFF1F2);
  static const rose500 = Color(0xFFF43F5E);

  static const teal50 = Color(0xFFF0FDFA);
  static const teal100 = Color(0xFFCCFBF1);
  static const teal500 = Color(0xFF14B8A6);

  static const amber50 = Color(0xFFFFFBEB);
  static const amber100 = Color(0xFFFEF3C7);
  static const amber500 = Color(0xFFF59E0B);

  static const background = neutral50;
  static const cardFill = white;
  static const cardBorder = neutral100;
  static const titleText = neutral700;
  static const subHeaderText = neutral400;

  static const primaryButtonFill = blue500;
  static const primaryButtonText = blue50;
  static const secondaryButtonFill = neutral200;
  static const secondaryButtonText = neutral700;
  static const dangerButtonFill = rose500;
  static const dangerButtonText = rose50;
  static const successButtonFill = teal500;
  static const successButtonText = teal50;
  static const warningButtonFill = amber500;
  static const warningButtonText = amber50;
  static const primaryBadgeFill = blue100;
  static const primaryBadgeText = blue500;
  static const secondaryBadgeFill = neutral200;
  static const secondaryBadgeText = neutral700;
  static const secondaryBadgeIcon = neutral700;
  static const checkboxCardFill = neutral50;
  static const checkboxCardBorder = neutral200;
}

abstract final class AppTypography {
  static const sansFamily = 'Inter';

  static const sizeXs = 12.0;
  static const sizeSm = 14.0;
  static const sizeBase = 16.0;
  static const sizeLg = 18.0;
  static const sizeXl = 20.0;
  static const size2xl = 24.0;

  static const weightNormal = FontWeight.w400;
  static const weightMedium = FontWeight.w500;
  static const weightSemibold = FontWeight.w600;
  static const weightBold = FontWeight.w700;
}

abstract final class AppSpacing {
  static const zero = 0.0;
  static const one = 4.0;
  static const oneAndHalf = 6.0;
  static const two = 8.0;
  static const twoAndHalf = 10.0;
  static const three = 12.0;
  static const four = 16.0;
  static const five = 20.0;
  static const six = 24.0;
  static const eight = 32.0;
  static const ten = 40.0;
  static const twelve = 48.0;
}

abstract final class AppRadii {
  static const sm = 2.0;
  static const defaultRadius = 4.0;
  static const md = 6.0;
  static const lg = 8.0;
  static const xl = 12.0;
  static const twoXl = 16.0;
  static const threeXl = 24.0;
  static const full = 999.0;
}

abstract final class AppSizes {
  static const borderDefault = 1.0;
  static const onboardingMaxWidth = 420.0;
  static const onboardingVisual = 144.0;
  static const onboardingVisualIcon = 54.0;
  static const onboardingDot = 8.0;
  static const onboardingButtonHeight = 54.0;
  static const progressIndicator = 20.0;
  static const progressStroke = 2.4;
}

abstract final class AppOpacity {
  static const overlay20 = 0.2;
  static const overlay25 = 0.25;
  static const overlay30 = 0.3;
  static const overlay40 = 0.4;
}
