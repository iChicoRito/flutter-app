import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../vault/vault_models.dart';

abstract class VaultService {
  Future<bool> isDeviceSecurityAvailable();

  Future<VaultResolution> resolveConfig({
    required String entityKey,
    required VaultDraft draft,
    VaultConfig? existingConfig,
  });

  Future<void> clearVault(VaultConfig? config);

  Future<VaultRecoveryAttempt> unlockWithRecoveryKey({
    required VaultConfig config,
    required String candidate,
    DateTime? now,
  });

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

class VaultResolution {
  const VaultResolution({required this.config, this.recoveryKeys = const []});

  final VaultConfig? config;
  final List<String> recoveryKeys;
}

enum VaultRecoveryAttemptStatus { success, invalid, lockedOut, unavailable }

class VaultRecoveryAttempt {
  const VaultRecoveryAttempt({required this.status, this.remainingLockout});

  final VaultRecoveryAttemptStatus status;
  final Duration? remainingLockout;

  bool get isSuccess => status == VaultRecoveryAttemptStatus.success;
}

abstract class VaultSecureStore {
  Future<String?> read({required String key});

  Future<void> write({required String key, required String value});

  Future<void> delete({required String key});
}

class FlutterVaultSecureStore implements VaultSecureStore {
  const FlutterVaultSecureStore(this._storage);

  final FlutterSecureStorage _storage;

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }
}

class InMemoryVaultSecureStore implements VaultSecureStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

class VaultRecoveryKeyGenerator {
  const VaultRecoveryKeyGenerator({Random? random}) : _random = random;

  static const String characterSet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final Random? _random;

  List<String> generate({int count = 6}) {
    final random = _random ?? Random.secure();
    final keys = <String>{};
    while (keys.length < count) {
      keys.add('${_segment(random)}-${_segment(random)}');
    }
    return keys.toList(growable: false);
  }

  String _segment(Random random) {
    return List.generate(
      4,
      (_) => characterSet[random.nextInt(characterSet.length)],
    ).join();
  }
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
  Future<VaultResolution> resolveConfig({
    required String entityKey,
    required VaultDraft draft,
    VaultConfig? existingConfig,
  }) async {
    if (!draft.isEnabled || draft.method == null) {
      return const VaultResolution(config: null);
    }
    if (draft.method == VaultMethod.deviceSecurity) {
      return const VaultResolution(
        config: VaultConfig(
          isEnabled: true,
          method: VaultMethod.deviceSecurity,
        ),
      );
    }
    return VaultResolution(
      config: VaultConfig(
        isEnabled: true,
        method: draft.method!,
        secretKeyRef: existingConfig?.secretKeyRef ?? entityKey,
        recoveryKeyRef:
            existingConfig?.recoveryKeyRef ?? '${entityKey}_recovery',
      ),
      recoveryKeys: draft.keepExistingSecret
          ? const []
          : const VaultRecoveryKeyGenerator().generate(),
    );
  }

