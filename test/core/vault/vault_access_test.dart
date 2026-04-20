import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/core/services/vault_service.dart';
import 'package:flutter_app/core/vault/vault_access.dart';
import 'package:flutter_app/core/vault/vault_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('recovery keys dialog copies keys and closes after countdown', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          final arguments = call.arguments as Map<Object?, Object?>;
          clipboardText = arguments['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    const keys = [
      'ABCD-2345',
      'EFGH-6789',
      'JKLM-2345',
      'NPQR-6789',
      'STUV-2345',
      'WXYZ-6789',
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => showVaultRecoveryKeysDialog(
                  context: context,
                  recoveryKeys: keys,
                ),
                child: const Text('Show keys'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show keys'));
    await tester.pumpAndSettle();

    expect(find.text('Your Vault Recovery Keys'), findsOneWidget);
    for (final key in keys) {
      expect(find.text(key), findsOneWidget);
    }

    expect(find.byType(CheckboxListTile), findsNothing);
    expect(find.text('Done'), findsNothing);

    await tester.tap(find.text('Copy Recovery Keys'));
    await tester.pump();
    expect(clipboardText, keys.join('\n'));
    expect(find.text('Copied, closing in (5s)'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Copied, closing in (4s)'), findsOneWidget);
    expect(find.text('Your Vault Recovery Keys'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.text('Your Vault Recovery Keys'), findsNothing);
  });

  group('vault recovery reset flow', () {
    testWidgets(
      'pin recovery reset uses one compact PIN field, validates, opens keyboard, and submits',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 740));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final service = _FakeVaultService();
        var textInputShowCount = 0;

        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.textInput,
          (call) async {
            if (call.method == 'TextInput.show') {
              textInputShowCount++;
            }
            return null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.textInput,
            null,
          );
        });

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: _EnsureUnlockedHarness(
                service: service,
                config: const VaultConfig(
                  isEnabled: true,
                  method: VaultMethod.pin,
                  secretKeyRef: 'secret-ref',
                  recoveryKeyRef: 'recovery-ref',
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open vault'));
        await tester.pumpAndSettle();

        expect(find.text('Forgot Vault PIN?'), findsOneWidget);
        await tester.tap(find.text('Forgot Vault PIN?'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextFormField).first, 'A7F2-K9L3');
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Create New Vault PIN'), findsOneWidget);
        expect(find.text('Reset Vault PIN'), findsOneWidget);
        expect(find.text('Confirm PIN'), findsNothing);
        expect(find.text('Cancel'), findsOneWidget);

        final showCountBeforeTap = textInputShowCount;
        await tester.tap(find.text('-').first);
        await tester.pump();
        expect(textInputShowCount, greaterThan(showCountBeforeTap));

        await tester.enterText(find.byType(TextFormField).first, '12');
        await tester.tap(find.text('Reset Vault'));
        await tester.pumpAndSettle();

        expect(find.text('PIN must be exactly 4 digits.'), findsOneWidget);

        await tester.enterText(find.byType(TextFormField).first, '1234');
        await tester.tap(find.text('Reset Vault'));
        await tester.pumpAndSettle();

        expect(find.text('result: VaultUnlockResult.unlocked'), findsOneWidget);
        expect(service.resolvedSecret, '1234');
        expect(service.recoveryResetApplied, isTrue);
      },
    );

    testWidgets('password recovery reset still shows confirm password', (
      tester,
    ) async {
      final service = _FakeVaultService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _EnsureUnlockedHarness(
              service: service,
              config: const VaultConfig(
                isEnabled: true,
                method: VaultMethod.password,
                secretKeyRef: 'secret-ref',
                recoveryKeyRef: 'recovery-ref',
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open vault'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forgot Vault Password?'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'A7F2-K9L3');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Create New Vault password'), findsOneWidget);
      expect(find.text('Confirm new password'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('reset dialog cancel closes flow without unlocking', (
      tester,
    ) async {
      final service = _FakeVaultService();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: _EnsureUnlockedHarness(
              service: service,
              config: const VaultConfig(
                isEnabled: true,
                method: VaultMethod.pin,
                secretKeyRef: 'secret-ref',
                recoveryKeyRef: 'recovery-ref',
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open vault'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Forgot Vault PIN?'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'A7F2-K9L3');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Create New Vault PIN'), findsNothing);
      expect(find.text('result: VaultUnlockResult.cancelled'), findsOneWidget);
      expect(service.resolvedSecret, isNull);
      expect(service.recoveryResetApplied, isFalse);
    });
  });
}

class _EnsureUnlockedHarness extends StatefulWidget {
  const _EnsureUnlockedHarness({required this.service, required this.config});

  final VaultService service;
  final VaultConfig config;

  @override
  State<_EnsureUnlockedHarness> createState() => _EnsureUnlockedHarnessState();
}

class _EnsureUnlockedHarnessState extends State<_EnsureUnlockedHarness> {
  String _result = 'pending';

  Future<void> _openVault() async {
    final result = await ensureUnlocked(
      context: context,
      vaultService: widget.service,
      entityKey: 'task:test',
      title: 'ss',
      entityKind: VaultEntityKind.task,
      config: widget.config,
      onRecoveryReset: (_) async {
        if (widget.service is _FakeVaultService) {
          (widget.service as _FakeVaultService).recoveryResetApplied = true;
        }
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _result = result.toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextButton(onPressed: _openVault, child: const Text('Open vault')),
        Text('result: $_result'),
      ],
    );
  }
}

class _FakeVaultService extends NoopVaultService {
  String? resolvedSecret;
  bool recoveryResetApplied = false;

  @override
  Future<VaultRecoveryAttempt> unlockWithRecoveryKey({
    required VaultConfig config,
    required String candidate,
    DateTime? now,
  }) async {
    return const VaultRecoveryAttempt(status: VaultRecoveryAttemptStatus.success);
  }

  @override
  Future<VaultResolution> resolveConfig({
    required String entityKey,
    required VaultDraft draft,
    VaultConfig? existingConfig,
  }) async {
    resolvedSecret = draft.secret;
    return VaultResolution(
      config: VaultConfig(
        isEnabled: true,
        method: draft.method!,
        secretKeyRef: 'updated-secret-ref',
        recoveryKeyRef: 'updated-recovery-ref',
      ),
    );
  }
}
