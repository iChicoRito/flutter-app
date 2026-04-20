import 'dart:convert';

import 'package:flutter_app/core/services/vault_service.dart';
import 'package:flutter_app/core/vault/vault_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VaultRecoveryKeyGenerator', () {
    test('creates six unique non-ambiguous keys in XXXX-XXXX format', () {
      final keys = const VaultRecoveryKeyGenerator().generate();

      expect(keys, hasLength(6));
      expect(keys.toSet(), hasLength(6));
      for (final key in keys) {
        expect(key, matches(RegExp(r'^[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{4}$')));
        expect(key.contains(RegExp(r'[O0I1]')), isFalse);
      }
    });
  });

  group('LocalVaultService recovery keys', () {
    late InMemoryVaultSecureStore store;
    late LocalVaultService service;

    setUp(() {
      store = InMemoryVaultSecureStore();
      service = LocalVaultService.withStore(secureStore: store);
    });

    test('new password vault returns keys and stores only hashes', () async {
      final resolution = await service.resolveConfig(
        entityKey: 'task:alpha',
        draft: const VaultDraft(
          isEnabled: true,
          method: VaultMethod.password,
          secret: 'open sesame',
        ),
      );

      expect(resolution.config?.secretKeyRef, isNotNull);
      expect(resolution.config?.recoveryKeyRef, isNotNull);
      expect(resolution.recoveryKeys, hasLength(6));

      final storedSecret = store.values[resolution.config!.secretKeyRef];
      final storedRecovery = store.values[resolution.config!.recoveryKeyRef];
      expect(storedSecret, isNot('open sesame'));
      for (final key in resolution.recoveryKeys) {
        expect(storedRecovery, isNot(contains(key)));
      }
    });

    test('keeping an existing secret does not generate new keys', () async {
      final first = await service.resolveConfig(
        entityKey: 'task:beta',
        draft: const VaultDraft(
          isEnabled: true,
          method: VaultMethod.pin,
          secret: '1234',
        ),
      );

      final second = await service.resolveConfig(
        entityKey: 'task:beta',
        draft: const VaultDraft(
          isEnabled: true,
          method: VaultMethod.pin,
          keepExistingSecret: true,
        ),
        existingConfig: first.config,
      );

      expect(second.config?.secretKeyRef, first.config?.secretKeyRef);
      expect(second.config?.recoveryKeyRef, first.config?.recoveryKeyRef);
      expect(second.recoveryKeys, isEmpty);
    });

    test('changing a secret invalidates old recovery keys', () async {
      final first = await service.resolveConfig(
        entityKey: 'task:gamma',
        draft: const VaultDraft(
          isEnabled: true,
          method: VaultMethod.password,
          secret: 'old password',
        ),
      );
      final oldKey = first.recoveryKeys.first;

      final second = await service.resolveConfig(
        entityKey: 'task:gamma',
        draft: const VaultDraft(
          isEnabled: true,
          method: VaultMethod.password,
          secret: 'new password',
        ),
        existingConfig: first.config,
      );

      final attempt = await service.unlockWithRecoveryKey(
        config: second.config!,
        candidate: oldKey,
      );

      expect(second.recoveryKeys, isNot(contains(oldKey)));
      expect(attempt.status, VaultRecoveryAttemptStatus.invalid);
    });

    test('valid recovery key succeeds only once', () async {
      final resolution = await service.resolveConfig(
        entityKey: 'task:delta',
        draft: const VaultDraft(
          isEnabled: true,
          method: VaultMethod.password,
          secret: 'vault password',
        ),
      );

      final first = await service.unlockWithRecoveryKey(
        config: resolution.config!,
        candidate: resolution.recoveryKeys.first,
      );
      final second = await service.unlockWithRecoveryKey(
        config: resolution.config!,
        candidate: resolution.recoveryKeys.first,
      );

      expect(first.status, VaultRecoveryAttemptStatus.success);
      expect(second.status, VaultRecoveryAttemptStatus.invalid);
    });

    test('five invalid attempts trigger a fifteen-minute lockout', () async {
      final resolution = await service.resolveConfig(
        entityKey: 'task:epsilon',
        draft: const VaultDraft(
          isEnabled: true,
          method: VaultMethod.password,
          secret: 'vault password',
        ),
      );
      final now = DateTime(2026, 4, 20, 10);

      for (var index = 0; index < 4; index++) {
        final attempt = await service.unlockWithRecoveryKey(
          config: resolution.config!,
          candidate: 'BADK-EYAA',
          now: now,
        );
        expect(attempt.status, VaultRecoveryAttemptStatus.invalid);
      }

      final locked = await service.unlockWithRecoveryKey(
        config: resolution.config!,
        candidate: 'BADK-EYAA',
        now: now,
      );
      final stillLocked = await service.unlockWithRecoveryKey(
        config: resolution.config!,
        candidate: resolution.recoveryKeys.first,
        now: now.add(const Duration(minutes: 1)),
      );

      expect(locked.status, VaultRecoveryAttemptStatus.lockedOut);
      expect(locked.remainingLockout, const Duration(minutes: 15));
      expect(stillLocked.status, VaultRecoveryAttemptStatus.lockedOut);
    });

    test('recovery metadata stores hashes and used key state', () async {
      final resolution = await service.resolveConfig(
        entityKey: 'task:zeta',
        draft: const VaultDraft(
          isEnabled: true,
          method: VaultMethod.password,
          secret: 'vault password',
        ),
      );

      await service.unlockWithRecoveryKey(
        config: resolution.config!,
        candidate: resolution.recoveryKeys.first,
      );

      final rawMetadata = store.values[resolution.config!.recoveryKeyRef]!;
      final metadata = jsonDecode(rawMetadata) as Map<String, Object?>;

      expect(metadata['keyHashes'], isA<List<dynamic>>());
      expect(metadata['usedKeyHashes'], isA<List<dynamic>>());
      expect(metadata['usedKeyHashes'] as List<dynamic>, hasLength(1));
      expect(rawMetadata, isNot(contains(resolution.recoveryKeys.first)));
    });
  });
}