  @override
  Future<VaultRecoveryAttempt> unlockWithRecoveryKey({
    required VaultConfig config,
    required String candidate,
    DateTime? now,
  }) async =>
      const VaultRecoveryAttempt(status: VaultRecoveryAttemptStatus.success);

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
    VaultRecoveryKeyGenerator recoveryKeyGenerator =
        const VaultRecoveryKeyGenerator(),
  }) : _secureStore = FlutterVaultSecureStore(
         secureStorage ?? const FlutterSecureStorage(),
       ),
       _localAuthentication = localAuthentication ?? LocalAuthentication(),
       _recoveryKeyGenerator = recoveryKeyGenerator;

  LocalVaultService.withStore({
    required VaultSecureStore secureStore,
    LocalAuthentication? localAuthentication,
    VaultRecoveryKeyGenerator recoveryKeyGenerator =
        const VaultRecoveryKeyGenerator(),
  }) : _secureStore = secureStore,
       _localAuthentication = localAuthentication ?? LocalAuthentication(),
       _recoveryKeyGenerator = recoveryKeyGenerator;

  static const int _maxRecoveryFailures = 5;
  static const Duration _recoveryLockoutDuration = Duration(minutes: 15);

  final VaultSecureStore _secureStore;
  final LocalAuthentication _localAuthentication;
  final VaultRecoveryKeyGenerator _recoveryKeyGenerator;
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
  Future<VaultResolution> resolveConfig({
    required String entityKey,
    required VaultDraft draft,
    VaultConfig? existingConfig,
  }) async {
    if (!draft.isEnabled || draft.method == null) {
      await clearVault(existingConfig);
      clearUnlocked(entityKey);
      return const VaultResolution(config: null);
    }

    final method = draft.method!;
    if (method == VaultMethod.deviceSecurity) {
      if (!await isDeviceSecurityAvailable()) {
        throw const VaultException('Device security is not available.');
      }
      if (existingConfig?.secretKeyRef case final previousRef?) {
        await _secureStore.delete(key: previousRef);
      }
      if (existingConfig?.recoveryKeyRef case final previousRecoveryRef?) {
        await _secureStore.delete(key: previousRecoveryRef);
      }
      clearUnlocked(entityKey);
      return VaultResolution(
        config: VaultConfig(isEnabled: true, method: method),
      );
    }

    final nextSecret = draft.secret?.trim() ?? '';
    final currentRef = existingConfig?.secretKeyRef;
    final currentRecoveryRef = existingConfig?.recoveryKeyRef;
    if (draft.keepExistingSecret &&
        currentRef != null &&
        existingConfig?.method == method) {
      clearUnlocked(entityKey);
      return VaultResolution(
        config: VaultConfig(
          isEnabled: true,
          method: method,
          secretKeyRef: currentRef,
          recoveryKeyRef: currentRecoveryRef,
        ),
      );
    }

    if (nextSecret.isEmpty) {
      throw const VaultException('A secret is required for this vault method.');
    }

    final secretKeyRef =
        currentRef ??
        'vault_${entityKey}_${DateTime.now().microsecondsSinceEpoch}';
    final recoveryKeyRef =
        currentRecoveryRef ??
        'vault_recovery_${entityKey}_${DateTime.now().microsecondsSinceEpoch}';
    final recoveryKeys = _recoveryKeyGenerator.generate();
    await _secureStore.write(key: secretKeyRef, value: _hashSecret(nextSecret));
    await _writeRecoveryMetadata(recoveryKeyRef, recoveryKeys);
    clearUnlocked(entityKey);
    return VaultResolution(
      config: VaultConfig(
        isEnabled: true,
        method: method,
        secretKeyRef: secretKeyRef,
        recoveryKeyRef: recoveryKeyRef,
      ),
      recoveryKeys: recoveryKeys,
    );
  }

  @override
  Future<void> clearVault(VaultConfig? config) async {
    if (config?.secretKeyRef case final secretKeyRef?) {
      await _secureStore.delete(key: secretKeyRef);
    }
    if (config?.recoveryKeyRef case final recoveryKeyRef?) {
      await _secureStore.delete(key: recoveryKeyRef);
    }
  }

  @override
  Future<VaultRecoveryAttempt> unlockWithRecoveryKey({
    required VaultConfig config,
    required String candidate,
    DateTime? now,
  }) async {
    final recoveryKeyRef = config.recoveryKeyRef;
    if (!config.usesSecret || recoveryKeyRef == null) {
      return const VaultRecoveryAttempt(
        status: VaultRecoveryAttemptStatus.unavailable,
      );
    }

    final metadata = await _readRecoveryMetadata(recoveryKeyRef);
    if (metadata == null) {
      return const VaultRecoveryAttempt(
        status: VaultRecoveryAttemptStatus.unavailable,
      );
    }

    final currentTime = now ?? DateTime.now();
    final lockedUntil = metadata.lockedUntil;
    if (lockedUntil != null && lockedUntil.isAfter(currentTime)) {
      return VaultRecoveryAttempt(
        status: VaultRecoveryAttemptStatus.lockedOut,
        remainingLockout: lockedUntil.difference(currentTime),
      );
    }

    final candidateHash = _hashRecoveryKey(candidate);
    final isValid =
        metadata.keyHashes.contains(candidateHash) &&
        !metadata.usedKeyHashes.contains(candidateHash);
    if (isValid) {
      final next = metadata.copyWith(
        usedKeyHashes: {...metadata.usedKeyHashes, candidateHash},
        failedAttempts: 0,
        clearLockedUntil: true,
      );
      await _writeRecoveryMetadataValue(recoveryKeyRef, next);
      return const VaultRecoveryAttempt(
        status: VaultRecoveryAttemptStatus.success,
      );
    }

    final failedAttempts = metadata.failedAttempts + 1;
    if (failedAttempts >= _maxRecoveryFailures) {
      final lockedUntil = currentTime.add(_recoveryLockoutDuration);
      await _writeRecoveryMetadataValue(
        recoveryKeyRef,
        metadata.copyWith(
          failedAttempts: failedAttempts,
          lockedUntil: lockedUntil,
        ),
      );
      return VaultRecoveryAttempt(
        status: VaultRecoveryAttemptStatus.lockedOut,
        remainingLockout: _recoveryLockoutDuration,
      );
    }

    await _writeRecoveryMetadataValue(
      recoveryKeyRef,
      metadata.copyWith(failedAttempts: failedAttempts, clearLockedUntil: true),
    );
    return const VaultRecoveryAttempt(
      status: VaultRecoveryAttemptStatus.invalid,
    );
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
    final savedHash = await _secureStore.read(key: secretKeyRef);
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

  String _hashRecoveryKey(String key) {
    final normalized = key.trim().toUpperCase();
    return _hashSecret(normalized);
  }

  Future<void> _writeRecoveryMetadata(
    String recoveryKeyRef,
    List<String> recoveryKeys,
  ) {
    return _writeRecoveryMetadataValue(
      recoveryKeyRef,
      _VaultRecoveryMetadata(
        keyHashes: recoveryKeys.map(_hashRecoveryKey).toSet(),
        usedKeyHashes: const <String>{},
      ),
    );
  }

  Future<_VaultRecoveryMetadata?> _readRecoveryMetadata(String key) async {
    final raw = await _secureStore.read(key: key);
    if (raw == null) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) {
      return null;
    }
    return _VaultRecoveryMetadata.fromJson(decoded);
  }

  Future<void> _writeRecoveryMetadataValue(
    String key,
    _VaultRecoveryMetadata metadata,
  ) {
    return _secureStore.write(key: key, value: jsonEncode(metadata.toJson()));
  }
}

