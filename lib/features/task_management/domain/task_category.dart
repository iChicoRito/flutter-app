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
  TaskCategoryIconOption(key: 'bolt', icon: TablerIcons.bolt, label: 'Focus'),
  TaskCategoryIconOption(
    key: 'calendar',
    icon: TablerIcons.calendar_event,
    label: 'Events',
  ),
  TaskCategoryIconOption(
    key: 'device_laptop',
    icon: TablerIcons.device_laptop,
    label: 'Tech',
  ),
  TaskCategoryIconOption(
    key: 'plane',
    icon: TablerIcons.plane,
    label: 'Travel',
  ),
  TaskCategoryIconOption(
    key: 'receipt',
    icon: TablerIcons.receipt,
    label: 'Bills',
  ),
  TaskCategoryIconOption(key: 'movie', icon: TablerIcons.movie, label: 'Media'),
  TaskCategoryIconOption(
    key: 'palette',
    icon: TablerIcons.palette,
    label: 'Creative',
  ),
  TaskCategoryIconOption(
    key: 'barbell',
    icon: TablerIcons.barbell,
    label: 'Fitness',
  ),
  TaskCategoryIconOption(
    key: 'friends',
    icon: TablerIcons.friends,
    label: 'Social',
  ),
  TaskCategoryIconOption(
    key: 'chef_hat',
    icon: TablerIcons.chef_hat,
    label: 'Food',
  ),
  TaskCategoryIconOption(
    key: 'plant',
    icon: TablerIcons.plant_2,
    label: 'Garden',
  ),
  TaskCategoryIconOption(key: 'tools', icon: TablerIcons.tools, label: 'Fixes'),
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
  Color(0xFF066FD1),
  Color(0xFF90CAF9),
  Color(0xFFE6F0FA),
  Color(0xFF0CA678),
  Color(0xFFF59F00),
  Color(0xFFD63939),
  Color(0xFF6B7280),
];
