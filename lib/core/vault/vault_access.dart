import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

enum VaultUnlockResult { notRequired, unlocked, failed, cancelled }

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
      final unlocked = await vaultService.unlockWithSecret(
        entityKey: entityKey,
        config: config,
        candidate: secret,
      );
      return unlocked ? VaultUnlockResult.unlocked : VaultUnlockResult.failed;
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
    builder: (context) => AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('I Understand'),
        ),
      ],
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
    builder: (context) => Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              child: Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFECEC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFD63939),
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFFD63939),
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF6B7280),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: const Color(0xFFD63939),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('I Understand'),
            ),
          ],
        ),
      ),
    ),
  );
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

  bool get _isPin => widget.config.method == VaultMethod.pin;
  bool get _isSpace => widget.entityKind == VaultEntityKind.space;
  String get _entityLabel => _isSpace ? 'Space' : 'Task';
  String get _primaryLabel => 'Unlock $_entityLabel';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    Navigator.of(
      context,
    ).pop(_VaultSecretDialogResult.secret(_controller.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3FE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Color(0xFF066FD1),
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Locked $_entityLabel',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF066FD1),
                  height: 1,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Unlock the "${widget.title}"',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF333333),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isPin
                    ? 'Enter the 4-digit PIN to unlock $_entityLabel.'
                    : 'Enter the password to unlock $_entityLabel.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF8A94A6),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _controller,
                autofocus: true,
                keyboardType: _isPin
                    ? TextInputType.number
                    : TextInputType.text,
                obscureText: true,
                maxLength: _isPin ? 4 : null,
                decoration: InputDecoration(
                  hintText: _isPin ? 'Enter PIN' : 'Enter password',
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E8EC)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF066FD1)),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD63939)),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFD63939)),
                  ),
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) {
                    return _isPin
                        ? 'PIN is required.'
                        : 'Password is required.';
                  }
                  if (_isPin && !RegExp(r'^\d{4}$').hasMatch(trimmed)) {
                    return 'PIN must be exactly 4 digits.';
                  }
                  return null;
                },
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: const Color(0xFF2F8AE5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                child: Text(_primaryLabel),
              ),
              if (widget.config.recoveryKeyRef != null) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(const _VaultSecretDialogResult.recovery()),
                  child: Text(
                    _isPin ? 'Forgot Vault PIN?' : 'Forgot Vault Password?',
                  ),
                ),
              ],
            ],
          ),
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
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _VaultDialogIcon(icon: Icons.key_rounded),
              const SizedBox(height: 14),
              Text(
                'Recover Vault',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF066FD1),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter any one of your saved recovery keys to reset this $entityLabel vault.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF6B7280),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _controller,
                autofocus: true,
                enabled: !_isSubmitting,
                textCapitalization: TextCapitalization.characters,
                decoration: _vaultInputDecoration(
                  'A7F2-K9L3',
                ).copyWith(errorText: _inlineError, errorMaxLines: 3),
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
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: _primaryButtonStyle(context),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Continue'),
              ),
            ],
          ),
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
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _VaultDialogIcon(icon: Icons.lock_reset_rounded),
                const SizedBox(height: 14),
                Text(
                  'Create New Vault $methodLabel',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF066FD1),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Recovery succeeded. Set a new $methodLabel before opening "${widget.title}".',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF6B7280),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                if (_isPin)
                  _VaultPinField(
                    controller: _controller,
                    focusNode: _primaryFocusNode,
                    title: 'New PIN',
                    helperText: 'Create a new 4-digit PIN for this vault.',
                    autofocus: true,
                    validator: _validateSecret,
                    onSubmitted: () => _confirmFocusNode.requestFocus(),
                  )
                else
                  TextFormField(
                    controller: _controller,
                    autofocus: true,
                    keyboardType: TextInputType.text,
                    obscureText: true,
                    decoration: _vaultInputDecoration('Enter new password'),
                    validator: _validateSecret,
                  ),
                const SizedBox(height: 12),
                if (_isPin)
                  _VaultPinField(
                    controller: _confirmController,
                    focusNode: _confirmFocusNode,
                    title: 'Confirm PIN',
                    helperText: 'Re-enter the same 4 digits to confirm.',
                    validator: (value) {
                      final error = _validateSecret(value);
                      if (error != null) {
                        return error;
                      }
                      if (value?.trim() != _controller.text.trim()) {
                        return 'PINs do not match.';
                      }
                      return null;
                    },
                    onSubmitted: _submit,
                  )
                else
                  TextFormField(
                    controller: _confirmController,
                    keyboardType: TextInputType.text,
                    obscureText: true,
                    decoration: _vaultInputDecoration('Confirm new password'),
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
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _submit,
                  style: _primaryButtonStyle(context),
                  child: const Text('Reset Vault'),
                ),
              ],
            ),
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
      child: Dialog(
        backgroundColor: const Color(0xFFF9FAFB),
        surfaceTintColor: const Color(0xFFF9FAFB),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(35)),
        child: SingleChildScrollView(
          child: Container(
            width: 341,
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: const Color(0xFFE5E8EC), width: 1.4),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _VaultDialogIcon(icon: Icons.lock_rounded),
                const SizedBox(height: 16),
                Text(
                  'Your Vault Recovery Keys',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: const Color(0xFF066FD1),
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'If you lose these keys and forget your password, your vault cannot be recovered.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF777777),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.recoveryKeys.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 20,
                    childAspectRatio: 2.85,
                  ),
                  itemBuilder: (context, index) {
                    return Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE5E8EC)),
                      ),
                      child: Text(
                        widget.recoveryKeys[index],
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF777777),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _isCountingDown ? null : _copyKeys,
                  style: _primaryButtonStyle(context).copyWith(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.disabled)) {
                        return const Color(0xFFA9CBEF);
                      }
                      return const Color(0xFF066FD1);
                    }),
                    foregroundColor: WidgetStateProperty.all(Colors.white),
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
        ),
      ),
    );
  }
}

