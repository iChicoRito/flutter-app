import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tabler_icons/tabler_icons.dart';
import 'dart:async';

import '../../../core/theme/app_design_tokens.dart';
import '../../../core/vault/vault_models.dart';
import '../domain/task_category.dart';
import '../domain/task_item.dart';

const taskPrimaryBlue = AppColors.blue500;
const taskPrimaryPressed = AppColors.blue600;
const taskPrimaryDisabled = AppColors.blue200;
const taskSecondaryBlue = AppColors.blue200;
const taskAccentBlue = AppColors.blue100;
const taskSurface = AppColors.background;
const taskSurfaceAlt = AppColors.checkboxCardFill;
const taskBorderColor = AppColors.cardBorder;
const taskMutedBorderColor = AppColors.checkboxCardBorder;
const taskDarkText = AppColors.titleText;
const taskSecondaryText = AppColors.subHeaderText;
const taskMutedText = AppColors.subHeaderText;
const taskDisabledText = AppColors.neutral200;
const taskDangerText = AppColors.rose500;
const taskDangerPressed = AppColors.rose500;
const taskDangerDisabled = AppColors.rose100;
const taskFilterControlHeight = 44.0;
const taskSuccessText = AppColors.teal500;
const taskWarningText = AppColors.amber500;

enum TaskCardTone { primary, success, danger, warning }

Key taskCategoryColorChoiceKey(String scope, Color color) =>
    Key('$scope-category-color-${color.toARGB32()}');

Key taskCategorySelectedColorCheckKey(String scope, Color color) =>
    Key('$scope-category-color-check-${color.toARGB32()}');

class TaskCardAppearance {
  const TaskCardAppearance({
    required this.accentColor,
    required this.badgeBackgroundColor,
    required this.badgeForegroundColor,
    required this.lockedForegroundColor,
  });

  final Color accentColor;
  final Color badgeBackgroundColor;
  final Color badgeForegroundColor;
  final Color lockedForegroundColor;
}

Color _taskBadgeBackgroundFor(Color color) {
  final argb = color.toARGB32();
  if (argb == AppColors.blue500.toARGB32()) {
    return AppColors.blue100;
  }
  if (argb == AppColors.teal500.toARGB32()) {
    return AppColors.teal100;
  }
  if (argb == AppColors.rose500.toARGB32()) {
    return AppColors.rose100;
  }
  if (argb == AppColors.amber500.toARGB32()) {
    return AppColors.amber100;
  }
  return color.withValues(alpha: 0.16);
}

TaskCardAppearance taskCardAppearanceForCategory({
  required Color categoryColor,
  required bool previewProtected,
}) {
  if (previewProtected) {
    return const TaskCardAppearance(
      accentColor: AppColors.rose500,
      badgeBackgroundColor: AppColors.rose100,
      badgeForegroundColor: AppColors.rose500,
      lockedForegroundColor: AppColors.subHeaderText,
    );
  }

  return TaskCardAppearance(
    accentColor: categoryColor,
    badgeBackgroundColor: _taskBadgeBackgroundFor(categoryColor),
    badgeForegroundColor: categoryColor,
    lockedForegroundColor: AppColors.subHeaderText,
  );
}

TaskCardTone taskCardToneFor({
  required TaskItem task,
  required bool previewProtected,
}) {
  if (previewProtected) {
    return TaskCardTone.danger;
  }

  return switch (task.priority) {
    TaskPriority.low => TaskCardTone.success,
    TaskPriority.high => TaskCardTone.warning,
    TaskPriority.urgent => TaskCardTone.danger,
    TaskPriority.medium => TaskCardTone.primary,
  };
}

