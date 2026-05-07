# Objective
## Add Bar Chart for Weekly Task Count

---

## Description

This objective focuses on adding a bar chart to the dashboard or home page to improve task visualization. The chart will allow users to track the number of tasks created per day within a week of the current month. Additionally, a context menu — accessible via a three-dot (⋮) icon — will provide options to filter or export the chart data.

---

## Objectives Breakdown

### 1. Main Objective Area

Implement a bar chart on the dashboard/home page that displays the count of tasks created per day, scoped to a week within the current month.

---

### 2. Secondary Objective Area

Provide user controls through a context menu (triggered by a three-dot icon) to allow filtering and data export options directly from the chart.

---

### 3. Supporting Tasks

Break down the objective into actionable tasks based on what is stated.

#### 3.1 Chart Implementation
- Add a bar chart component to the dashboard/home page
- Display task count per day across the days of a selected week
- Scope the chart data to a week within the current month

#### 3.2 Context Menu Implementation
- Add a three-vertical-dot (⋮) icon associated with the bar chart
- On click, display a context menu with the following items:
  - **This Week** — filter chart to show the current week's data
  - **This Month** — filter chart to show the current month's data
  - **Export Data** — allow the user to export the chart data

---

### 4. Detailed Breakdown

#### 4.1 Bar Chart Display
The bar chart must be placed on the dashboard/home page and serve as a new visualization component for task tracking.

#### 4.2 Data Representation
Each bar in the chart represents the number of tasks created on a specific day, grouped by week within the current month.

#### 4.3 Context Menu Behavior
The three-vertical-dot icon, when clicked, opens a context menu with exactly three items:

##### Context Menu Items
- **This Week** — filters and displays data for the current week
- **This Month** — filters and displays data for the current month
- **Export Data** — triggers an export action for the chart's data

---