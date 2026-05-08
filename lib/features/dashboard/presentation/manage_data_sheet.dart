import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:tabler_icons/tabler_icons.dart';

import '../../../core/theme/app_design_tokens.dart';
import '../../task_management/data/app_data_transfer_service.dart';
import '../../task_management/presentation/task_management_ui.dart';

enum _ManageDataMode { importData, exportData }

const int _maxImportFileSizeBytes = 25 * 1024 * 1024;

class ManageDataSheet extends StatefulWidget {
  const ManageDataSheet({
    super.key,
    required this.onImportRequested,
    required this.onExportRequested,
    this.onPickImportFile,
  });

  static const Key modeSegmentKey = Key('manage-data-mode-segment');
  static const Key importModeKey = Key('manage-data-import-mode');
  static const Key exportModeKey = Key('manage-data-export-mode');
  static const Key pickFileButtonKey = Key('manage-data-pick-file');
  static const Key submitButtonKey = Key('manage-data-submit');
  static const Key selectedFileCardKey = Key('manage-data-selected-file');
  static const Key includeTasksKey = Key('manage-data-include-tasks');
  static const Key includeSpacesKey = Key('manage-data-include-spaces');

  final Future<AppDataImportResult> Function(PlatformFile file)
  onImportRequested;
  final Future<void> Function(AppDataExportSelection selection)
  onExportRequested;
  final Future<PlatformFile?> Function()? onPickImportFile;

  @override
  State<ManageDataSheet> createState() => _ManageDataSheetState();
}

class _ManageDataSheetState extends State<ManageDataSheet> {
  _ManageDataMode _mode = _ManageDataMode.importData;
  PlatformFile? _selectedFile;
  bool _includeTasks = true;
  bool _includeSpaces = true;
  bool _isWorking = false;

  Future<PlatformFile?> _pickImportFile() async {
    final picker = widget.onPickImportFile ?? _pickFileFromDevice;
    final file = await picker();
    if (!mounted || file == null) {
      return null;
    }

    final extension = file.extension?.toLowerCase();
    if (extension != 'json') {
      showTaskToast(
        context,
        message: 'Please choose a JSON file.',
        isError: true,
      );
      return null;
    }

    if (file.size > _maxImportFileSizeBytes) {
      showTaskToast(
        context,
        message: 'The selected file is larger than 25 MB.',
        isError: true,
      );
      return null;
    }

    setState(() {
      _selectedFile = file;
    });
    return file;
  }

