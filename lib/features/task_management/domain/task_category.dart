import 'package:flutter/material.dart';
import 'package:tabler_icons/tabler_icons.dart';

class TaskCategory {
  const TaskCategory({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.colorValue,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String iconKey;
  final int colorValue;
  final DateTime createdAt;

  Color get color => Color(colorValue);

  TaskCategory copyWith({
    String? id,
    String? name,
    String? iconKey,
    int? colorValue,
    DateTime? createdAt,
  }) {
    return TaskCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class TaskCategoryIconOption {
  const TaskCategoryIconOption({
    required this.key,
    required this.icon,
    required this.label,
  });

  final String key;
  final IconData icon;
  final String label;
}

const taskCategoryIconOptions = [
  TaskCategoryIconOption(
    key: 'briefcase',
    icon: TablerIcons.briefcase,
    label: 'Work',
  ),
  TaskCategoryIconOption(
    key: 'user',
    icon: TablerIcons.user,
    label: 'Personal',
  ),
  TaskCategoryIconOption(key: 'book', icon: TablerIcons.book, label: 'Study'),
  TaskCategoryIconOption(
    key: 'shopping_cart',
    icon: TablerIcons.shopping_cart,
    label: 'Shopping',
  ),
  TaskCategoryIconOption(
    key: 'heartbeat',
    icon: TablerIcons.heartbeat,
    label: 'Health',
  ),
  TaskCategoryIconOption(key: 'cash', icon: TablerIcons.cash, label: 'Finance'),
  TaskCategoryIconOption(
    key: 'star',
    icon: TablerIcons.star,
    label: 'Favorite',
  ),
  TaskCategoryIconOption(key: 'home', icon: TablerIcons.home, label: 'Home'),
];

IconData resolveTaskCategoryIcon(String iconKey) {
  for (final option in taskCategoryIconOptions) {
    if (option.key == iconKey) {
      return option.icon;
    }
  }

  return TablerIcons.tag;
}

const taskCategoryColorOptions = [
  Color(0xFF1E88E5),
  Color(0xFF0CA678),
  Color(0xFFF59F00),
  Color(0xFFD63939),
  Color(0xFF6B7280),
  Color(0xFF7C3AED),
];
