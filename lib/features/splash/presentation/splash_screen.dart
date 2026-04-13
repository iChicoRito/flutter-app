import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/display_name_store.dart';
import '../../../core/services/onboarding_status_store.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../onboarding/presentation/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.onboardingStatusStore,
    required this.displayNameStore,
  });

  static const Key markerKey = Key('splash-screen');

  final OnboardingStatusStore onboardingStatusStore;
  final DisplayNameStore displayNameStore;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _displayDuration = Duration(seconds: 5);

  late final AnimationController _controller;
  late final Animation<double> _glowScale;
  late final Animation<double> _markScale;
  late final Animation<double> _markOpacity;
  late final Animation<Offset> _labelOffset;

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _glowScale = Tween<double>(
      begin: 0.92,
      end: 1.08,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _markScale = Tween<double>(
      begin: 0.96,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _markOpacity = Tween<double>(
      begin: 0.88,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _labelOffset = Tween<Offset>(
      begin: const Offset(0, 0.16),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _navigationTimer = Timer(_displayDuration, _navigateToNextScreen);
  }

  Future<void> _navigateToNextScreen() async {
    if (!mounted) {
      return;
    }

    final isCompleted = await widget.onboardingStatusStore.isCompleted();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (context, animation, secondaryAnimation) => isCompleted
            ? DashboardScreen(displayNameStore: widget.displayNameStore)
            : OnboardingScreen(
                onboardingStatusStore: widget.onboardingStatusStore,
                displayNameStore: widget.displayNameStore,
              ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          final slide = Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(fade);

          return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: slide, child: child),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF066FD1);
    const secondary = Color(0xFF90CAF9);
    const accent = Color(0xFFE6F0FA);

    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      key: SplashScreen.markerKey,
      backgroundColor: primary,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const _SplashBackdrop(),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _glowScale.value,
                          child: Container(
                            width: 204,
                            height: 204,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent.withValues(alpha: 0.18),
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, child) {
                          return FadeTransition(
                            opacity: _markOpacity,
                            child: Transform.scale(
                              scale: _markScale.value,
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          width: 136,
                          height: 136,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(42),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [accent, secondary],
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x3390CAF9),
                                blurRadius: 24,
                                offset: Offset(0, 14),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 58,
                                height: 58,
                                decoration: BoxDecoration(
                                  color: primary,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              Positioned(
                                top: 30,
                                child: Container(
                                  width: 18,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 30,
                                child: Container(
                                  width: 52,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    SlideTransition(
                      position: _labelOffset,
                      child: Column(
                        children: [
                          Text(
                            'Flutter App',
                            style: textTheme.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Launching a clean, calm, and polished mobile experience.',
                            style: textTheme.bodyLarge?.copyWith(
                              color: accent,
                              height: 1.45,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: 132,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: const LinearProgressIndicator(
                                minHeight: 5,
                                backgroundColor: Color(0x3390CAF9),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  accent,
                                ),
                              ),
                            ),
                          ),
                        ],
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

class _SplashBackdrop extends StatelessWidget {
  const _SplashBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Align(
            alignment: const Alignment(-1.15, -0.95),
            child: Container(
              width: 240,
              height: 240,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x3390CAF9),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(1.1, 0.9),
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x1FE6F0FA),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0.92, -0.58),
            child: Transform.rotate(
              angle: 0.78,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(34),
                  border: Border.all(
                    color: const Color(0x4DE6F0FA),
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
