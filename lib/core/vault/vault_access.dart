import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_design_tokens.dart';
import '../services/vault_service.dart';
import 'vault_models.dart';

String taskVaultEntityKey(String taskId) => 'task:$taskId';

String spaceVaultEntityKey(String spaceId) => 'space:$spaceId';

bool hasEnabledVault(VaultConfig? config) => config?.isEnabled == true;

bool isEntityUnlocked(VaultService vaultService, String entityKey) {
  return vaultService.isUnlocked(entityKey);
}

bool isPreviewProtected({
  required VaultService vaultService,
  required VaultConfig? ownVault,
  String? ownEntityKey,
  required VaultConfig? inheritedVault,
  String? inheritedEntityKey,
}) {
  if (hasEnabledVault(ownVault) &&
      ownEntityKey != null &&
      !vaultService.isUnlocked(ownEntityKey)) {
    return true;
  }
  if (hasEnabledVault(inheritedVault) &&
      inheritedEntityKey != null &&
      !vaultService.isUnlocked(inheritedEntityKey)) {
    return true;
  }
  return false;
}

enum VaultUnlockResult { notRequired, unlocked, failed, lockedOut, cancelled }

enum VaultEntityKind { task, space }

typedef VaultRecoveryResetHandler =
    Future<void> Function(VaultResolution resolution);

Future<void> showVaultRecoveryKeysDialog({
  required BuildContext context,
  required List<String> recoveryKeys,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _VaultRecoveryKeysDialog(recoveryKeys: recoveryKeys),
  );
}

Future<VaultUnlockResult> ensureUnlocked({
  required BuildContext context,
  required VaultService vaultService,
  required String entityKey,
  required String title,
  required VaultEntityKind entityKind,
  required VaultConfig? config,
  bool forcePrompt = false,
  VaultRecoveryResetHandler? onRecoveryReset,
}) async {
  if (!hasEnabledVault(config)) {
    return VaultUnlockResult.notRequired;
  }
  if (!forcePrompt && vaultService.isUnlocked(entityKey)) {
    return VaultUnlockResult.notRequired;
  }

  switch (config!.method) {
    case VaultMethod.deviceSecurity:
      final unlocked = await vaultService.unlockWithDeviceSecurity(
        entityKey: entityKey,
        prompt: 'Authenticate to open $title.',
      );
      return unlocked ? VaultUnlockResult.unlocked : VaultUnlockResult.failed;
    case VaultMethod.password:
    case VaultMethod.pin:
      final value = await showDialog<_VaultSecretDialogResult>(
        context: context,
        builder: (context) => _VaultSecretDialog(
          title: title,
          entityKind: entityKind,
          config: config,
        ),
      );
      if (value == null) {
        return VaultUnlockResult.cancelled;
      }
      if (!context.mounted) {
        return VaultUnlockResult.cancelled;
      }
      if (value.recoveryRequested) {
        return _recoverVaultAccess(
          context: context,
          vaultService: vaultService,
          entityKey: entityKey,
          title: title,
          entityKind: entityKind,
          config: config,
          onRecoveryReset: onRecoveryReset,
        );
      }
      final secret = value.secret?.trim() ?? '';
      if (secret.isEmpty) {
        return VaultUnlockResult.cancelled;
      }
      final attempt = await vaultService.unlockWithSecret(
        entityKey: entityKey,
        config: config,
        candidate: secret,
      );
      switch (attempt.status) {
        case VaultSecretAttemptStatus.success:
          return VaultUnlockResult.unlocked;
        case VaultSecretAttemptStatus.invalid:
          return VaultUnlockResult.failed;
        case VaultSecretAttemptStatus.lockedOut:
          final remainingSeconds =
              attempt.remainingLockout?.inSeconds ?? 5 * 60;
          final minutes = ((remainingSeconds + 59) ~/ 60).clamp(1, 5);
          if (!context.mounted) {
            return VaultUnlockResult.lockedOut;
          }
          await _showVaultDangerDialog(
            context: context,
            title: 'Vault Locked',
            message:
                'Too many invalid attempts. Try again in about $minutes minutes.',
          );
          return VaultUnlockResult.lockedOut;
      }
  }
}

