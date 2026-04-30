import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_design_tokens.dart';

class FirstRunHandoffKeys {
  const FirstRunHandoffKeys._();

  static const Key namePrompt = Key('dashboard-name-prompt');
  static const Key nameField = Key('dashboard-name-field');
  static const Key nameSaveButton = Key('dashboard-name-save');
  static const Key welcomeScreen = Key('dashboard-welcome-screen');
  static const Key welcomeCard = Key('dashboard-welcome-card');
  static const Key welcomeButton = Key('dashboard-welcome-start');
}

class DisplayNamePromptDialog extends StatefulWidget {
  const DisplayNamePromptDialog({super.key});

  @override
  State<DisplayNamePromptDialog> createState() =>
      _DisplayNamePromptDialogState();
}

class _DisplayNamePromptDialogState extends State<DisplayNamePromptDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: FirstRunHandoffKeys.namePrompt,
      backgroundColor: AppColors.cardFill,
      surfaceTintColor: AppColors.cardFill,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.six),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.twoXl),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.six,
          AppSpacing.eight,
          AppSpacing.six,
          AppSpacing.eight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'What should we call you?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: AppColors.titleText,
                fontWeight: AppTypography.weightSemibold,
              ),
            ),
            const SizedBox(height: AppSpacing.three),
            Text(
              'Your name personalized your RemindLy',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.subHeaderText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.four),
            TextField(
              key: FirstRunHandoffKeys.nameField,
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Enter your name',
                filled: true,
                fillColor: AppColors.cardFill,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.three,
                  vertical: AppSpacing.four,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  borderSide: const BorderSide(color: AppColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  borderSide: const BorderSide(
                    color: AppColors.blue500,
                    width: AppSizes.borderDefault,
                  ),
                ),
              ),
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AppSpacing.three),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: FirstRunHandoffKeys.nameSaveButton,
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(
                    AppSizes.onboardingButtonHeight,
                  ),
                  backgroundColor: AppColors.primaryButtonFill,
                  foregroundColor: AppColors.primaryButtonText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.twoXl),
                  ),
                ),
                child: const Text('Get Started'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WelcomeHandoffDialog extends StatefulWidget {
  const WelcomeHandoffDialog({super.key, required this.displayName});

  final String displayName;

  @override
  State<WelcomeHandoffDialog> createState() => _WelcomeHandoffDialogState();
}

class _WelcomeHandoffDialogState extends State<WelcomeHandoffDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      key: FirstRunHandoffKeys.welcomeScreen,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.four),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: AppSpacing.zero,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: -70,
            child: SizedBox(
              width: AppSizes.welcomeDialogIllustrationWidth,
              height: AppSizes.welcomeDialogIllustrationHeight,
              child: SvgPicture.asset(
                'assets/svgs/welcome/remindly-welcome.svg',
                fit: BoxFit.contain,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 60),
            child: Container(
              key: FirstRunHandoffKeys.welcomeCard,
              decoration: BoxDecoration(
                color: AppColors.cardFill,
                borderRadius: BorderRadius.circular(AppRadii.threeXl),
                border: Border.all(color: AppColors.neutral200),
              ),
              padding: const EdgeInsets.all(AppSpacing.six),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Welcome, ${widget.displayName}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.primaryButtonFill,
                      fontSize: AppTypography.size2xl,
                      fontWeight: AppTypography.weightSemibold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.three),
                  Text(
                    'Your RemindLy dashboard is ready with tasks, notes, and reminders to keep you on track.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.subHeaderText,
                      fontSize: AppTypography.sizeBase,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.five),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: FirstRunHandoffKeys.welcomeButton,
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(
                          AppSizes.heroDialogButtonHeight,
                        ),
                        backgroundColor: AppColors.primaryButtonFill,
                        foregroundColor: AppColors.primaryButtonText,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.xl),
                        ),
                      ),
                      child: const Text('Let\'s Go!'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