  Future<PlatformFile?> _pickFileFromDevice() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }
    return result.files.single;
  }

  Future<void> _submitImport() async {
    final file = _selectedFile;
    if (file == null || _isWorking) {
      return;
    }

    setState(() {
      _isWorking = true;
    });

    try {
      final result = await widget.onImportRequested(file);
      if (!mounted) {
        return;
      }
      showTaskToast(
        context,
        message:
            'Imported ${result.taskCount} task${result.taskCount == 1 ? '' : 's'} '
            'and ${result.spaceCount} space${result.spaceCount == 1 ? '' : 's'}.',
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      showTaskToast(
        context,
        message: 'Unable to import the selected file right now.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  Future<void> _submitExport() async {
    if (_isWorking || (!_includeTasks && !_includeSpaces)) {
      return;
    }

    setState(() {
      _isWorking = true;
    });

    try {
      await widget.onExportRequested(
        AppDataExportSelection(
          includeTasks: _includeTasks,
          includeSpaces: _includeSpaces,
        ),
      );
      if (!mounted) {
        return;
      }
      showTaskToast(context, message: 'Data export ready to share.');
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) {
        return;
      }
      showTaskToast(
        context,
        message: 'Unable to export data right now.',
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TaskSheetHeader(
                  title: 'Upload File',
                  subtitle: 'Drop the file to import or export your data.',
                ),
                const SizedBox(height: 18),
                _ManageDataModeSegmentedControl(
                  key: ManageDataSheet.modeSegmentKey,
                  value: _mode,
                  onChanged: _isWorking
                      ? null
                      : (value) {
                          setState(() {
                            _mode = value;
                          });
                        },
                ),
                const SizedBox(height: 18),
                _mode == _ManageDataMode.importData
                    ? _ImportDataPanel(
                        key: ManageDataSheet.importModeKey,
                        selectedFile: _selectedFile,
                        isWorking: _isWorking,
                        onPickFile: _pickImportFile,
                        onClearFile: () {
                          if (_isWorking) {
                            return;
                          }
                          setState(() {
                            _selectedFile = null;
                          });
                        },
                      )
                    : _ExportDataPanel(
                        key: ManageDataSheet.exportModeKey,
                        includeTasks: _includeTasks,
                        includeSpaces: _includeSpaces,
                        isWorking: _isWorking,
                        onIncludeTasksChanged: (value) {
                          if (_isWorking) {
                            return;
                          }
                          setState(() {
                            _includeTasks = value;
                          });
                        },
                        onIncludeSpacesChanged: (value) {
                          if (_isWorking) {
                            return;
                          }
                          setState(() {
                            _includeSpaces = value;
                          });
                        },
                      ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    key: ManageDataSheet.submitButtonKey,
                    onPressed: _isWorking
                        ? null
                        : _mode == _ManageDataMode.importData
                        ? _submitImport
                        : _submitExport,
                    style: taskButtonStyle(
                      context,
                      role: TaskButtonRole.primary,
                      size: TaskButtonSize.large,
                      minimumSize: const Size.fromHeight(54),
                    ),
                    child: _isWorking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primaryButtonText,
                            ),
                          )
                        : Text(
                            _mode == _ManageDataMode.importData
                                ? 'Upload File'
                                : 'Export File',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImportDataPanel extends StatelessWidget {
  const _ImportDataPanel({
    super.key,
    required this.selectedFile,
    required this.isWorking,
    required this.onPickFile,
    required this.onClearFile,
  });

  final PlatformFile? selectedFile;
  final bool isWorking;
  final Future<PlatformFile?> Function() onPickFile;
  final VoidCallback onClearFile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final file = selectedFile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: 'Upload File',
          subtitle: 'Choose a JSON file to import notes, tasks, and spaces.',
        ),
        const SizedBox(height: 18),
        _DashedDropZone(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.five,
              AppSpacing.eight,
              AppSpacing.five,
              AppSpacing.five,
            ),
            child: Column(
              children: [
                const Icon(
                  TablerIcons.upload,
                  size: 42,
                  color: AppColors.blue500,
                ),
                const SizedBox(height: AppSpacing.five),
                Text(
                  'Drop file or browse',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.titleText,
                    fontSize: AppTypography.sizeLg,
                    fontWeight: AppTypography.weightSemibold,
                  ),
                ),
                const SizedBox(height: AppSpacing.two),
                Text(
                  'Format: .JSON & Max file size: 25 MB',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.subHeaderText,
                    fontSize: AppTypography.sizeSm,
                    fontWeight: AppTypography.weightNormal,
                  ),
                ),
                const SizedBox(height: AppSpacing.five),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    key: ManageDataSheet.pickFileButtonKey,
                    onPressed: isWorking
                        ? null
                        : () async {
                            await onPickFile();
                          },
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      side: const BorderSide(color: AppColors.blue500),
                      foregroundColor: AppColors.blue500,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.xl),
                      ),
                      textStyle: theme.textTheme.titleSmall?.copyWith(
                        fontSize: AppTypography.sizeBase,
                        fontWeight: AppTypography.weightMedium,
                      ),
                    ),
                    child: const Text('Import File'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (file != null) ...[
          const SizedBox(height: AppSpacing.five),
          Container(
            key: ManageDataSheet.selectedFileCardKey,
            padding: const EdgeInsets.all(AppSpacing.four),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(AppRadii.twoXl),
              border: Border.all(color: AppColors.neutral200),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.neutral100,
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                  ),
                  child: const Icon(
                    TablerIcons.file,
                    color: AppColors.neutral500,
                  ),
                ),
                const SizedBox(width: AppSpacing.four),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.titleText,
                          fontSize: AppTypography.sizeBase,
                          fontWeight: AppTypography.weightSemibold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatFileSize(file.size),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.subHeaderText,
                          fontSize: AppTypography.sizeSm,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: isWorking ? null : onClearFile,
                  icon: const Icon(TablerIcons.x, color: AppColors.rose500),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ExportDataPanel extends StatelessWidget {
  const _ExportDataPanel({
    super.key,
    required this.includeTasks,
    required this.includeSpaces,
    required this.isWorking,
    required this.onIncludeTasksChanged,
    required this.onIncludeSpacesChanged,
  });

  final bool includeTasks;
  final bool includeSpaces;
  final bool isWorking;
  final ValueChanged<bool> onIncludeTasksChanged;
  final ValueChanged<bool> onIncludeSpacesChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: 'Export Data',
          subtitle: 'Choose which data you want to include in the export.',
        ),
        const SizedBox(height: 18),
        _SelectionCard(
          key: ManageDataSheet.includeTasksKey,
          title: 'Tasks',
          subtitle: 'Export all tasks',
          value: includeTasks,
          onChanged: onIncludeTasksChanged,
          isWorking: isWorking,
        ),
        const SizedBox(height: AppSpacing.four),
        _SelectionCard(
          key: ManageDataSheet.includeSpacesKey,
          title: 'Spaces',
          subtitle: 'Export all spaces',
          value: includeSpaces,
          onChanged: onIncludeSpacesChanged,
          isWorking: isWorking,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskFieldLabel(title),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.subHeaderText,
            fontSize: AppTypography.sizeSm,
            fontWeight: AppTypography.weightNormal,
          ),
        ),
      ],
    );
  }
}

