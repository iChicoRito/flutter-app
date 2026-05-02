# Objective

## Add New Features and Changes Across Key Pages

---

## Description

The objective is to implement new features and improvements across multiple sections of the application, specifically the Home/Dashboard Page, Tasks Page, and Text/Rich Editor Page. The goal is to enhance user interaction, improve task management functionality, and expand editing capabilities while addressing existing issues. The expected outcome is a more flexible, interactive, and functional user experience based strictly on the specified changes.

---

## Objectives Breakdown

### 1. Main Objective Area

Enhance core application functionality by introducing new interaction features and improving existing components across the dashboard, task management system, and text editor.

---

### 2. Secondary Objective Area

Support usability improvements by enabling additional task actions, improving task organization, and expanding editor capabilities as explicitly described.

---

### 3. Supporting Tasks

#### 3.1 Task Group

* Implement context menu actions (Mark as Complete, Delete, Archive) in the "Tasks Status" section on the Home/Dashboard Page

* Enable draggable task cards in the Tasks Page (Tasks Lists Tab)

* Add a "Pin" option to the task card context menu

* Add an "Export" option to the task card context menu with JSON file output

* Improve WYSIWYG editor functionality and fix issues related to text highlighting

* Allow users to paste and remove images within the editor canvas

* Enable users to insert or attach files within the editor canvas

---

### 4. Detailed Breakdown

#### 4.1 Home/Dashboard Page

In the "Tasks Status" section, when a user holds a task card, a context menu should appear with the following options:

* Mark as Complete

* Delete

* Archive

#### 4.2 Tasks Page (Tasks Lists Tab)

* Task cards should be draggable, allowing users to reposition them freely (above, below, or anywhere)

* The task card context menu should include:

  * Pin option
  * Export option

* The Export function should allow users to export tasks with full details in JSON format

#### 4.3 Text / Rich Editor Page

* Add more options to the WYSIWYG editor
* Fix bugs related to text highlighting while typing
* Allow users to:

  * Paste images onto the canvas

  * Remove images from the canvas

  * Insert or attach files within the canvas

##### Nested Details

* Context menus are triggered by holding task cards
* Draggable behavior applies specifically to task cards in the Tasks Page
* Exported data must include full task details and be in JSON format
* Editor improvements are limited to stated functionality (options, bug fixes, media/file handling)
* No additional features or behaviors beyond those explicitly listed are included
