import 'package:flutter/material.dart';

import '../../../core/services/display_name_store.dart';
import '../../../core/services/onboarding_status_store.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../domain/onboarding_step_data.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onboardingStatusStore,
    required this.displayNameStore,
  });

  static const Key markerKey = Key('onboarding-screen');
  static const Key contentKey = Key('onboarding-content');

  final OnboardingStatusStore onboardingStatusStore;
  final DisplayNameStore displayNameStore;

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
            DashboardScreen(displayNameStore: widget.displayNameStore),
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
    const primary = Color(0xFF066FD1);
    const secondary = Color(0xFF90CAF9);
    const accent = Color(0xFFE6F0FA);
    const primaryText = Color(0xFF333333);
    const mutedText = Color(0xFF999999);
    final theme = Theme.of(context);
    final step = onboardingSteps[_currentIndex];

    return Scaffold(
      key: OnboardingScreen.markerKey,
      backgroundColor: accent,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _OnboardingBackdrop(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) {
                _dragDx += details.delta.dx;
              },
              onHorizontalDragEnd: _handleSwipeEnd,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: Column(
                  children: [
                    const Spacer(),
                    _OnboardingVisual(
                      index: _currentIndex,
                      primary: primary,
                      secondary: secondary,
                      accent: accent,
                    ),
                    const Spacer(),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          key: OnboardingScreen.contentKey,
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _StepIndicator(
                              currentIndex: _currentIndex,
                              totalSteps: onboardingSteps.length,
                            ),
                            const SizedBox(height: 18),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeOutCubic,
                              layoutBuilder: (currentChild, previousChildren) {
                                return currentChild ?? const SizedBox.shrink();
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
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: primaryText,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 10),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 260),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeOutCubic,
                              layoutBuilder: (currentChild, previousChildren) {
                                return currentChild ?? const SizedBox.shrink();
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
                                  color: mutedText,
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 22),
                            _OnboardingActions(
                              currentIndex: _currentIndex,
                              isCompleting: _isCompleting,
                              onBack: _goToPreviousStep,
                              onPrimary: _goToNextStep,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingBackdrop extends StatelessWidget {
  const _OnboardingBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(-1.1, -0.92),
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x3390CAF9),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(1.08, -0.55),
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(48),
                border: Border.all(color: const Color(0x33066FD1), width: 1.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingVisual extends StatelessWidget {
  const _OnboardingVisual({
    required this.index,
    required this.primary,
    required this.secondary,
    required this.accent,
  });

  final int index;
  final Color primary;
  final Color secondary;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final icon = switch (index) {
      0 => Icons.rocket_launch_rounded,
      1 => Icons.explore_rounded,
      2 => Icons.auto_awesome_motion_rounded,
      _ => Icons.check_circle_rounded,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      width: 144,
      height: 144,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: secondary.withValues(alpha: 0.35),
      ),
      child: Center(child: Icon(icon, size: 54, color: primary)),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentIndex, required this.totalSteps});

  final int currentIndex;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    const dotSize = 8.0;
    const gap = 6.0;
    final totalWidth = (totalSteps * dotSize) + ((totalSteps - 1) * gap);

    return SizedBox(
      width: totalWidth,
      height: dotSize,
      child: Stack(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              totalSteps,
              (index) => Container(
                width: dotSize,
                height: dotSize,
                margin: EdgeInsets.only(
                  right: index == totalSteps - 1 ? 0 : gap,
                ),
                decoration: BoxDecoration(
                  color: const Color(0x33066FD1),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            left: currentIndex * (dotSize + gap),
            child: Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: const Color(0xFF066FD1),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingActions extends StatelessWidget {
  const _OnboardingActions({
    required this.currentIndex,
    required this.isCompleting,
    required this.onBack,
    required this.onPrimary,
  });

  final int currentIndex;
  final bool isCompleting;
  final Future<void> Function() onBack;
  final Future<void> Function() onPrimary;

  @override
  Widget build(BuildContext context) {
    final isFirstStep = currentIndex == 0;
    final isLastStep = currentIndex == onboardingSteps.length - 1;
    final primaryLabel = isFirstStep
        ? 'Get Started'
        : isLastStep
        ? 'Continue'
        : 'Next';

    final primaryButton = FilledButton(
      onPressed: isCompleting ? null : () => onPrimary(),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: const Color(0xFF066FD1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: isCompleting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            )
          : Text(primaryLabel),
    );

    if (isFirstStep) {
      return SizedBox(width: double.infinity, child: primaryButton);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: isCompleting ? null : () => onBack(),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              side: const BorderSide(color: Color(0xFFE5E8EC)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            child: const Text('Back'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: primaryButton),
      ],
    );
  }
}
