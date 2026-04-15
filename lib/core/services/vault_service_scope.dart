import 'package:flutter/widgets.dart';

import 'vault_service.dart';

class VaultServiceScope extends InheritedWidget {
  const VaultServiceScope({
    super.key,
    required this.vaultService,
    required super.child,
  });

  final VaultService vaultService;

  static VaultService? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<VaultServiceScope>()
        ?.vaultService;
  }

  static VaultService of(BuildContext context) {
    return maybeOf(context) ?? const NoopVaultService();
  }

  @override
  bool updateShouldNotify(VaultServiceScope oldWidget) {
    return vaultService != oldWidget.vaultService;
  }
}