TaskCardAppearance taskCardAppearance(TaskCardTone tone) {
  return switch (tone) {
    TaskCardTone.primary => const TaskCardAppearance(
      accentColor: AppColors.blue500,
      badgeBackgroundColor: AppColors.blue100,
      badgeForegroundColor: AppColors.blue500,
      lockedForegroundColor: AppColors.subHeaderText,
    ),
    TaskCardTone.success => const TaskCardAppearance(
      accentColor: AppColors.teal500,
      badgeBackgroundColor: AppColors.teal100,
      badgeForegroundColor: AppColors.teal500,
      lockedForegroundColor: AppColors.subHeaderText,
    ),
    TaskCardTone.danger => const TaskCardAppearance(
      accentColor: AppColors.rose500,
      badgeBackgroundColor: AppColors.rose100,
      badgeForegroundColor: AppColors.rose500,
      lockedForegroundColor: AppColors.subHeaderText,
    ),
    TaskCardTone.warning => const TaskCardAppearance(
      accentColor: AppColors.amber500,
      badgeBackgroundColor: AppColors.amber100,
      badgeForegroundColor: AppColors.amber500,
      lockedForegroundColor: AppColors.subHeaderText,
    ),
  };
}

BoxDecoration taskCardShellDecoration() {
  return BoxDecoration(
    color: AppColors.cardFill,
    borderRadius: BorderRadius.circular(AppRadii.twoXl),
    border: Border.all(
      color: AppColors.cardBorder,
      width: AppSizes.borderDefault,
    ),
  );
}

BoxDecoration taskCardBadgeDecoration(TaskCardAppearance appearance) {
  return BoxDecoration(
    color: appearance.badgeBackgroundColor,
    borderRadius: BorderRadius.circular(AppRadii.full),
  );
}

enum TaskButtonRole { primary, secondary, destructive, ghost }

enum TaskButtonSize { large, medium, small }

class _TaskButtonPalette {
  const _TaskButtonPalette({
    required this.background,
    required this.pressedBackground,
    required this.disabledBackground,
    required this.foreground,
    required this.disabledForeground,
    this.borderColor,
    this.disabledBorderColor,
  });

  final Color background;
  final Color pressedBackground;
  final Color disabledBackground;
  final Color foreground;
  final Color disabledForeground;
  final Color? borderColor;
  final Color? disabledBorderColor;
}

_TaskButtonPalette _taskButtonPalette(TaskButtonRole role) {
  return switch (role) {
    TaskButtonRole.primary => const _TaskButtonPalette(
      background: AppColors.primaryButtonFill,
      pressedBackground: AppColors.blue600,
      disabledBackground: AppColors.blue200,
      foreground: AppColors.primaryButtonText,
      disabledForeground: AppColors.primaryButtonText,
    ),
    TaskButtonRole.secondary => const _TaskButtonPalette(
      background: AppColors.secondaryButtonFill,
      pressedBackground: AppColors.secondaryButtonFill,
      disabledBackground: AppColors.neutral200,
      foreground: AppColors.secondaryButtonText,
      disabledForeground: AppColors.neutral400,
    ),
    TaskButtonRole.destructive => const _TaskButtonPalette(
      background: AppColors.dangerButtonFill,
      pressedBackground: AppColors.rose500,
      disabledBackground: AppColors.rose100,
      foreground: AppColors.dangerButtonText,
      disabledForeground: AppColors.dangerButtonText,
    ),
    TaskButtonRole.ghost => const _TaskButtonPalette(
      background: AppColors.neutral200,
      pressedBackground: AppColors.neutral200,
      disabledBackground: AppColors.neutral100,
      foreground: AppColors.titleText,
      disabledForeground: AppColors.subHeaderText,
      borderColor: AppColors.cardBorder,
      disabledBorderColor: AppColors.cardBorder,
    ),
  };
}

double taskButtonHeight(TaskButtonSize size) {
  return switch (size) {
    TaskButtonSize.large => 54,
    TaskButtonSize.medium => 44,
    TaskButtonSize.small => 40,
  };
}

double taskButtonRadius(TaskButtonSize size) {
  return switch (size) {
    TaskButtonSize.large => AppRadii.twoXl,
    TaskButtonSize.medium => AppRadii.twoXl,
    TaskButtonSize.small => AppRadii.twoXl,
  };
}

double taskButtonIconSize(TaskButtonSize size) {
  return switch (size) {
    TaskButtonSize.large => 18,
    TaskButtonSize.medium => 16,
    TaskButtonSize.small => 16,
  };
}

