import 'package:flutter/material.dart';

import '../../core/theme/app_design_tokens.dart';

enum AppDecisionTone { primary, danger, success, warning }

class AppDecisionDialog extends StatelessWidget {
  const AppDecisionDialog({
    super.key,
    required this.tone,
    required this.icon,
    required this.title,
    required this.message,
    required this.secondaryLabel,
    required this.primaryLabel,
    required this.onSecondaryPressed,
    required this.onPrimaryPressed,
  });

  final AppDecisionTone tone;
  final IconData icon;
  final String title;
  final String message;
  final String secondaryLabel;
  final String primaryLabel;
  final VoidCallback onSecondaryPressed;
  final VoidCallback onPrimaryPressed;

  Color get _toneFill {
    return switch (tone) {
      AppDecisionTone.primary => AppColors.blue100,
      AppDecisionTone.danger => AppColors.rose100,
      AppDecisionTone.success => AppColors.teal100,
      AppDecisionTone.warning => AppColors.amber100,
    };
  }

  Color get _toneForeground {
    return switch (tone) {
      AppDecisionTone.primary => AppColors.blue500,
      AppDecisionTone.danger => AppColors.rose500,
      AppDecisionTone.success => AppColors.teal500,
      AppDecisionTone.warning => AppColors.amber500,
    };
  }

  Color get _primaryFill {
    return switch (tone) {
      AppDecisionTone.danger => AppColors.dangerButtonFill,
      AppDecisionTone.success => AppColors.successButtonFill,
      AppDecisionTone.warning => AppColors.primaryButtonFill,
      AppDecisionTone.primary => AppColors.primaryButtonFill,
    };
  }

  Color get _primaryText {
    return switch (tone) {
      AppDecisionTone.danger => AppColors.dangerButtonText,
      AppDecisionTone.success => AppColors.successButtonText,
      AppDecisionTone.warning => AppColors.primaryButtonText,
      AppDecisionTone.primary => AppColors.primaryButtonText,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      backgroundColor: AppColors.cardFill,
      surfaceTintColor: AppColors.cardFill,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.eight,
        vertical: AppSpacing.six,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.threeXl),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.six,
          AppSpacing.eight,
          AppSpacing.six,
          AppSpacing.six,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              child: Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: _toneFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _toneForeground, size: 24),
              ),
            ),
            const SizedBox(height: AppSpacing.five),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppColors.titleText,
                fontWeight: AppTypography.weightSemibold,
              ),
            ),
            const SizedBox(height: AppSpacing.three),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.subHeaderText,
              ),
            ),
            const SizedBox(height: AppSpacing.six),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onSecondaryPressed,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(
                        AppSizes.onboardingButtonHeight,
                      ),
                      backgroundColor: AppColors.neutral200,
                      foregroundColor: AppColors.titleText,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                      ),
                    ),
                    child: Text(secondaryLabel),
                  ),
                ),
                const SizedBox(width: AppSpacing.three),
                Expanded(
                  child: FilledButton(
                    onPressed: onPrimaryPressed,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(
                        AppSizes.onboardingButtonHeight,
                      ),
                      backgroundColor: _primaryFill,
                      foregroundColor: _primaryText,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                      ),
                    ),
                    child: Text(primaryLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