class _VaultDialogIcon extends StatelessWidget {
  const _VaultDialogIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Align(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFFE6F0FA),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(icon, color: const Color(0xFF066FD1), size: 30),
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
    this.autofocus = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String title;
  final String helperText;
  final String? Function(String?) validator;
  final VoidCallback onSubmitted;
  final bool autofocus;

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
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: widget.focusNode.hasFocus
                    ? const Color(0xFF066FD1)
                    : const Color(0xFFE5E8EC),
              ),
            ),
            child: Column(
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF333333),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                _VaultPinPreview(value: digits),
                const SizedBox(height: 14),
                Text(
                  digits.length == 4 ? '4 digits entered' : widget.helperText,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 0,
          child: TextFormField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            autofocus: widget.autofocus,
            keyboardType: TextInputType.number,
            obscureText: true,
            obscuringCharacter: '•',
            maxLength: 4,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            enableInteractiveSelection: false,
            style: const TextStyle(
              color: Colors.transparent,
              fontSize: 1,
              height: 0.01,
            ),
            cursorColor: Colors.transparent,
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isCollapsed: true,
            ),
            validator: widget.validator,
            onFieldSubmitted: (_) => widget.onSubmitted(),
          ),
        ),
      ],
    );
  }
}

class _VaultPinPreview extends StatelessWidget {
  const _VaultPinPreview({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isFilled = index < value.length;
        return Container(
          width: 56,
          height: 64,
          margin: EdgeInsets.only(right: index == 3 ? 0 : 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isFilled
                  ? const Color(0xFF066FD1)
                  : const Color(0xFFE5E8EC),
              width: isFilled ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF066FD1,
                ).withValues(alpha: isFilled ? 0.08 : 0),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: isFilled ? 14 : 8,
              height: isFilled ? 14 : 8,
              decoration: BoxDecoration(
                color: isFilled
                    ? const Color(0xFF066FD1)
                    : const Color(0xFFD6EAFB),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}

InputDecoration _vaultInputDecoration(String hintText) {
  return InputDecoration(
    hintText: hintText,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE5E8EC)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF066FD1)),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD63939)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD63939)),
    ),
  );
}

ButtonStyle _primaryButtonStyle(BuildContext context) {
  return FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(48),
    backgroundColor: const Color(0xFF066FD1),
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    textStyle: Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
  );
}
