class OnboardingStepData {
  const OnboardingStepData({required this.title, required this.description});

  final String title;
  final String description;
}

const onboardingSteps = <OnboardingStepData>[
  OnboardingStepData(
    title: 'Welcome Aboard',
    description:
        'Placeholder text for your opening message. Use this step to introduce the app in a simple, friendly way.',
  ),
  OnboardingStepData(
    title: 'Discover Features',
    description:
        'Placeholder text for key capabilities. Highlight the main things users can do without overcrowding the layout.',
  ),
  OnboardingStepData(
    title: 'Stay Organized',
    description:
        'Placeholder text for helpful routines, reminders, or tools that make the experience feel clear and manageable.',
  ),
  OnboardingStepData(
    title: 'Ready To Begin',
    description:
        'Placeholder text for the final onboarding message. Encourage users to continue into the app with confidence.',
  ),
];