EdgeInsetsGeometry taskButtonPadding(TaskButtonSize size) {
  return switch (size) {
    TaskButtonSize.large => const EdgeInsets.symmetric(
      horizontal: AppSpacing.five,
      vertical: AppSpacing.five,
    ),
    TaskButtonSize.medium => const EdgeInsets.symmetric(
      horizontal: AppSpacing.five,
      vertical: AppSpacing.five,
    ),
    TaskButtonSize.small => const EdgeInsets.symmetric(
      horizontal: AppSpacing.five,
      vertical: AppSpacing.five,
    ),
  };
}

TextStyle? taskButtonTextStyle(BuildContext context, TaskButtonSize size) {
  final base = Theme.of(context).textTheme.labelLarge;
  return base?.copyWith(
    fontSize: switch (size) {
      TaskButtonSize.large => AppTypography.sizeBase,
      TaskButtonSize.medium => AppTypography.sizeSm,
      TaskButtonSize.small => AppTypography.sizeSm,
    },
    fontWeight: AppTypography.weightSemibold,
  );
}

ButtonStyle taskButtonStyle(
  BuildContext context, {
  required TaskButtonRole role,
  TaskButtonSize size = TaskButtonSize.medium,
  EdgeInsetsGeometry? padding,
  Size? minimumSize,
  bool shrinkTapTarget = false,
}) {
  final palette = _taskButtonPalette(role);
  final resolvedPadding = padding ?? taskButtonPadding(size);
  final resolvedMinimumSize = minimumSize ?? Size(0, taskButtonHeight(size));
  final borderRadius = BorderRadius.circular(taskButtonRadius(size));

  return ButtonStyle(
    minimumSize: WidgetStatePropertyAll(resolvedMinimumSize),
    padding: WidgetStatePropertyAll(resolvedPadding),
    elevation: const WidgetStatePropertyAll(0),
    tapTargetSize: shrinkTapTarget
        ? MaterialTapTargetSize.shrinkWrap
        : MaterialTapTargetSize.padded,
    visualDensity: const VisualDensity(horizontal: 0, vertical: 0),
    textStyle: WidgetStatePropertyAll(taskButtonTextStyle(context, size)),
    iconSize: WidgetStatePropertyAll(taskButtonIconSize(size)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: borderRadius),
    ),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return palette.disabledBackground;
      }
      if (states.contains(WidgetState.pressed)) {
        return palette.pressedBackground;
      }
      return palette.background;
    }),
    foregroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) {
        return palette.disabledForeground;
      }
      return palette.foreground;
    }),
    side: WidgetStateProperty.resolveWith((states) {
      final borderColor = states.contains(WidgetState.disabled)
          ? palette.disabledBorderColor
          : palette.borderColor;
      if (borderColor == null) {
        return BorderSide.none;
      }
      return BorderSide(color: borderColor);
    }),
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  );
}

BoxDecoration taskActionTileDecoration({
  required TaskButtonRole role,
  TaskButtonSize size = TaskButtonSize.medium,
}) {
  final palette = _taskButtonPalette(role);
  return BoxDecoration(
    color: palette.background,
    borderRadius: BorderRadius.circular(taskButtonRadius(size) + 6),
    border: palette.borderColor == null
        ? null
        : Border.all(color: palette.borderColor!),
  );
}

OverlayEntry? _currentTaskToastEntry;

void showTaskToast(
  BuildContext context, {
  required String message,
  bool isError = false,
  Color? backgroundColor,
  Color? foregroundColor,
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
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
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
    this.backgroundColor,
    this.foregroundColor,
    required this.onDismissed,
  });

  final String message;
  final bool isError;
  final Color? backgroundColor;
  final Color? foregroundColor;
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
    final backgroundColor =
        widget.backgroundColor ??
        (widget.isError ? AppColors.rose500 : AppColors.teal100);
    final foregroundColor =
        widget.foregroundColor ??
        (widget.isError ? AppColors.rose50 : AppColors.teal500);

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
  Color? fillColor,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: AppColors.subHeaderText),
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: fillColor ?? AppColors.cardFill,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.four,
      vertical: AppSpacing.three,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.xl),
      borderSide: const BorderSide(color: AppColors.neutral200),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.xl),
      borderSide: const BorderSide(color: AppColors.neutral200),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.xl),
      borderSide: const BorderSide(color: AppColors.blue500),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.xl),
      borderSide: const BorderSide(color: AppColors.rose500),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.xl),
      borderSide: const BorderSide(color: AppColors.rose500),
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
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AppColors.titleText,
        fontWeight: AppTypography.weightSemibold,
        fontSize: AppTypography.sizeBase,
      ),
    );
  }
}