Future<VaultUnlockResult> _recoverVaultAccess({
  required BuildContext context,
  required VaultService vaultService,
  required String entityKey,
  required String title,
  required VaultEntityKind entityKind,
  required VaultConfig config,
  required VaultRecoveryResetHandler? onRecoveryReset,
}) async {
  if (onRecoveryReset == null || config.recoveryKeyRef == null) {
    await _showVaultMessageDialog(
      context: context,
      title: 'Recovery Unavailable',
      message:
          'Recovery keys are not available for this vault. Unlock with the current password or PIN.',
    );
    return VaultUnlockResult.cancelled;
  }

  final recoveryAttempt = await showDialog<_VaultRecoveryKeyDialogResult>(
    context: context,
    builder: (context) => _VaultRecoveryKeyDialog(
      entityKind: entityKind,
      config: config,
      vaultService: vaultService,
    ),
  );
  if (recoveryAttempt == null) {
    return VaultUnlockResult.cancelled;
  }

  if (!context.mounted) {
    return VaultUnlockResult.cancelled;
  }
  switch (recoveryAttempt.status) {
    case VaultRecoveryAttemptStatus.unavailable:
      await _showVaultMessageDialog(
        context: context,
        title: 'Recovery Unavailable',
        message:
            'Recovery keys are not available for this vault. Unlock with the current password or PIN.',
      );
      return VaultUnlockResult.cancelled;
    case VaultRecoveryAttemptStatus.lockedOut:
      final minutes = (recoveryAttempt.remainingLockout?.inMinutes ?? 15).clamp(
        1,
        15,
      );
      await _showVaultDangerDialog(
        context: context,
        title: 'Recovery Locked',
        message:
            'Too many invalid recovery attempts. Try again in about $minutes minutes.',
      );
      return VaultUnlockResult.failed;
    case VaultRecoveryAttemptStatus.invalid:
      return VaultUnlockResult.failed;
    case VaultRecoveryAttemptStatus.success:
      break;
  }

  if (!context.mounted) {
    return VaultUnlockResult.cancelled;
  }
  final newSecret = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _VaultResetSecretDialog(
      title: title,
      entityKind: entityKind,
      method: config.method,
    ),
  );
  if (newSecret == null || newSecret.trim().isEmpty) {
    return VaultUnlockResult.cancelled;
  }

  final resolution = await vaultService.resolveConfig(
    entityKey: entityKey,
    draft: VaultDraft(
      isEnabled: true,
      method: config.method,
      secret: newSecret,
    ),
    existingConfig: config,
  );
  await onRecoveryReset(resolution);
  vaultService.markUnlocked(entityKey);
  if (context.mounted && resolution.recoveryKeys.isNotEmpty) {
    await showVaultRecoveryKeysDialog(
      context: context,
      recoveryKeys: resolution.recoveryKeys,
    );
  }
  return VaultUnlockResult.unlocked;
}