class _VaultRecoveryMetadata {
  const _VaultRecoveryMetadata({
    required this.keyHashes,
    required this.usedKeyHashes,
    this.failedAttempts = 0,
    this.lockedUntil,
  });

  final Set<String> keyHashes;
  final Set<String> usedKeyHashes;
  final int failedAttempts;
  final DateTime? lockedUntil;

  factory _VaultRecoveryMetadata.fromJson(Map<String, Object?> json) {
    return _VaultRecoveryMetadata(
      keyHashes: ((json['keyHashes'] as List?) ?? const [])
          .whereType<String>()
          .toSet(),
      usedKeyHashes: ((json['usedKeyHashes'] as List?) ?? const [])
          .whereType<String>()
          .toSet(),
      failedAttempts: json['failedAttempts'] is int
          ? json['failedAttempts']! as int
          : 0,
      lockedUntil: json['lockedUntil'] is int
          ? DateTime.fromMillisecondsSinceEpoch(json['lockedUntil']! as int)
          : null,
    );
  }

  _VaultRecoveryMetadata copyWith({
    Set<String>? keyHashes,
    Set<String>? usedKeyHashes,
    int? failedAttempts,
    DateTime? lockedUntil,
    bool clearLockedUntil = false,
  }) {
    return _VaultRecoveryMetadata(
      keyHashes: keyHashes ?? this.keyHashes,
      usedKeyHashes: usedKeyHashes ?? this.usedKeyHashes,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockedUntil: clearLockedUntil ? null : lockedUntil ?? this.lockedUntil,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'keyHashes': keyHashes.toList(growable: false),
      'usedKeyHashes': usedKeyHashes.toList(growable: false),
      'failedAttempts': failedAttempts,
      'lockedUntil': lockedUntil?.millisecondsSinceEpoch,
    };
  }
}

class VaultException implements Exception {
  const VaultException(this.message);

  final String message;

  @override
  String toString() => message;
}
