import 'package:flutter/material.dart';

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

Future<VaultUnlockResult> ensureUnlocked({
  required BuildContext context,
  required VaultService vaultService,
  required String entityKey,
  required String title,
  required VaultEntityKind entityKind,
  required VaultConfig? config,
  bool forcePrompt = false,
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
      final value = await showDialog<String>(
        context: context,
        builder: (context) => _VaultSecretDialog(
          title: title,
          entityKind: entityKind,
          method: config.method,
        ),
      );
      if (value == null || value.trim().isEmpty) {
        return VaultUnlockResult.cancelled;
      }
      final unlocked = await vaultService.unlockWithSecret(
        entityKey: entityKey,
        config: config,
        candidate: value,
      );
      return unlocked ? VaultUnlockResult.unlocked : VaultUnlockResult.failed;
  }
}

class _VaultSecretDialog extends StatefulWidget {
  const _VaultSecretDialog({
    required this.title,
    required this.entityKind,
    required this.method,
  });

  final String title;
  final VaultEntityKind entityKind;
  final VaultMethod method;

  @override
  State<_VaultSecretDialog> createState() => _VaultSecretDialogState();
}

class _VaultSecretDialogState extends State<_VaultSecretDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool get _isPin => widget.method == VaultMethod.pin;
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
    Navigator.of(context).pop(_controller.text.trim());
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
                keyboardType: _isPin ? TextInputType.number : TextInputType.text,
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
                    return _isPin ? 'PIN is required.' : 'Password is required.';
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
                  textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(_primaryLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