Future<void> _showVaultMessageDialog({
  required BuildContext context,
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _vaultDialogCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(child: _VaultHeroIcon(icon: Icons.info_rounded)),
          const SizedBox(height: AppSpacing.five),
          Text(
            title,
            textAlign: TextAlign.center,
            style: _vaultTitleStyle(context),
          ),
          const SizedBox(height: AppSpacing.three),
          Text(
            message,
            textAlign: TextAlign.center,
            style: _vaultSubtitleStyle(context),
          ),
          const SizedBox(height: AppSpacing.five),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: _vaultPrimaryButtonStyle(),
            child: const Text('I Understand'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showVaultDangerDialog({
  required BuildContext context,
  required String title,
  required String message,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _vaultDialogCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(child: _VaultHeroIcon(icon: Icons.warning_amber_rounded)),
          const SizedBox(height: AppSpacing.five),
          Text(
            title,
            textAlign: TextAlign.center,
            style: _vaultTitleStyle(context).copyWith(color: AppColors.rose500),
          ),
          const SizedBox(height: AppSpacing.three),
          Text(
            message,
            textAlign: TextAlign.center,
            style: _vaultSubtitleStyle(
              context,
            ).copyWith(color: AppColors.neutral500),
          ),
          const SizedBox(height: AppSpacing.five),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            style: _vaultPrimaryButtonStyle(
              backgroundColor: AppColors.rose500,
              foregroundColor: AppColors.white,
            ),
            child: const Text('I Understand'),
          ),
        ],
      ),
    ),
  );
}

const _vaultDialogInset = EdgeInsets.symmetric(
  horizontal: AppSpacing.six,
  vertical: AppSpacing.six,
);

const _vaultDialogPadding = EdgeInsets.fromLTRB(
  AppSpacing.eight,
  AppSpacing.six,
  AppSpacing.eight,
  AppSpacing.six,
);

const _vaultDialogRadius = AppRadii.threeXl;
const _vaultDialogMaxWidth = AppSizes.onboardingMaxWidth;
const _vaultHeroIconSize = AppSpacing.ten + AppSpacing.eight;

TextStyle _vaultTitleStyle(BuildContext context) {
  return Theme.of(context).textTheme.titleLarge?.copyWith(
        fontSize: AppTypography.sizeLg,
        fontWeight: AppTypography.weightSemibold,
        color: AppColors.titleText,
        height: 1.15,
      ) ??
      const TextStyle(
        fontSize: AppTypography.sizeLg,
        fontWeight: AppTypography.weightSemibold,
        color: AppColors.titleText,
        height: 1.15,
      );
}

TextStyle _vaultSubtitleStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodyLarge?.copyWith(
        fontSize: AppTypography.sizeBase,
        fontWeight: AppTypography.weightNormal,
        color: AppColors.subHeaderText,
        height: 1.25,
      ) ??
      const TextStyle(
        fontSize: AppTypography.sizeBase,
        fontWeight: AppTypography.weightNormal,
        color: AppColors.subHeaderText,
        height: 1.25,
      );
}

ButtonStyle _vaultPrimaryButtonStyle({
  Color? backgroundColor,
  Color? foregroundColor,
}) {
  return FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(54),
    backgroundColor: backgroundColor ?? AppColors.primaryButtonFill,
    foregroundColor: foregroundColor ?? AppColors.primaryButtonText,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.twoXl),
    ),
    textStyle: const TextStyle(
      fontSize: AppTypography.sizeBase,
      fontWeight: AppTypography.weightSemibold,
    ),
  );
}

InputDecoration _vaultInputDecoration(
  String hintText, {
  String? labelText,
  String? errorText,
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    hintStyle: const TextStyle(
      fontSize: AppTypography.sizeBase,
      fontWeight: AppTypography.weightNormal,
      color: AppColors.subHeaderText,
    ),
    labelStyle: const TextStyle(
      fontSize: AppTypography.sizeSm,
      fontWeight: AppTypography.weightMedium,
      color: AppColors.titleText,
    ),
    errorText: errorText,
    errorMaxLines: 3,
    filled: true,
    fillColor: AppColors.white,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpacing.five,
      vertical: AppSpacing.four,
    ),
    constraints: const BoxConstraints(minHeight: 54),
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

Widget _vaultDialogCard({
  required Widget child,
  EdgeInsetsGeometry padding = _vaultDialogPadding,
}) {
  return Dialog(
    backgroundColor: AppColors.white,
    surfaceTintColor: AppColors.white,
    insetPadding: _vaultDialogInset,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(_vaultDialogRadius),
      side: const BorderSide(color: AppColors.cardBorder),
    ),
    child: SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _vaultDialogMaxWidth),
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class _VaultHeroIcon extends StatelessWidget {
  const _VaultHeroIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _vaultHeroIconSize,
      height: _vaultHeroIconSize,
      decoration: const BoxDecoration(
        color: AppColors.blue100,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: AppColors.blue500,
        size: AppSpacing.six + AppSpacing.one,
      ),
    );
  }
}

