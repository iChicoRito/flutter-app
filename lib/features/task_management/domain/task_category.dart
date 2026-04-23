import 'package:flutter/material.dart';
import 'package:tabler_icons/tabler_icons.dart';

import '../../../core/theme/app_design_tokens.dart';

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
  TaskCategoryIconOption(key: 'music', icon: TablerIcons.music, label: 'Music'),
  TaskCategoryIconOption(key: 'paw', icon: TablerIcons.paw, label: 'Pets'),
  TaskCategoryIconOption(
    key: 'camera',
    icon: TablerIcons.camera,
    label: 'Photos',
  ),
  TaskCategoryIconOption(key: 'gift', icon: TablerIcons.gift, label: 'Gifts'),
  TaskCategoryIconOption(
    key: 'certificate',
    icon: TablerIcons.certificate,
    label: 'Goals',
  ),
  TaskCategoryIconOption(
    key: 'coffee',
    icon: TablerIcons.coffee,
    label: 'Break',
  ),
  TaskCategoryIconOption(key: 'car', icon: TablerIcons.car, label: 'Commute'),
  TaskCategoryIconOption(
    key: 'bicycle',
    icon: TablerIcons.bike,
    label: 'Cycling',
  ),
  TaskCategoryIconOption(key: 'bulb', icon: TablerIcons.bulb, label: 'Ideas'),
  TaskCategoryIconOption(key: 'phone', icon: TablerIcons.phone, label: 'Calls'),
  TaskCategoryIconOption(key: 'mail', icon: TablerIcons.mail, label: 'Email'),
  TaskCategoryIconOption(
    key: 'map_pin',
    icon: TablerIcons.map_pin,
    label: 'Places',
  ),
  TaskCategoryIconOption(key: 'medal', icon: TablerIcons.medal, label: 'Wins'),
  TaskCategoryIconOption(key: 'notes', icon: TablerIcons.notes, label: 'Notes'),
  TaskCategoryIconOption(
    key: 'palette_off',
    icon: TablerIcons.brush,
    label: 'Design',
  ),
  TaskCategoryIconOption(
    key: 'trophy',
    icon: TablerIcons.trophy,
    label: 'Awards',
  ),
  TaskCategoryIconOption(
    key: 'activity',
    icon: TablerIcons.activity,
    label: 'Active',
  ),
  TaskCategoryIconOption(key: 'alarm', icon: TablerIcons.alarm, label: 'Alarm'),
  TaskCategoryIconOption(
    key: 'archive',
    icon: TablerIcons.archive,
    label: 'Archive',
  ),
  TaskCategoryIconOption(key: 'bell', icon: TablerIcons.bell, label: 'Alerts'),
  TaskCategoryIconOption(
    key: 'building',
    icon: TablerIcons.building,
    label: 'Office',
  ),
  TaskCategoryIconOption(key: 'bus', icon: TablerIcons.bus, label: 'Bus'),
  TaskCategoryIconOption(
    key: 'calculator',
    icon: TablerIcons.calculator,
    label: 'Math',
  ),
  TaskCategoryIconOption(
    key: 'chart_bar',
    icon: TablerIcons.chart_bar,
    label: 'Stats',
  ),
  TaskCategoryIconOption(
    key: 'checklist',
    icon: TablerIcons.checklist,
    label: 'Checklist',
  ),
  TaskCategoryIconOption(
    key: 'clipboard_list',
    icon: TablerIcons.clipboard_list,
    label: 'Clipboard',
  ),
  TaskCategoryIconOption(key: 'cloud', icon: TablerIcons.cloud, label: 'Cloud'),
  TaskCategoryIconOption(key: 'code', icon: TablerIcons.code, label: 'Code'),
  TaskCategoryIconOption(
    key: 'compass',
    icon: TablerIcons.compass,
    label: 'Explore',
  ),
  TaskCategoryIconOption(
    key: 'device_mobile',
    icon: TablerIcons.device_mobile,
    label: 'Mobile',
  ),
  TaskCategoryIconOption(
    key: 'flame',
    icon: TablerIcons.flame,
    label: 'Streak',
  ),
  TaskCategoryIconOption(
    key: 'gamepad',
    icon: TablerIcons.device_gamepad_2,
    label: 'Games',
  ),
  TaskCategoryIconOption(
    key: 'headphones',
    icon: TablerIcons.headphones,
    label: 'Audio',
  ),
  TaskCategoryIconOption(
    key: 'microphone',
    icon: TablerIcons.microphone,
    label: 'Voice',
  ),
  TaskCategoryIconOption(
    key: 'moon',
    icon: TablerIcons.moon_stars,
    label: 'Night',
  ),
  TaskCategoryIconOption(
    key: 'puzzle',
    icon: TablerIcons.puzzle,
    label: 'Puzzle',
  ),
  TaskCategoryIconOption(
    key: 'school',
    icon: TablerIcons.school,
    label: 'School',
  ),
  TaskCategoryIconOption(
    key: 'shield',
    icon: TablerIcons.shield,
    label: 'Secure',
  ),
  TaskCategoryIconOption(
    key: 'shopping_bag',
    icon: TablerIcons.shopping_bag,
    label: 'Bag',
  ),
  TaskCategoryIconOption(
    key: 'swimming',
    icon: TablerIcons.swimming,
    label: 'Swim',
  ),
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
  AppColors.blue500,
  AppColors.amber500,
  AppColors.teal500,
  AppColors.rose500,
  AppColors.indigo500,
  AppColors.neutral500,
];
