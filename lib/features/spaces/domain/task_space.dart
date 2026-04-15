import 'package:flutter/material.dart';

class TaskSpace {
  const TaskSpace({
    required this.id,
    required this.name,
    required this.description,
    required this.categoryId,
    required this.colorValue,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String description;
  final String categoryId;
  final int colorValue;
  final DateTime createdAt;
  final DateTime updatedAt;

  Color get color => Color(colorValue);

  TaskSpace copyWith({
    String? id,
    String? name,
    String? description,
    String? categoryId,
    int? colorValue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TaskSpace(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