class _VaultSecretDialogResult {
  const _VaultSecretDialogResult.secret(this.secret)
    : recoveryRequested = false;

  const _VaultSecretDialogResult.recovery()
    : secret = null,
      recoveryRequested = true;

  final String? secret;
  final bool recoveryRequested;
}

class _VaultSecretDialog extends StatefulWidget {
  const _VaultSecretDialog({
    required this.title,
    required this.entityKind,
    required this.config,
  });

  final String title;
  final VaultEntityKind entityKind;
  final VaultConfig config;

  @override
  State<_VaultSecretDialog> createState() => _VaultSecretDialogState();
}

class _VaultSecretDialogState extends State<_VaultSecretDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final FocusNode _pinFocusNode = FocusNode();
  String? _pinError;

  bool get _isPin => widget.config.method == VaultMethod.pin;
  bool get _isSpace => widget.entityKind == VaultEntityKind.space;
  String get _entityLabel => _isSpace ? 'Space' : 'Task';
  String get _primaryLabel => 'Unlock $_entityLabel';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handlePinChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handlePinChanged);
    _controller.dispose();
    _pinFocusNode.dispose();
    super.dispose();
  }

  void _submit() {
    if (_isPin) {
      final error = _validatePin(_controller.text);
      if (error != null) {
        setState(() {
          _pinError = error;
        });
        _pinFocusNode.requestFocus();
        return;
      }
    } else if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(
      context,
    ).pop(_VaultSecretDialogResult.secret(_controller.text.trim()));
  }

  void _handlePinChanged() {
    if (_pinError == null) {
      return;
    }
    final error = _validatePin(_controller.text);
    if (error != _pinError) {
      setState(() {
        _pinError = error;
      });
    }
  }

  String? _validatePin(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'PIN is required.';
    }
    if (!RegExp(r'^\d{4}$').hasMatch(trimmed)) {
      return 'PIN must be exactly 4 digits.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return _vaultDialogCard(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(child: _VaultHeroIcon(icon: Icons.lock_rounded)),
            const SizedBox(height: AppSpacing.six),
            Text(
              'Locked $_entityLabel',
              textAlign: TextAlign.center,
              style: _vaultTitleStyle(context),
            ),
            const SizedBox(height: AppSpacing.two),
            Text(
              _isPin
                  ? 'Enter the 4 - digit PIN to unlock "${widget.title}"'
                  : 'Enter the password to unlock "${widget.title}"',
              textAlign: TextAlign.center,
              style: _vaultSubtitleStyle(context),
            ),
            const SizedBox(height: AppSpacing.six),
            if (_isPin)
              _VaultCompactPinField(
                controller: _controller,
                focusNode: _pinFocusNode,
                errorText: _pinError,
                autofocus: true,
                validator: _validatePin,
                onSubmitted: _submit,
              )
            else
              TextFormField(
                controller: _controller,
                autofocus: true,
                keyboardType: TextInputType.text,
                obscureText: true,
                decoration: _vaultInputDecoration('Enter password'),
                style: const TextStyle(
                  fontSize: AppTypography.sizeBase,
                  color: AppColors.titleText,
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return 'Password is required.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
            const SizedBox(height: AppSpacing.four),
            FilledButton(
              onPressed: _submit,
              style: _vaultPrimaryButtonStyle(),
              child: Text(_primaryLabel),
            ),
            if (widget.config.recoveryKeyRef != null) ...[
              const SizedBox(height: AppSpacing.six),
              TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).pop(const _VaultSecretDialogResult.recovery()),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.titleText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.twoXl),
                  ),
                  textStyle: const TextStyle(
                    fontSize: AppTypography.sizeBase,
                    fontWeight: AppTypography.weightMedium,
                  ),
                ),
                child: Text(
                  _isPin ? 'Forgot Vault PIN?' : 'Forgot Vault Password?',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VaultRecoveryKeyDialogResult {
  const _VaultRecoveryKeyDialogResult({
    required this.status,
    this.remainingLockout,
  });

  final VaultRecoveryAttemptStatus status;
  final Duration? remainingLockout;
}

class _VaultRecoveryKeyDialog extends StatefulWidget {
  const _VaultRecoveryKeyDialog({
    required this.entityKind,
    required this.config,
    required this.vaultService,
  });

  final VaultEntityKind entityKind;
  final VaultConfig config;
  final VaultService vaultService;

  @override
  State<_VaultRecoveryKeyDialog> createState() =>
      _VaultRecoveryKeyDialogState();
}

class _VaultRecoveryKeyDialogState extends State<_VaultRecoveryKeyDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;
  String? _inlineError;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _isSubmitting = true;
      _inlineError = null;
    });
    final attempt = await widget.vaultService.unlockWithRecoveryKey(
      config: widget.config,
      candidate: _controller.text.trim(),
    );
    if (!mounted) {
      return;
    }
    if (attempt.status == VaultRecoveryAttemptStatus.invalid) {
      setState(() {
        _isSubmitting = false;
        _inlineError =
            'You entered old recovery keys, please use the latest recovery keys.';
      });
      return;
    }
    Navigator.of(context).pop(
      _VaultRecoveryKeyDialogResult(
        status: attempt.status,
        remainingLockout: attempt.remainingLockout,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entityLabel = widget.entityKind == VaultEntityKind.space
        ? 'space'
        : 'task';
    return _vaultDialogCard(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(child: _VaultHeroIcon(icon: Icons.lock_open_rounded)),
            const SizedBox(height: AppSpacing.six),
            Text(
              'Recover Vault',
              textAlign: TextAlign.center,
              style: _vaultTitleStyle(context),
            ),
            const SizedBox(height: AppSpacing.two),
            Text(
              'Enter any one of your saved recovery keys to reset this $entityLabel vault.',
              textAlign: TextAlign.center,
              style: _vaultSubtitleStyle(context),
            ),
            const SizedBox(height: AppSpacing.six),
            TextFormField(
              controller: _controller,
              autofocus: true,
              enabled: !_isSubmitting,
              textCapitalization: TextCapitalization.characters,
              decoration: _vaultInputDecoration(
                'XXXX-XXXX',
                errorText: _inlineError,
              ),
              style: const TextStyle(
                fontSize: AppTypography.sizeBase,
                color: AppColors.titleText,
              ),
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) {
                  return 'Recovery key is required.';
                }
                if (!RegExp(
                  r'^[A-Za-z0-9]{4}-[A-Za-z0-9]{4}$',
                ).hasMatch(trimmed)) {
                  return 'Use the XXXX-XXXX recovery key format.';
                }
                return null;
              },
              onChanged: (_) {
                if (_inlineError == null) {
                  return;
                }
                setState(() {
                  _inlineError = null;
                });
              },
              onFieldSubmitted: (_) {
                if (!_isSubmitting) {
                  _submit();
                }
              },
            ),
            const SizedBox(height: AppSpacing.four),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              style: _vaultPrimaryButtonStyle(),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }
}