class _ManageDataModeSegmentedControl extends StatelessWidget {
  const _ManageDataModeSegmentedControl({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final _ManageDataMode value;
  final ValueChanged<_ManageDataMode>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.one),
      decoration: BoxDecoration(
        color: AppColors.cardFill,
        borderRadius: BorderRadius.circular(AppRadii.twoXl),
        border: Border.all(color: AppColors.neutral200),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ManageDataModeOption(
              label: 'Import Data',
              selected: value == _ManageDataMode.importData,
              onTap: onChanged == null
                  ? null
                  : () => onChanged!(_ManageDataMode.importData),
            ),
          ),
          Expanded(
            child: _ManageDataModeOption(
              label: 'Export Data',
              selected: value == _ManageDataMode.exportData,
              onTap: onChanged == null
                  ? null
                  : () => onChanged!(_ManageDataMode.exportData),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManageDataModeOption extends StatelessWidget {
  const _ManageDataModeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.two,
            vertical: AppSpacing.three,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColors.blue100 : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: selected ? AppColors.blue500 : AppColors.subHeaderText,
                  fontSize: AppTypography.sizeBase,
                  fontWeight: selected
                      ? AppTypography.weightMedium
                      : AppTypography.weightNormal,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionCard extends StatelessWidget {
  const _SelectionCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.isWorking,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isWorking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isWorking ? null : () => onChanged(!value),
        borderRadius: BorderRadius.circular(AppRadii.twoXl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.four),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadii.twoXl),
            border: Border.all(color: AppColors.neutral200),
          ),
          child: Row(
            children: [
              Checkbox(
                value: value,
                onChanged: isWorking
                    ? null
                    : (next) => onChanged(next ?? false),
                activeColor: AppColors.blue500,
                checkColor: AppColors.blue50,
                side: const BorderSide(color: AppColors.blue200),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
              ),
              const SizedBox(width: AppSpacing.two),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppColors.titleText,
                        fontSize: AppTypography.sizeLg,
                        fontWeight: AppTypography.weightSemibold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.subHeaderText,
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
      ),
    );
  }
}

class _DashedDropZone extends StatelessWidget {
  const _DashedDropZone({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRoundedRectPainter(
        color: AppColors.blue500,
        strokeWidth: 2,
        radius: AppRadii.threeXl,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.blue50.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(AppRadii.threeXl),
        ),
        child: child,
      ),
    );
  }
}

class _DashedRoundedRectPainter extends CustomPainter {
  const _DashedRoundedRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  final Color color;
  final double strokeWidth;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + 8).clamp(0.0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += 14;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius;
  }
}

String _formatFileSize(int sizeBytes) {
  const kilobyte = 1024.0;
  const megabyte = kilobyte * 1024.0;
  if (sizeBytes >= megabyte) {
    return '${(sizeBytes / megabyte).toStringAsFixed(1)} MB';
  }
  if (sizeBytes >= kilobyte) {
    return '${(sizeBytes / kilobyte).toStringAsFixed(1)} KB';
  }
  return '$sizeBytes B';
}
