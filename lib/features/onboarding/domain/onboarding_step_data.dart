class OnboardingStepData {
  const OnboardingStepData({
    required this.title,
    required this.description,
    required this.assetPath,
  });

  final String title;
  final String description;
  final String assetPath;
}

const onboardingSteps = <OnboardingStepData>[
  OnboardingStepData(
    title: 'Welcome to RemindLy',
    description:
        'Your smart task companion that helps you remember what matters.',
    assetPath: 'assets/svgs/on-board/on-board-icon-1.svg',
  ),
  OnboardingStepData(
    title: 'Create Tasks Easily',
    description:
        'Add tasks in seconds, organize them by category, and set priorities.',
    assetPath: 'assets/svgs/on-board/on-board-icon-2.svg',
  ),
  OnboardingStepData(
    title: 'Never Miss a Reminder',
    description:
        'Set reminders for your tasks and get notified right on time, even when you\'re offline.',
    assetPath: 'assets/svgs/on-board/on-board-icon-3.svg',
  ),
  OnboardingStepData(
    title: 'Stay Focused & Productive',
    description:
        'Use built-in timers to stay focused, manage your time better, and complete your tasks.',
    assetPath: 'assets/svgs/on-board/on-board-icon-4.svg',
  ),
];
