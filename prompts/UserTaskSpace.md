# **Objective: Tasks Space Feature**

## 1. Bottom Navigation Update

* Rename **“Analyze”** → **“Spaces”**
* Replace the icon with the provided briefcase SVG
    <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="currentColor" class="icon icon-tabler icons-tabler-filled icon-tabler-briefcase"><path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M22 13.478v4.522a3 3 0 0 1 -3 3h-14a3 3 0 0 1 -3 -3v-4.522l.553 .277a20.999 20.999 0 0 0 18.897 -.002l.55 -.275zm-8 -11.478a3 3 0 0 1 3 3v1h2a3 3 0 0 1 3 3v2.242l-1.447 .724a19.002 19.002 0 0 1 -16.726 .186l-.647 -.32l-1.18 -.59v-2.242a3 3 0 0 1 3 -3h2v-1a3 3 0 0 1 3 -3h4zm-2 8a1 1 0 0 0 -1 1a1 1 0 1 0 2 .01c0 -.562 -.448 -1.01 -1 -1.01zm2 -6h-4a1 1 0 0 0 -1 1v1h6v-1a1 1 0 0 0 -1 -1z" /></svg>

* Ensure:

  * Icon size, alignment, and active state match other nav items
  * Label uses same typography and spacing as existing tabs
  * Active state color follows design system

---

## 2. Tasks Space Page (Main Screen)

### Layout & UI

* Follow the **Figma design exactly**:

  * Spacing, grid system, typography, and color hierarchy must be pixel-accurate
* Two view modes:

  * **Grid View**
  * **List View**
* Views must be:

  * Toggleable (tab or switch)
  * Persist user preference (optional but recommended)

### Folder (Space) Card

Each Space is represented as a card containing:

* **Space Name**
* **Short Description**
* **Category indicator**
* **Color accent (based on selected folder color)**
* **Task Count Badge**

  * Red circular badge
  * Displays number of tasks inside the space
  * Hide if empty (optional UX decision)

### Interactions

* Tap card → Open Space
* Long press OR tap **3-dot menu (⋮)** → Open context menu:

  * **Edit**
  * **Delete**

---

## 3. Create / Edit Space

### Navigation Flow

* Tap **“Create Space”** → Redirect to creation page
* Edit uses the same page with pre-filled values

### Fields

* **Space Name** (required)
* **Short Description**
* **Category**

  * Same selection logic as task creation
* **Space Color**

  * Color picker or predefined palette

### Behavior

* On submit:

  * Validate required fields
  * Create or update space
  * Redirect back to Spaces page

---

## 4. Context Menu Actions

### Edit

* Opens the same creation page
* Pre-filled data
* Updates existing space

### Delete

* Must show confirmation dialog:

  * Same design pattern as task deletion
  * Message example:

    > “Deleting this space will remove all tasks inside. This action cannot be undone.”

* Actions:

  * Cancel
  * Confirm Delete

* On confirm:

  * Delete space
  * Delete all associated tasks

---

## 5. Inside a Space (Tasks View)

### Navigation Flow

* Tap a Space → Redirect to Space-specific task page

### Behavior

* Functions like **Task Management**, but scoped to the selected Space

### Task Creation

* Same UI and logic as existing task creation
* **Category is automatically assigned**

  * Based on the Space’s category
  * Not editable (or optionally locked with visibility)

---

## 6. Additional UX Improvements (Recommended)

### Empty State

* If no spaces:

  * Show illustration + CTA:

    > “No spaces yet. Create one to organize your tasks.”

### Performance

* Lazy load spaces if many exist
* Optimize badge updates in real-time

### Accessibility

* Ensure:

  * Touch targets ≥ 44px
  * Color contrast meets WCAG
  * Icons have labels for screen readers

---

## 7. Suggested Component Structure (Dev-Friendly)

* `SpacesPage`

  * `ViewToggle (Grid/List)`
  * `SpaceCard`
  * `ContextMenu`
* `CreateEditSpacePage`
* `SpaceDetailPage`

  * `TaskList`
  * `CreateTaskModal`

---
