import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/services/display_name_store.dart';
import '../../../core/services/onboarding_status_store.dart';
import '../../../core/theme/app_design_tokens.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../domain/onboarding_step_data.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onboardingStatusStore,
    required this.displayNameStore,
    required this.dashboardClock,
  });

  static const Key markerKey = Key('onboarding-screen');
  static const Key contentKey = Key('onboarding-content');
  static const Key pageIndicatorKey = Key('onboarding-page-indicator');

  final OnboardingStatusStore onboardingStatusStore;
  final DisplayNameStore displayNameStore;
  final DashboardClock dashboardClock;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentIndex = 0;
  int _previousIndex = 0;
  bool _isCompleting = false;
  double _dragDx = 0;

  bool get _isLastStep => _currentIndex == onboardingSteps.length - 1;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _goToNextStep() async {
    if (_isLastStep) {
      await _completeOnboarding();
      return;
    }

    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex += 1;
    });
  }

  Future<void> _goToPreviousStep() async {
    if (_currentIndex == 0) {
      return;
    }

    setState(() {
      _previousIndex = _currentIndex;
      _currentIndex -= 1;
    });
  }

  void _handleSwipeEnd(DragEndDetails details) {
    if (_isCompleting) {
      return;
    }

    final velocity = details.primaryVelocity ?? 0;
    const velocityThreshold = 250;
    const distanceThreshold = 40;

    if (velocity <= -velocityThreshold || _dragDx <= -distanceThreshold) {
      _dragDx = 0;
      _goToNextStep();
      return;
    }

    if (velocity >= velocityThreshold || _dragDx >= distanceThreshold) {
      _dragDx = 0;
      _goToPreviousStep();
      return;
    }

    _dragDx = 0;
  }

  Future<void> _completeOnboarding() async {
    if (_isCompleting) {
      return;
    }

    setState(() {
      _isCompleting = true;
    });

    await widget.onboardingStatusStore.markCompleted();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (context, animation, secondaryAnimation) =>
            DashboardScreen(
              displayNameStore: widget.displayNameStore,
              clock: widget.dashboardClock,
            ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = onboardingSteps[_currentIndex];

    return Scaffold(
      key: OnboardingScreen.markerKey,
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) {
                _dragDx += details.delta.dx;
              },
              onHorizontalDragEnd: _handleSwipeEnd,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final visualSize = math.min(
                    AppSizes.onboardingVisual,
                    constraints.maxWidth - (AppSpacing.five * 2),
                  );
                  final imageTextGap = math.min(
                    AppSizes.onboardingImageTextGap,
                    constraints.maxHeight * 0.06,
                  );

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.five,
                      vertical: AppSpacing.five,
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: _OnboardingVisual(
                              step: step,
                              size: visualSize,
                            ),
                          ),
                        ),
                        SizedBox(height: imageTextGap),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: AppSizes.onboardingContentMaxWidth,
                          ),
                          child: Column(
                            key: OnboardingScreen.contentKey,
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 260),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeOutCubic,
                                layoutBuilder:
                                    (currentChild, previousChildren) {
                                      return currentChild ??
                                          const SizedBox.shrink();
                                    },
                                transitionBuilder: (child, animation) {
                                  final isForward =
                                      _currentIndex >= _previousIndex;
                                  final slide = Tween<Offset>(
                                    begin: Offset(isForward ? 0.08 : -0.08, 0),
                                    end: Offset.zero,
                                  ).animate(animation);

                                  return SlideTransition(
                                    position: slide,
                                    child: child,
                                  );
                                },
                                child: Text(
                                  step.title,
                                  key: ValueKey('title-$_currentIndex'),
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        color: AppColors.titleText,
                                        fontSize: AppTypography.sizeXl,
                                        fontWeight:
                                            AppTypography.weightSemibold,
                                        height: 1.18,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(
                                height: AppSizes.onboardingTitleDescriptionGap,
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 260),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeOutCubic,
                                layoutBuilder:
                                    (currentChild, previousChildren) {
                                      return currentChild ??
                                          const SizedBox.shrink();
                                    },
                                transitionBuilder: (child, animation) {
                                  final isForward =
                                      _currentIndex >= _previousIndex;
                                  final slide = Tween<Offset>(
                                    begin: Offset(isForward ? 0.08 : -0.08, 0),
                                    end: Offset.zero,
                                  ).animate(animation);

                                  return SlideTransition(
                                    position: slide,
                                    child: child,
                                  );
                                },
                                child: Text(
                                  step.description,
                                  key: ValueKey('desc-$_currentIndex'),
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: AppColors.subHeaderText,
                                    fontSize: AppTypography.sizeBase,
                                    height: 1.25,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(
                                height:
                                    AppSizes.onboardingDescriptionIndicatorGap,
                              ),
                              _OnboardingPageIndicator(
                                currentIndex: _currentIndex,
                              ),
                              const SizedBox(
                                height: AppSizes.onboardingIndicatorButtonGap,
                              ),
                              _OnboardingActions(
                                isCompleting: _isCompleting,
                                isLastStep: _isLastStep,
                                onPrimary: _goToNextStep,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingVisual extends StatelessWidget {
  const _OnboardingVisual({required this.step, required this.size});

  final OnboardingStepData step;
  final double size;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeOutCubic,
      child: SvgPicture.asset(
        step.assetPath,
        key: ValueKey(step.assetPath),
        width: size,
        height: size,
        fit: BoxFit.contain,
        semanticsLabel: step.title,
      ),
    );
  }
}

class _OnboardingPageIndicator extends StatelessWidget {
  const _OnboardingPageIndicator({required this.currentIndex});

  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: OnboardingScreen.pageIndicatorKey,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(onboardingSteps.length, (index) {
        final isActive = index == currentIndex;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: isActive ? AppSizes.onboardingDot * 2 : AppSizes.onboardingDot,
          height: AppSizes.onboardingDot,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.one),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primaryButtonFill
                : AppColors.secondaryButtonFill,
            borderRadius: BorderRadius.circular(AppRadii.full),
          ),
        );
      }),
    );
  }
}

class _OnboardingActions extends StatelessWidget {
  const _OnboardingActions({
    required this.isCompleting,
    required this.isLastStep,
    required this.onPrimary,
  });

  final bool isCompleting;
  final bool isLastStep;
  final Future<void> Function() onPrimary;

  @override
  Widget build(BuildContext context) {
    final primaryLabel = isLastStep ? 'Continue' : 'Next';

    return SizedBox(
      width: double.infinity,
      height: AppSizes.onboardingActionHeight,
      child: FilledButton(
        onPressed: isCompleting ? null : () => onPrimary(),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryButtonFill,
          foregroundColor: AppColors.primaryButtonText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              AppSizes.onboardingButtonRadius,
            ),
          ),
        ),
        child: isCompleting
            ? const SizedBox(
                width: AppSizes.progressIndicator,
                height: AppSizes.progressIndicator,
                child: CircularProgressIndicator(
                  strokeWidth: AppSizes.progressStroke,
                ),
              )
            : Text(primaryLabel, style: _themeButtonTextStyle(context)),
      ),
    );
  }
}

TextStyle? _themeButtonTextStyle(BuildContext context) {
  return Theme.of(
    context,
  ).filledButtonTheme.style?.textStyle?.resolve(<WidgetState>{});
}
