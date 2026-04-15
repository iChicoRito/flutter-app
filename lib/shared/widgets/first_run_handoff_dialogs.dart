import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tabler_icons/tabler_icons.dart';

class FirstRunHandoffKeys {
  const FirstRunHandoffKeys._();

  static const Key namePrompt = Key('dashboard-name-prompt');
  static const Key nameField = Key('dashboard-name-field');
  static const Key nameSaveButton = Key('dashboard-name-save');
  static const Key welcomeScreen = Key('dashboard-welcome-screen');
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
    const taskPrimaryBlue = Color(0xFF066FD1);
    const taskSecondaryText = Color(0xFF6B7280);
    const taskDarkText = Color(0xFF333333);

    return Dialog(
      key: FirstRunHandoffKeys.namePrompt,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'What should we call you?',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: taskDarkText,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your name personalizes your Remindly reminders and welcome flow.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: taskSecondaryText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              key: FirstRunHandoffKeys.nameField,
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Enter your name',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE5E8EC)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE5E8EC)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: taskPrimaryBlue,
                    width: 1.4,
                  ),
                ),
              ),
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: FirstRunHandoffKeys.nameSaveButton,
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: taskPrimaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Save'),
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
  bool _showButton = false;

  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showButton = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const taskPrimaryBlue = Color(0xFF066FD1);
    const taskAccentBlue = Color(0xFFE6F0FA);
    const taskSecondaryText = Color(0xFF6B7280);
    const taskDarkText = Color(0xFF333333);

    return Dialog(
      key: FirstRunHandoffKeys.welcomeScreen,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: taskAccentBlue,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                TablerIcons.sparkles,
                color: taskPrimaryBlue,
                size: 32,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Welcome, ${widget.displayName}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: taskDarkText,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your Remindly dashboard is ready with tasks, notes, and reminders to keep you on track.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: taskSecondaryText,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            if (_showButton)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: FirstRunHandoffKeys.welcomeButton,
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: taskPrimaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Let\'s Go'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
