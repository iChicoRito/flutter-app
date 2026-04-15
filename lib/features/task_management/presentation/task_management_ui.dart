import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tabler_icons/tabler_icons.dart';
import 'dart:async';

const taskPrimaryBlue = Color(0xFF066FD1);
const taskPrimaryPressed = Color(0xFF055CB0);
const taskSecondaryBlue = Color(0xFF90CAF9);
const taskAccentBlue = Color(0xFFE6F0FA);
const taskSurface = Color(0xFFF9FAFB);
const taskSurfaceAlt = Color(0xFFF3F6F9);
const taskBorderColor = Color(0xFFE5E8EC);
const taskMutedBorderColor = Color(0xFFEEF1F4);
const taskDarkText = Color(0xFF333333);
const taskSecondaryText = Color(0xFF6B7280);
const taskMutedText = Color(0xFF999999);
const taskDangerText = Color(0xFFD63939);
const taskFilterControlHeight = 44.0;
const taskSuccessText = Color(0xFF0CA678);
const taskWarningText = Color(0xFFF59F00);

OverlayEntry? _currentTaskToastEntry;

void showTaskToast(
  BuildContext context, {
  required String message,
  bool isError = false,
}) {
  _currentTaskToastEntry?.remove();
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) {
    return;
  }

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _TaskToastOverlay(
      message: message,
      isError: isError,
      onDismissed: () {
        if (_currentTaskToastEntry == entry) {
          _currentTaskToastEntry = null;
        }
        entry.remove();
      },
    ),
  );

  _currentTaskToastEntry = entry;
  overlay.insert(entry);
}

class _TaskToastOverlay extends StatefulWidget {
  const _TaskToastOverlay({
    required this.message,
    required this.isError,
    required this.onDismissed,
  });

  final String message;
  final bool isError;
  final VoidCallback onDismissed;

  @override
  State<_TaskToastOverlay> createState() => _TaskToastOverlayState();
}

class _TaskToastOverlayState extends State<_TaskToastOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 180),
  );
  late final Animation<Offset> _offset = Tween<Offset>(
    begin: const Offset(0, 0.2),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  bool _dismissed = false;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _showAndHide();
  }

  Future<void> _showAndHide() async {
    await _controller.forward();
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 2), () async {
      if (!mounted || _dismissed) {
        return;
      }
      await _controller.reverse();
      _dismissed = true;
      widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isError
        ? taskDangerText
        : const Color(0xFFE6F6F1);
    final foregroundColor = widget.isError ? Colors.white : taskSuccessText;

    return Positioned(
      left: 16,
      right: 16,
      bottom: 24 + MediaQuery.of(context).padding.bottom,
      child: IgnorePointer(
        child: SlideTransition(
          position: _offset,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.isError
                      ? backgroundColor
                      : foregroundColor.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                widget.message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration taskInputDecoration({
  required BuildContext context,
  required String hintText,
  Widget? prefixIcon,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: taskMutedText),
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: taskBorderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: taskBorderColor),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: taskPrimaryBlue),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: taskDangerText),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: taskDangerText),
    ),
  );
}

class TaskFieldLabel extends StatelessWidget {
  const TaskFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: taskDarkText,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class TaskSectionCard extends StatelessWidget {
  const TaskSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: taskBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: taskDarkText,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: taskSecondaryText),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1, color: taskBorderColor),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class TaskCompactDropdown<T> extends StatelessWidget {
  const TaskCompactDropdown({
    super.key,
    required this.buttonKey,
    required this.menuKeyBuilder,
    required this.currentValue,
    required this.currentLabel,
    required this.onSelected,
    required this.items,
    required this.labelBuilder,
    this.leadingBuilder,
    this.currentLeading,
  });

  final Key buttonKey;
  final Key Function(T value) menuKeyBuilder;
  final T currentValue;
  final String currentLabel;
  final ValueChanged<T> onSelected;
  final List<T> items;
  final String Function(T value) labelBuilder;
  final Widget? Function(T value)? leadingBuilder;
  final Widget? currentLeading;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      key: buttonKey,
      initialValue: currentValue,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      onSelected: onSelected,
      itemBuilder: (context) {
        return items.map((item) {
          return PopupMenuItem<T>(
            key: menuKeyBuilder(item),
            value: item,
            child: Row(
              children: [
                if (leadingBuilder?.call(item) case final leading?) ...[
                  leading,
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    labelBuilder(item),
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: taskDarkText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        constraints: const BoxConstraints(
          minHeight: taskFilterControlHeight,
          maxHeight: taskFilterControlHeight,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: taskBorderColor),
        ),
        child: Row(
          children: [
            if (currentLeading != null) ...[
              currentLeading!,
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                currentLabel,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: taskDarkText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              TablerIcons.chevron_down,
              size: 16,
              color: taskMutedText,
            ),
          ],
        ),
      ),
    );
  }
}

class TaskPickerButton extends StatelessWidget {
  const TaskPickerButton({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
    this.buttonKey,
  });

  final String title;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: buttonKey,
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: taskBorderColor, width: 1),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: taskAccentBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: taskPrimaryBlue, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: taskSecondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: taskDarkText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

ThemeData buildTaskPickerTheme(ThemeData baseTheme) {
  final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme);
  return baseTheme.copyWith(
    colorScheme: baseTheme.colorScheme.copyWith(
      primary: taskPrimaryBlue,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: taskDarkText,
    ),
    textTheme: textTheme,
    scaffoldBackgroundColor: Colors.white,
    canvasColor: Colors.white,
    dialogTheme: const DialogThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      rangePickerBackgroundColor: Colors.white,
      rangePickerSurfaceTintColor: Colors.white,
      headerBackgroundColor: Colors.white,
      headerForegroundColor: taskDarkText,
      dividerColor: taskBorderColor,
      rangeSelectionBackgroundColor: taskAccentBlue,
      todayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return taskPrimaryBlue;
      }),
      todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return taskPrimaryBlue;
        }
        return null;
      }),
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return taskDarkText;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return taskPrimaryBlue;
        }
        return null;
      }),
      yearForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return taskPrimaryBlue;
        }
        return taskDarkText;
      }),
      yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return taskAccentBlue;
        }
        return null;
      }),
      rangeSelectionOverlayColor: WidgetStateProperty.all(
        taskPrimaryBlue.withValues(alpha: 0.08),
      ),
      dayOverlayColor: WidgetStateProperty.all(
        taskPrimaryBlue.withValues(alpha: 0.08),
      ),
      yearOverlayColor: WidgetStateProperty.all(
        taskPrimaryBlue.withValues(alpha: 0.08),
      ),
    ),
  );
}