class TaskCategoryColorSelector extends StatelessWidget {
  const TaskCategoryColorSelector({
    super.key,
    required this.scope,
    required this.selectedColor,
    required this.onSelected,
  });

  final String scope;
  final Color selectedColor;
  final ValueChanged<Color> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final color in taskCategoryColorOptions)
          _TaskCategoryColorChoiceChip(
            key: taskCategoryColorChoiceKey(scope, color),
            color: color,
            selected: selectedColor.toARGB32() == color.toARGB32(),
            selectedCheckKey: taskCategorySelectedColorCheckKey(scope, color),
            onTap: () => onSelected(color),
          ),
      ],
    );
  }
}

class _TaskCategoryColorChoiceChip extends StatelessWidget {
  const _TaskCategoryColorChoiceChip({
    super.key,
    required this.color,
    required this.selected,
    required this.selectedCheckKey,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final Key selectedCheckKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.full),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.cardFill, width: 2),
        ),
        child: selected
            ? Icon(
                key: selectedCheckKey,
                Icons.check_rounded,
                color: AppColors.white,
                size: 22,
              )
            : null,
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.eight,
        vertical: AppSpacing.six,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(AppRadii.threeXl),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.titleText,
              fontWeight: AppTypography.weightSemibold,
              fontSize: AppTypography.sizeLg,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.one),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.subHeaderText,
                fontSize: AppTypography.sizeBase,
                fontWeight: AppTypography.weightNormal,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.four),
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
      color: AppColors.cardFill,
      surfaceTintColor: AppColors.cardFill,
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
                      color: AppColors.titleText,
                      fontSize: AppTypography.sizeBase,
                      fontWeight: AppTypography.weightNormal,
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.four),
        decoration: BoxDecoration(
          color: AppColors.cardFill,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(color: AppColors.neutral200),
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
                  color: AppColors.titleText,
                  fontSize: AppTypography.sizeBase,
                  fontWeight: AppTypography.weightNormal,
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

class TaskMenuEntry extends StatelessWidget {
  const TaskMenuEntry({
    super.key,
    required this.icon,
    required this.label,
    this.color = taskDarkText,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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
      borderRadius: BorderRadius.circular(AppRadii.xl),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.cardFill,
          borderRadius: BorderRadius.circular(AppRadii.xl),
          border: Border.all(
            color: AppColors.neutral100,
            width: AppSizes.borderDefault,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.four,
          vertical: AppSpacing.three,
        ),
        child: Row(
          children: [
            Container(
              width: AppSpacing.ten,
              height: AppSpacing.ten,
              decoration: BoxDecoration(
                color: taskAccentBlue,
                borderRadius: BorderRadius.circular(AppRadii.xl),
              ),
              child: Icon(icon, color: taskPrimaryBlue, size: 18),
            ),
            const SizedBox(width: AppSpacing.three),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: taskSecondaryText,
                      fontSize: AppTypography.sizeSm,
                      fontWeight: AppTypography.weightNormal,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.one),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: taskDarkText,
                      fontSize: AppTypography.sizeBase,
                      fontWeight: AppTypography.weightNormal,
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
  final textTheme = GoogleFonts.interTextTheme(baseTheme.textTheme);
  return baseTheme.copyWith(
    colorScheme: baseTheme.colorScheme.copyWith(
      primary: AppColors.blue500,
      onPrimary: AppColors.blue50,
      surface: AppColors.cardFill,
      onSurface: AppColors.titleText,
    ),
    textTheme: textTheme,
    scaffoldBackgroundColor: AppColors.cardFill,
    canvasColor: AppColors.cardFill,
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.cardFill,
      surfaceTintColor: AppColors.cardFill,
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: AppColors.cardFill,
      surfaceTintColor: AppColors.cardFill,
      rangePickerBackgroundColor: AppColors.cardFill,
      rangePickerSurfaceTintColor: AppColors.cardFill,
      headerBackgroundColor: AppColors.cardFill,
      headerForegroundColor: AppColors.titleText,
      dividerColor: AppColors.cardBorder,
      rangeSelectionBackgroundColor: AppColors.blue100,
      todayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.blue50;
        }
        return AppColors.blue500;
      }),
      todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.blue500;
        }
        return null;
      }),
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.blue50;
        }
        return AppColors.titleText;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.blue500;
        }
        return null;
      }),
      yearForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.blue500;
        }
        return AppColors.titleText;
      }),
      yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.blue100;
        }
        return null;
      }),
      rangeSelectionOverlayColor: WidgetStateProperty.all(
        AppColors.blue500.withValues(alpha: 0.08),
      ),
      dayOverlayColor: WidgetStateProperty.all(
        AppColors.blue500.withValues(alpha: 0.08),
      ),
      yearOverlayColor: WidgetStateProperty.all(
        AppColors.blue500.withValues(alpha: 0.08),
      ),
    ),
  );
}

