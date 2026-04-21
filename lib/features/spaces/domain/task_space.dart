import 'package:flutter/material.dart';

import '../../../core/vault/vault_models.dart';

class TaskSpace {
  const TaskSpace({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.colorValue,
    required this.createdAt,
    required this.updatedAt,
    this.vaultConfig,
    this.archivedAt,
  });

  final String id;
  final String name;
  final String description;
  final String categoryId;
  final int colorValue;
  final DateTime createdAt;
  final DateTime updatedAt;
  final VaultConfig? vaultConfig;
  final DateTime? archivedAt;

  Color get color => Color(colorValue);
  bool get isArchived => archivedAt != null;

  TaskSpace copyWith({
    String? id,
    String? name,
    String? description,
    String? categoryId,
    int? colorValue,
    DateTime? createdAt,
    DateTime? updatedAt,
    VaultConfig? vaultConfig,
    bool clearVaultConfig = false,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
  }) {
    return TaskSpace(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      vaultConfig: clearVaultConfig ? null : vaultConfig ?? this.vaultConfig,
      archivedAt: clearArchivedAt ? null : archivedAt ?? this.archivedAt,
    );
  }
}
