enum VaultMethod { password, pin, deviceSecurity }

class VaultConfig {
  const VaultConfig({
    required this.isEnabled,
    required this.method,
    this.secretKeyRef,
  });

  final bool isEnabled;
  final VaultMethod method;
  final String? secretKeyRef;

  bool get usesSecret =>
      method == VaultMethod.password || method == VaultMethod.pin;

  VaultConfig copyWith({
    bool? isEnabled,
    VaultMethod? method,
    String? secretKeyRef,
    bool clearSecretKeyRef = false,
  }) {
    return VaultConfig(
      isEnabled: isEnabled ?? this.isEnabled,
      method: method ?? this.method,
      secretKeyRef: clearSecretKeyRef
          ? null
          : secretKeyRef ?? this.secretKeyRef,
    );
  }
}

class VaultDraft {
  const VaultDraft({
    required this.isEnabled,
    this.method,
    this.secret,
    this.keepExistingSecret = false,
  });

  const VaultDraft.disabled()
    : isEnabled = false,
      method = null,
      secret = null,
      keepExistingSecret = false;

  final bool isEnabled;
  final VaultMethod? method;
  final String? secret;
  final bool keepExistingSecret;
}