class VaultSettingsFields extends StatelessWidget {
  const VaultSettingsFields({
    super.key,
    required this.enabled,
    required this.method,
    required this.secretController,
    required this.hasExistingSecret,
    required this.isDeviceSecurityAvailable,
    required this.onEnabledChanged,
    required this.onMethodChanged,
    this.isEditing = false,
    this.changeVault = false,
    this.onChangeVaultChanged,
  });

  final bool enabled;
  final VaultMethod? method;
  final TextEditingController secretController;
  final bool hasExistingSecret;
  final bool? isDeviceSecurityAvailable;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<VaultMethod> onMethodChanged;
  final bool isEditing;
  final bool changeVault;
  final ValueChanged<bool>? onChangeVaultChanged;

  bool get _showsSecretField =>
      method == VaultMethod.password || method == VaultMethod.pin;

  bool get _usesEditChangeFlow =>
      isEditing && hasExistingSecret && _showsSecretField;

  bool get _shouldShowSecretField =>
      _showsSecretField && enabled && (!_usesEditChangeFlow || changeVault);

  bool get _shouldShowMethodDropdown => enabled && !_usesEditChangeFlow;

  bool get _shouldValidateSecret =>
      enabled && _showsSecretField && (!_usesEditChangeFlow || changeVault);