class _VaultResetSecretDialog extends StatefulWidget {
  const _VaultResetSecretDialog({
    required this.title,
    required this.entityKind,
    required this.method,
  });

  final String title;
  final VaultEntityKind entityKind;
  final VaultMethod method;

  @override
  State<_VaultResetSecretDialog> createState() =>
      _VaultResetSecretDialogState();
}

class _VaultResetSecretDialogState extends State<_VaultResetSecretDialog> {
  final _controller = TextEditingController();
  final _confirmController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late final FocusNode _primaryFocusNode;
  late final FocusNode _confirmFocusNode;

  bool get _isPin => widget.method == VaultMethod.pin;

  @override
  void initState() {
    super.initState();
    _primaryFocusNode = FocusNode();
    _confirmFocusNode = FocusNode();
    if (_isPin) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) {
          return;
        }
        _primaryFocusNode.requestFocus();
        await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      });
    }
  }

  @override
  void dispose() {
    _primaryFocusNode.dispose();
    _confirmFocusNode.dispose();
    _controller.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final methodLabel = _isPin ? 'PIN' : 'password';
    final actionLabel = _isPin ? 'Reset Vault PIN' : 'Reset Vault Password';
    return PopScope(
      canPop: false,
      child: _vaultDialogCard(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                child: _VaultHeroIcon(icon: Icons.lock_reset_rounded),
              ),
              const SizedBox(height: AppSpacing.six),
              Text(
                'Create New Vault $methodLabel',
                textAlign: TextAlign.center,
                style: _vaultTitleStyle(context),
              ),
              const SizedBox(height: AppSpacing.two),
              Text(
                actionLabel,
                textAlign: TextAlign.center,
                style: _vaultSubtitleStyle(context).copyWith(
                  color: AppColors.titleText,
                  fontWeight: AppTypography.weightMedium,
                ),
              ),
              const SizedBox(height: AppSpacing.oneAndHalf),
              Text(
                'Recovery succeeded. Set a new $methodLabel before opening "${widget.title}".',
                textAlign: TextAlign.center,
                style: _vaultSubtitleStyle(context),
              ),
              const SizedBox(height: AppSpacing.six),
              if (_isPin)
                _VaultCompactPinField(
                  controller: _controller,
                  focusNode: _primaryFocusNode,
                  autofocus: true,
                  errorText: null,
                  validator: _validateSecret,
                  onSubmitted: _submit,
                )
              else
                TextFormField(
                  controller: _controller,
                  autofocus: true,
                  keyboardType: TextInputType.text,
                  obscureText: true,
                  decoration: _vaultInputDecoration('Enter new password'),
                  style: const TextStyle(
                    fontSize: AppTypography.sizeBase,
                    color: AppColors.titleText,
                  ),
                  validator: _validateSecret,
                ),
              if (!_isPin) ...[
                const SizedBox(height: AppSpacing.three),
                TextFormField(
                  controller: _confirmController,
                  keyboardType: TextInputType.text,
                  obscureText: true,
                  decoration: _vaultInputDecoration('Confirm new password'),
                  style: const TextStyle(
                    fontSize: AppTypography.sizeBase,
                    color: AppColors.titleText,
                  ),
                  validator: (value) {
                    final error = _validateSecret(value);
                    if (error != null) {
                      return error;
                    }
                    if (value?.trim() != _controller.text.trim()) {
                      return 'Passwords do not match.';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _submit(),
                ),
              ],
              const SizedBox(height: AppSpacing.four),
              FilledButton(
                onPressed: _submit,
                style: _vaultPrimaryButtonStyle(),
                child: const Text('Reset Vault'),
              ),
              const SizedBox(height: AppSpacing.four),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.titleText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.twoXl),
                  ),
                  textStyle: const TextStyle(
                    fontSize: AppTypography.sizeBase,
                    fontWeight: AppTypography.weightMedium,
                  ),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _validateSecret(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return _isPin ? 'PIN is required.' : 'Password is required.';
    }
    if (_isPin && !RegExp(r'^\d{4}$').hasMatch(trimmed)) {
      return 'PIN must be exactly 4 digits.';
    }
    return null;
  }
}

