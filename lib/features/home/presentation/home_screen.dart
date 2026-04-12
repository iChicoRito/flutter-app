import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const Key markerKey = Key('home-screen');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: KeyedSubtree(
          key: markerKey,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: const Icon(
                      Icons.waving_hand_rounded,
                      size: 40,
                      color: Color(0xFF1E88E5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Home Screen',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The custom splash screen has completed and the app is ready for the next experience.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF475569),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
