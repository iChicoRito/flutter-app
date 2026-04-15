## Objective: Application Branding and Onboarding Enhancement

### 1. Apply Branding

The application now has an official name: **Remindly**.

**About the app:**
Remindly is a task and notes application designed for users who often forget important things they need to do. Unlike a basic to-do list, Remindly actively helps users remember their tasks through **alarms** and **push notifications**, making it a smart and reliable reminder companion.

**Goal:**
Update the app’s branding to reflect the name **Remindly** across the user experience where needed.

---

### 2. Remove Splash Screen Completely

The app should no longer display a splash screen.

**Required changes:**

* Remove the splash screen UI
* Delete any unused splash screen files, widgets, routes, and logic
* Remove related navigation code
* Make sure the app opens **directly to the onboarding screen** on launch

**Expected behavior:**
When the user opens the app, it should go straight to onboarding without showing any splash screen first.

---

### 3. Update Onboarding Content

Replace the current onboarding placeholder content with the following:

```dart
const onboardingSteps = <OnboardingStepData>[
  OnboardingStepData(
    title: 'Welcome to Remindly',
    description:
        'Your smart task companion that helps you remember what matters. Stay on top of your day with simple, powerful tools.',
  ),
  OnboardingStepData(
    title: 'Create Tasks Easily',
    description:
        'Add tasks in seconds, organize them by category, and set priorities so you always know what to focus on.',
  ),
  OnboardingStepData(
    title: 'Never Miss a Reminder',
    description:
        'Set reminders for your tasks and get notified right on time, even when you’re offline.',
  ),
  OnboardingStepData(
    title: 'Stay Focused & Productive',
    description:
        'Use built-in timers to stay focused, manage your time better, and complete your tasks with confidence.',
  ),
];
```

**Also update the onboarding icons so they match each step properly:**

* **Welcome to Remindly** → use a friendly branding icon, such as `task_alt`, `check_circle_outline`, or a custom Remindly logo
* **Create Tasks Easily** → use `edit_note`, `playlist_add_check`, or `fact_check`
* **Never Miss a Reminder** → use `notifications_active`, `alarm`, or `access_alarm`
* **Stay Focused & Productive** → use `timer`, `hourglass_bottom`, or `track_changes`

**Goal:**
Each onboarding step should have an icon that visually supports its message.

---

### 4. Improve Welcome Modal Button Style

For new users, after they enter their name, a **Welcome modal** is shown.

**Change needed:**
The current button style is too pill-shaped.

**Update the button to:**

* be **full width**
* use a **standard rounded rectangle**
* have a **moderate border radius** instead of a pill shape

**Recommended style:**

* full width inside the modal/card
* border radius around **10–14**
* comfortable vertical padding
* clean and modern appearance

**Expected result:**
The button should feel more balanced and consistent with the card layout, instead of looking overly rounded.

---

## Enhanced Development Notes

### Navigation flow

New app launch flow should be:

**App Launch → Onboarding Screen → Name Input → Welcome Modal → Continue to App**

There should be **no splash screen** in between.

### UI consistency

Please also make sure:

* onboarding layout feels clean and branded for Remindly
* icons, titles, and descriptions are aligned consistently
* spacing and typography are polished
* button styling matches the rest of the app design system

---