import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/core/vault/vault_access.dart';
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
}