class _VaultRecoveryKeysDialog extends StatefulWidget {
  const _VaultRecoveryKeysDialog({required this.recoveryKeys});

  final List<String> recoveryKeys;

  @override
  State<_VaultRecoveryKeysDialog> createState() =>
      _VaultRecoveryKeysDialogState();
}

class _VaultRecoveryKeysDialogState extends State<_VaultRecoveryKeysDialog> {
  Timer? _closeTimer;
  int? _secondsUntilClose;

  bool get _isCountingDown => _secondsUntilClose != null;

  @override
  void dispose() {
    _closeTimer?.cancel();
    super.dispose();
  }

  Future<void> _copyKeys() async {
    if (_isCountingDown) {
      return;
    }
    await Clipboard.setData(
      ClipboardData(text: widget.recoveryKeys.join('\n')),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _secondsUntilClose = 5;
    });
    _closeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final nextValue = (_secondsUntilClose ?? 1) - 1;
      if (nextValue <= 0) {
        timer.cancel();
        Navigator.of(context).pop();
        return;
      }
      setState(() {
        _secondsUntilClose = nextValue;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: _vaultDialogCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(child: _VaultHeroIcon(icon: Icons.lock_open_rounded)),
            const SizedBox(height: AppSpacing.six),
            Text(
              'Your Vault Recovery Keys',
              textAlign: TextAlign.center,
              style: _vaultTitleStyle(context),
            ),
            const SizedBox(height: AppSpacing.two),
            Text(
              'If you lose these keys and forget your password, your vault cannot be recovered.',
              textAlign: TextAlign.center,
              style: _vaultSubtitleStyle(context),
            ),
            const SizedBox(height: AppSpacing.six),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.recoveryKeys.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.four,
                mainAxisSpacing: AppSpacing.four,
                childAspectRatio: 2.55,
              ),
              itemBuilder: (context, index) {
                return Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                    border: Border.all(color: AppColors.neutral200),
                  ),
                  child: Text(
                    widget.recoveryKeys[index],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.titleText,
                      fontWeight: AppTypography.weightMedium,
                      fontSize: AppTypography.sizeBase,
                      letterSpacing: 0,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.four),
            FilledButton(
              onPressed: _isCountingDown ? null : _copyKeys,
              style: _vaultPrimaryButtonStyle(
                backgroundColor: _isCountingDown
                    ? AppColors.blue200
                    : AppColors.primaryButtonFill,
                foregroundColor: _isCountingDown
                    ? AppColors.blue500
                    : AppColors.primaryButtonText,
              ),
              child: Text(
                _isCountingDown
                    ? 'Copied, closing in (${_secondsUntilClose}s)'
                    : 'Copy Recovery Keys',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VaultPinField extends StatefulWidget {
  const _VaultPinField({
    required this.controller,
    required this.focusNode,
    required this.title,
    required this.helperText,
    required this.validator,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String title;
  final String helperText;
  final String? Function(String?) validator;
  final VoidCallback onSubmitted;

  @override
  State<_VaultPinField> createState() => _VaultPinFieldState();
}

class _VaultPinFieldState extends State<_VaultPinField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    widget.focusNode.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant _VaultPinField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_refresh);
      widget.focusNode.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    widget.focusNode.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final digits = widget.controller.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => widget.focusNode.requestFocus(),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
            decoration: BoxDecoration(
              color: AppColors.neutral50,
              borderRadius: BorderRadius.circular(AppRadii.threeXl),
              border: Border.all(
                color: widget.focusNode.hasFocus
                    ? AppColors.blue500
                    : AppColors.neutral200,
              ),
            ),
            child: Column(
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.titleText,
                    fontWeight: AppTypography.weightSemibold,
                  ),
                ),
                const SizedBox(height: 14),
                _VaultPinPreview(value: digits),
                const SizedBox(height: 14),
                Text(
                  digits.length == 4 ? '4 digits entered' : widget.helperText,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.neutral500,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        _HiddenVaultPinInput(
          controller: widget.controller,
          focusNode: widget.focusNode,
          validator: widget.validator,
          onSubmitted: widget.onSubmitted,
        ),
      ],
    );
  }
}

class _VaultCompactPinField extends StatefulWidget {
  const _VaultCompactPinField({
    required this.controller,
    required this.focusNode,
    required this.validator,
    required this.onSubmitted,
    this.errorText,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? Function(String?) validator;
  final VoidCallback onSubmitted;
  final String? errorText;
  final bool autofocus;

  @override
  State<_VaultCompactPinField> createState() => _VaultCompactPinFieldState();
}

class _VaultCompactPinFieldState extends State<_VaultCompactPinField> {
  Future<void> _focusAndShowKeyboard() async {
    widget.focusNode.requestFocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    widget.focusNode.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant _VaultCompactPinField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_refresh);
      widget.controller.addListener(_refresh);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_refresh);
      widget.focusNode.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    widget.focusNode.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final digits = widget.controller.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _focusAndShowKeyboard,
          child: _VaultPinPreview(
            value: digits,
            compact: true,
            hasError: widget.errorText != null,
          ),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 8),
          Text(
            widget.errorText!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.rose500,
              height: 1.35,
            ),
          ),
        ],
        _HiddenVaultPinInput(
          controller: widget.controller,
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          validator: widget.validator,
          onSubmitted: widget.onSubmitted,
        ),
      ],
    );
  }
}

