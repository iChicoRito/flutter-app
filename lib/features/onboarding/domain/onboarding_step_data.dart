import 'package:flutter/material.dart';

class OnboardingStepData {
  const OnboardingStepData({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

const onboardingSteps = <OnboardingStepData>[
  OnboardingStepData(
    title: 'Welcome to RemindLy',
    description:
        'Your smart task companion that helps you remember what matters. Stay on top of your day with simple, powerful tools.',
    icon: Icons.task_alt_rounded,
  ),
  OnboardingStepData(
    title: 'Create Tasks Easily',
    description:
        'Add tasks in seconds, organize them by category, and set priorities so you always know what to focus on.',
    icon: Icons.edit_note_rounded,
  ),
  OnboardingStepData(
    title: 'Never Miss a Reminder',
    description:
        'Set reminders for your tasks and get notified right on time, even when you\'re offline.',
    icon: Icons.notifications_active_rounded,
  ),
  OnboardingStepData(
    title: 'Stay Focused & Productive',
    description:
        'Use built-in timers to stay focused, manage your time better, and complete your tasks with confidence.',
    icon: Icons.timer_rounded,
  ),
];
