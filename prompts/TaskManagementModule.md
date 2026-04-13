## Task Management Module

### Overview

Replace the current **wallet** item in the bottom navigation bar with a **notes/tasks** icon using **Tabler Icons only**. This section will serve as the **Task Management Module**, which is one of the **main core features of the app**.

This module allows users to manage their personal productivity offline by creating and organizing **tasks, notes, reminders, and schedules**. Since the app works offline, all data will be stored locally using **Hive**.

---

## 1. Bottom Navigation Update

### Change Required

* Replace the **wallet** icon in the bottom navbar
* Use a **Tabler** icon only
* Recommended icons:

  * `Icon(TablerIcons.notes)`
  * `Icon(TablerIcons.notebook)`
  * `Icon(TablerIcons.checklist)`
  * `Icon(TablerIcons.edit)`

### Recommended Choice

Use **`TablerIcons.checklist`** or **`TablerIcons.notes`** because they better represent:

* tasks
* reminders
* notes
* productivity management

---

## 2. Module Purpose

This page is the **Task Management Module** where the user can perform full **CRUD operations** for:

* tasks
* notes
* reminders

This module should feel like the **central productivity hub** of the app.

---

## 3. Core Features

### Required Functions

* Add task
* Edit task
* Delete task
* Mark task as completed
* Restore completed task
* Search task

### Recommended Additional Functions

To make the module more complete and useful:

* Filter by category
* Filter by status
* Sort by due date, priority, or creation date
* Archive old/completed tasks
* Pin important tasks
* Empty trash / permanently delete
* View overdue tasks
* Toggle reminder on/off
* Duplicate task

---

## 4. Task Data Fields

Each task may contain the following fields:

* **id**
* **task title**
* **description / notes**
* **due date**
* **due time**
* **priority**
* **category**
* **reminder**
* **timer**
* **repeat option**
* **status**
* **created at**
* **updated at**
* **is completed**
* **completed at** *(optional)*

### Suggested Field Details

* **task title**: required
* **description / notes**: optional
* **due date**: optional
* **due time**: optional
* **priority**: low / medium / high / urgent
* **category**: work, personal, school, health, etc.
* **reminder**: date/time before task deadline or custom reminder time
* **timer**: duration for focus or countdown tracking
* **repeat option**: none / daily / weekly / monthly / custom
* **status**: pending / completed / overdue / archived

---

## 5. Category Management

When adding or editing a task, the user should be able to select a category.

### Category Features

* Choose from existing categories
* Create a new category if no suitable category exists
* Assign an icon to the category
* Assign a color to the category

### Category Fields

* **id**
* **name**
* **icon**
* **color**
* **createdAt**

### Example Default Categories

* Personal
* Work
* Study
* Shopping
* Health
* Finance

### Category Customization

Users should be able to:

* add category
* edit category
* delete category
* choose category icon
* choose category color

---

## 6. Offline Storage with Hive

Since the app is offline-first, use **Hive** as the local database.

### Why Hive

* lightweight
* fast local storage
* works well offline
* easy integration with Flutter
* suitable for structured local data

### Data to Store in Hive

* tasks
* categories
* reminders configuration
* task status changes
* local preferences for sorting/filtering

### Suggested Hive Boxes

* `tasksBox`
* `categoriesBox`
* `settingsBox`

---

## 7. Suggested Data Models

### Task Model

```dart
@HiveType(typeId: 0)
class TaskModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String? description;

  @HiveField(3)
  DateTime? dueDate;

  @HiveField(4)
  String? dueTime;

  @HiveField(5)
  String priority;

  @HiveField(6)
  String categoryId;

  @HiveField(7)
  DateTime? reminderDateTime;

  @HiveField(8)
  int? timerMinutes;

  @HiveField(9)
  String repeatOption;

  @HiveField(10)
  String status;

  @HiveField(11)
  bool isCompleted;

  @HiveField(12)
  DateTime createdAt;

  @HiveField(13)
  DateTime updatedAt;

  @HiveField(14)
  DateTime? completedAt;

  TaskModel({
    required this.id,
    required this.title,
    this.description,
    this.dueDate,
    this.dueTime,
    required this.priority,
    required this.categoryId,
    this.reminderDateTime,
    this.timerMinutes,
    required this.repeatOption,
    required this.status,
    required this.isCompleted,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });
}
```

### Category Model

```dart
@HiveType(typeId: 1)
class CategoryModel extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String icon;

  @HiveField(3)
  int colorValue;

  @HiveField(4)
  DateTime createdAt;

  CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.colorValue,
    required this.createdAt,
  });
}
```

---

## 8. UI/UX Suggestions

### Main Task Screen

Sections may include:

* Search bar
* Category filter chips
* Task list
* Completed section
* Floating action button for adding task

### Task Item Actions

Each task card can support:

* tap to view/edit
* checkbox to mark complete
* swipe left to delete
* swipe right to edit
* long press for more options

### Add/Edit Task Screen

Form fields:

* title
* description
* due date
* due time
* priority dropdown
* category selector
* reminder selector
* timer input
* repeat option
* save button

### Empty State

If no tasks exist:

* show illustration or icon
* message like:
  **“No tasks yet. Start by adding your first task.”**

---

## 9. Business Logic Suggestions

### Task Status Rules

* If `isCompleted == true`, status = `completed`
* If due date has passed and not completed, status = `overdue`
* If archived manually, status = `archived`
* Otherwise, status = `pending`

### Search Behavior

Search should match:

* title
* description
* category name

### Restore Behavior

When restoring a completed task:

* `isCompleted = false`
* `status = pending`
* `completedAt = null`

---

## 10. Enhanced Final Objective Statement

Here is a cleaner version you can use directly in documentation:

> **Task Management Module**
>
> Replace the wallet icon in the bottom navigation bar with a suitable **Tabler notes/tasks icon**. This page will serve as the **Task Management Module**, one of the main core features of the app.
>
> The module should allow users to manage their productivity offline by performing full CRUD operations on tasks, notes, and reminders. Users must be able to add, edit, delete, complete, restore, and search tasks.
>
> Each task may include fields such as title, description, due date, due time, priority, category, reminder, timer, repeat option, and status.
>
> The module must also support **category management**, allowing users to choose from predefined categories or create their own category with a custom name, icon, and color.
>
> Since the app works offline, all task and category data must be stored locally using **Hive**, with no online database integration for now.

---