class _HiddenVaultPinInput extends StatelessWidget {
  const _HiddenVaultPinInput({
    required this.controller,
    required this.focusNode,
    required this.validator,
    required this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? Function(String?) validator;
  final VoidCallback onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 1,
      height: 1,
      child: Transform.translate(
        offset: const Offset(-1000, 0),
        child: TextFormField(
          controller: controller,
          focusNode: focusNode,
          autofocus: autofocus,
          keyboardType: TextInputType.number,
          obscureText: true,
          obscuringCharacter: '*',
          maxLength: 4,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(4),
          ],
          enableInteractiveSelection: false,
          showCursor: false,
          style: const TextStyle(
            color: Colors.transparent,
            fontSize: 1,
            height: 1,
          ),
          cursorColor: Colors.transparent,
          decoration: const InputDecoration(
            isDense: true,
            isCollapsed: true,
            counterText: '',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorBorder: InputBorder.none,
            focusedErrorBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          validator: validator,
          onFieldSubmitted: (_) => onSubmitted(),
        ),
      ),
    );
  }
}

class _VaultPinPreview extends StatelessWidget {
  const _VaultPinPreview({
    required this.value,
    this.compact = false,
    this.hasError = false,
  });

  final String value;
  final bool compact;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = AppSpacing.three;
        final rawSize = (constraints.maxWidth - (spacing * 3)) / 4;
        final itemSize = rawSize.clamp(48.0, 72.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            final isFilled = index < value.length;
            return Padding(
              padding: EdgeInsets.only(right: index == 3 ? 0 : spacing),
              child: SizedBox.square(
                dimension: itemSize,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadii.xl),
                    border: Border.all(
                      color: hasError
                          ? AppColors.rose500
                          : isFilled
                          ? AppColors.blue500
                          : AppColors.neutral200,
                    ),
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: isFilled
                          ? Text(
                              '\u2022',
                              key: ValueKey('filled-$index'),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: AppColors.neutral500,
                                    fontWeight: AppTypography.weightSemibold,
                                    height: 1,
                                  ),
                            )
                          : Text(
                              '-',
                              key: ValueKey('empty-$index'),
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: AppColors.neutral400,
                                    fontWeight: AppTypography.weightNormal,
                                    height: 1,
                                  ),
                            ),
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
