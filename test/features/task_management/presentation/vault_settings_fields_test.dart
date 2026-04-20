import 'package:flutter/material.dart';
import 'package:flutter_app/core/vault/vault_models.dart';
import 'package:flutter_app/features/task_management/presentation/task_management_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'edit mode with an existing secret shows Change Vault and hides the field by default',
    (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VaultSettingsFields(
              enabled: true,
              method: VaultMethod.password,
              secretController: controller,
              hasExistingSecret: true,
              isEditing: true,
              isDeviceSecurityAvailable: true,
              onEnabledChanged: (_) {},
              onMethodChanged: (_) {},
              onChangeVaultChanged: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Change Vault'), findsOneWidget);
      expect(find.text('Enable Vault'), findsNothing);
      expect(
        find.text('Current security method: Custom Password'),
        findsOneWidget,
      );
      expect(find.byType(TextFormField), findsNothing);
    },
  );

  testWidgets(
    'edit mode reveals the new secret field when Change Vault is on',
    (tester) async {
      final controller = TextEditingController();
      var changeVault = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: VaultSettingsFields(
                  enabled: true,
                  method: VaultMethod.pin,
                  secretController: controller,
                  hasExistingSecret: true,
                  isEditing: true,
                  changeVault: changeVault,
                  isDeviceSecurityAvailable: true,
                  onEnabledChanged: (_) {},
                  onMethodChanged: (_) {},
                  onChangeVaultChanged: (value) {
                    setState(() {
                      changeVault = value;
                    });
                  },
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('New 4-Digit PIN'), findsNothing);

      await tester.tap(find.text('Change Vault'));
      await tester.pumpAndSettle();

      expect(find.text('New 4-Digit PIN'), findsOneWidget);
      expect(find.text('Enter a new 4-digit PIN'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
    },
  );
}
