import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../vault/vault_models.dart';

abstract class VaultService {
  Future<bool> isDeviceSecurityAvailable();

  Future<VaultConfig?> resolveConfig({
    required String entityKey,
    required VaultDraft draft,
    VaultConfig? existingConfig,
  });

  Future<void> clearVault(VaultConfig? config);

  Future<bool> unlockWithSecret({
    required String entityKey,
    required VaultConfig config,
    required String candidate,
  });

  Future<bool> unlockWithDeviceSecurity({
    required String entityKey,
    required String prompt,
  });

  bool isUnlocked(String entityKey);

  void markUnlocked(String entityKey);

  void clearUnlocked(String entityKey);

  void clearAllUnlocked();
}

class NoopVaultService implements VaultService {
  const NoopVaultService();

  @override
  Future<void> clearVault(VaultConfig? config) async {}

  @override
  void clearAllUnlocked() {}

  @override
  void clearUnlocked(String entityKey) {}

  @override
  bool isUnlocked(String entityKey) => false;

  @override
  Future<bool> isDeviceSecurityAvailable() async => false;

  @override
  void markUnlocked(String entityKey) {}

  @override
  Future<VaultConfig?> resolveConfig({
    required String entityKey,
    required VaultDraft draft,
    VaultConfig? existingConfig,
  }) async {
    if (!draft.isEnabled || draft.method == null) {
      return null;
    }
    if (draft.method == VaultMethod.deviceSecurity) {
      return const VaultConfig(
        isEnabled: true,
        method: VaultMethod.deviceSecurity,
      );
    }
    return VaultConfig(
      isEnabled: true,
      method: draft.method!,
      secretKeyRef: existingConfig?.secretKeyRef ?? entityKey,
    );
  }

  @override
  Future<bool> unlockWithDeviceSecurity({
    required String entityKey,
    required String prompt,
  }) async => true;

  @override
  Future<bool> unlockWithSecret({
    required String entityKey,
    required VaultConfig config,
    required String candidate,
  }) async => true;
}

class LocalVaultService implements VaultService {
  LocalVaultService({
    FlutterSecureStorage? secureStorage,
    LocalAuthentication? localAuthentication,
  }) : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
       _localAuthentication = localAuthentication ?? LocalAuthentication();

  final FlutterSecureStorage _secureStorage;
  final LocalAuthentication _localAuthentication;
  final Set<String> _unlockedKeys = <String>{};

  @override
  Future<bool> isDeviceSecurityAvailable() async {
    try {
      final canCheck = await _localAuthentication.canCheckBiometrics;
      final isSupported = await _localAuthentication.isDeviceSupported();
      return canCheck || isSupported;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<VaultConfig?> resolveConfig({
    required String entityKey,
    required VaultDraft draft,
    VaultConfig? existingConfig,
  }) async {
    if (!draft.isEnabled || draft.method == null) {
      await clearVault(existingConfig);
      clearUnlocked(entityKey);
      return null;
    }

    final method = draft.method!;
    if (method == VaultMethod.deviceSecurity) {
      if (!await isDeviceSecurityAvailable()) {
        throw const VaultException('Device security is not available.');
      }
      if (existingConfig?.secretKeyRef case final previousRef?) {
        await _secureStorage.delete(key: previousRef);
      }
      clearUnlocked(entityKey);
      return VaultConfig(isEnabled: true, method: method);
    }

    final nextSecret = draft.secret?.trim() ?? '';
    final currentRef = existingConfig?.secretKeyRef;
    if (draft.keepExistingSecret &&
        currentRef != null &&
        existingConfig?.method == method) {
      clearUnlocked(entityKey);
      return VaultConfig(
        isEnabled: true,
        method: method,
        secretKeyRef: currentRef,
      );
    }

    if (nextSecret.isEmpty) {
      throw const VaultException('A secret is required for this vault method.');
    }

    final secretKeyRef =
        currentRef ?? 'vault_${entityKey}_${DateTime.now().microsecondsSinceEpoch}';
    await _secureStorage.write(key: secretKeyRef, value: _hashSecret(nextSecret));
    clearUnlocked(entityKey);
    return VaultConfig(
      isEnabled: true,
      method: method,
      secretKeyRef: secretKeyRef,
    );
  }

  @override
  Future<void> clearVault(VaultConfig? config) async {
    if (config?.secretKeyRef case final secretKeyRef?) {
      await _secureStorage.delete(key: secretKeyRef);
    }
  }

  @override
  Future<bool> unlockWithSecret({
    required String entityKey,
    required VaultConfig config,
    required String candidate,
  }) async {
    final secretKeyRef = config.secretKeyRef;
    if (secretKeyRef == null) {
      return false;
    }
    final savedHash = await _secureStorage.read(key: secretKeyRef);
    if (savedHash == null) {
      return false;
    }
    final matches = savedHash == _hashSecret(candidate.trim());
    if (matches) {
      markUnlocked(entityKey);
    }
    return matches;
  }

  @override
  Future<bool> unlockWithDeviceSecurity({
    required String entityKey,
    required String prompt,
  }) async {
    try {
      final authenticated = await _localAuthentication.authenticate(
        localizedReason: prompt,
        biometricOnly: false,
      );
      if (authenticated) {
        markUnlocked(entityKey);
      }
      return authenticated;
    } on PlatformException {
      return false;
    }
  }

  @override
  bool isUnlocked(String entityKey) => _unlockedKeys.contains(entityKey);

  @override
  void markUnlocked(String entityKey) {
    _unlockedKeys.add(entityKey);
  }

  @override
  void clearUnlocked(String entityKey) {
    _unlockedKeys.remove(entityKey);
  }

  @override
  void clearAllUnlocked() {
    _unlockedKeys.clear();
  }

  String _hashSecret(String secret) {
    return sha256.convert(utf8.encode(secret)).toString();
  }
}

class VaultException implements Exception {
  const VaultException(this.message);

  final String message;

  @override
  String toString() => message;
}