  @override
  Widget build(BuildContext context) {
    return TaskSectionCard(
      title: 'Vault',
      subtitle: 'Protect this item with a password',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_usesEditChangeFlow)
            SwitchListTile.adaptive(
              value: changeVault,
              onChanged: onChangeVaultChanged,
              contentPadding: EdgeInsets.zero,
              activeThumbColor: Colors.white,
              activeTrackColor: taskPrimaryBlue,
              title: Text(
                'Change Vault',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: taskDarkText,
                  fontSize: AppTypography.sizeBase,
                  fontWeight: AppTypography.weightSemibold,
                ),
              ),
              subtitle: Text(
                'Leave this off to keep the current ${method == VaultMethod.pin ? 'PIN' : 'password'} unchanged.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: taskSecondaryText,
                  fontSize: AppTypography.sizeSm,
                  fontWeight: AppTypography.weightNormal,
                ),
              ),
            )
          else
            SwitchListTile.adaptive(
              value: enabled,
              onChanged: onEnabledChanged,
              contentPadding: EdgeInsets.zero,
              activeThumbColor: Colors.white,
              activeTrackColor: taskPrimaryBlue,
              title: Text(
                'Enable Vault',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: taskDarkText,
                  fontSize: AppTypography.sizeBase,
                  fontWeight: AppTypography.weightSemibold,
                ),
              ),
              subtitle: Text(
                'Require an authentication',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: taskSecondaryText,
                  fontSize: AppTypography.sizeSm,
                  fontWeight: AppTypography.weightNormal,
                ),
              ),
            ),
          if (_usesEditChangeFlow && !changeVault) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.blue100,
                borderRadius: BorderRadius.circular(AppRadii.twoXl),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Text(
                'Current security method: ${_vaultMethodLabel(method ?? VaultMethod.password)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.blue500,
                  fontWeight: AppTypography.weightSemibold,
                ),
              ),
            ),
          ],
          if (enabled &&
              (_shouldShowMethodDropdown || _shouldShowSecretField)) ...[
            const SizedBox(height: 8),
            if (_shouldShowMethodDropdown) ...[
              const TaskFieldLabel('Security Method'),
              const SizedBox(height: 8),
              TaskCompactDropdown<VaultMethod>(
                buttonKey: const Key('vault-method-dropdown'),
                menuKeyBuilder: (value) => Key('vault-method-${value.name}'),
                currentValue: method ?? VaultMethod.password,
                currentLabel: _vaultMethodLabel(method ?? VaultMethod.password),
                onSelected: onMethodChanged,
                items: VaultMethod.values,
                labelBuilder: _vaultMethodLabel,
              ),
            ],
            if (_shouldShowSecretField) ...[
              const SizedBox(height: 16),
              TaskFieldLabel(
                _usesEditChangeFlow
                    ? method == VaultMethod.pin
                          ? 'New 4-Digit PIN'
                          : 'New Password'
                    : method == VaultMethod.pin
                    ? '4-Digit PIN'
                    : 'Password',
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: secretController,
                keyboardType: method == VaultMethod.pin
                    ? TextInputType.number
                    : TextInputType.text,
                obscureText: true,
                maxLength: method == VaultMethod.pin ? 4 : null,
                decoration: taskInputDecoration(
                  context: context,
                  hintText: hasExistingSecret
                      ? _usesEditChangeFlow
                            ? method == VaultMethod.pin
                                  ? 'Enter a new 4-digit PIN'
                                  : 'Enter a new password'
                            : method == VaultMethod.pin
                            ? 'Leave blank to keep the current PIN'
                            : 'Leave blank to keep the current password'
                      : method == VaultMethod.pin
                      ? 'Enter 4-digit PIN (xxxx)'
                      : 'Enter password',
                ).copyWith(counterText: ''),
                validator: (value) {
                  if (!_shouldValidateSecret) {
                    return null;
                  }
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return hasExistingSecret
                        ? _usesEditChangeFlow
                              ? method == VaultMethod.pin
                                    ? 'PIN is required.'
                                    : 'Password is required.'
                              : null
                        : method == VaultMethod.pin
                        ? 'PIN is required.'
                        : 'Password is required.';
                  }
                  if (method == VaultMethod.pin &&
                      !RegExp(r'^\d{4}$').hasMatch(trimmed)) {
                    return 'PIN must be exactly 4 digits.';
                  }
                  return null;
                },
              ),
            ],
            if (_shouldShowMethodDropdown &&
                method == VaultMethod.deviceSecurity) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.blue100,
                  borderRadius: BorderRadius.circular(AppRadii.twoXl),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Text(
                  isDeviceSecurityAvailable == false
                      ? 'Device security is not available on this device yet.'
                      : 'This uses your phone biometric or device passcode prompt.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDeviceSecurityAvailable == false
                        ? AppColors.rose500
                        : AppColors.blue500,
                    fontWeight: AppTypography.weightSemibold,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  static String _vaultMethodLabel(VaultMethod method) {
    return switch (method) {
      VaultMethod.password => 'Custom Password',
      VaultMethod.pin => '4-digit PIN',
      VaultMethod.deviceSecurity => 'Device Security',
    };
  }
}

class TaskFormPageHeader extends StatelessWidget {
  const TaskFormPageHeader({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(
            TablerIcons.chevron_left,
            color: AppColors.subHeaderText,
            size: AppTypography.sizeLg,
          ),
          splashRadius: AppSpacing.five,
          constraints: const BoxConstraints.tightFor(
            width: AppSpacing.six,
            height: AppSpacing.six,
          ),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(width: AppSpacing.one),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.titleText,
              fontSize: AppTypography.sizeLg,
              fontWeight: AppTypography.weightSemibold,
            ),
          ),
        ),
      ],
    );
  }
}
