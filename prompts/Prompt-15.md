# Objective

## Fixes, Changes, and Features for Dashboard and Task Management

---

## Description

The objective focuses on improving the Dashboard/Home Page by introducing a visual chart for task progress, removing existing collapsible task cards, and replacing them with a unified Tasks Status card. The goal is to enhance data visualization, simplify the interface, and provide clearer access to task information and interactions.

---

## Objectives Breakdown

### 1. Main Objective Area

Enhance the Dashboard/Home Page by adding a pie (circular) chart that visualizes task progress, including completed, today, upcoming, and overdue tasks, with interactive and filterable functionality.

---

### 2. Secondary Objective Area

Simplify the interface by removing the four collapsible task cards and replacing them with a consolidated Tasks Status card that lists all tasks with key details and interaction capabilities.

---

### 3. Supporting Tasks

#### 3.1 Task Group

* Add a pie chart to the Dashboard/Home Page for task visualization
* Display task categories: Completed, Today, Upcoming, and Overdue
* Include a central indicator showing the total task count
* Provide a legend below the chart for all task categories
* Enable interaction where selecting a chart segment highlights it and dims others
* Update the legend to reflect only the selected segment upon interaction
* Add filtering options (Today, This Week, This Month, All Tasks) in the chart’s context menu
* Ensure the chart updates dynamically based on the selected filter
* Remove the four collapsible cards (Today, Upcoming, Overdue, Completed) entirely
* Replace removed cards with a Tasks Status card displaying all tasks
* Show task details including icon, title, category, and date relative to today
* Follow the provided layout format from the Figma screenshot
* Add a context menu in the Tasks Status card for filtering (Completed, Today, Upcoming, Overdue)
* Enable navigation to the full task view when a task is clicked

---

### 4. Detailed Breakdown

#### 4.1 Pie Chart Visualization

The chart should present task distribution across Completed, Today, Upcoming, and Overdue categories, include a central task count indicator, and display a legend below for category identification.

#### 4.2 Interactive and Filtering Behavior

Selecting a segment of the pie chart should highlight it while dimming others, and the legend should reflect only the selected category. A context menu should allow filtering by Today, This Week, This Month, and All Tasks, updating the chart dynamically.

#### 4.3 Tasks Status Card Replacement

The four removed collapsible cards should be replaced with a Tasks Status card that lists all tasks, displaying their icon, title, category, and date, following the specified layout.

##### Nested Details

* Layout format follows the provided structure:

  * Icon | Task Title (Today)
  * Category Name | Date (e.g., Apr 28)
* Context menu includes filters: Completed, Today, Upcoming, Overdue
* Clicking a task opens the corresponding task details
* No additional functionality beyond what is specified is introduced
