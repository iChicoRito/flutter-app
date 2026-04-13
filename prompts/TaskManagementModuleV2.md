**Objective: Refactor Tasks Management UI/UX**

Improve the overall Tasks Management interface to make it more consistent, theme-aligned, and user-friendly.

### 1. Input Field Design Consistency

* Redesign all input fields to use a proper **label + input field** structure.
* In the **Task display section**, apply the same visual style used in the **search bar field** for text-based fields so the UI feels consistent.

### 2. Description Field

* Convert the **Description** field into a **textarea**.
* Ensure it is styled consistently with the rest of the form and supports comfortable multi-line input.

### 3. Select Dropdown Styling

* Update all **select fields** so they match the **filter dropdown UI** used in the Tasks filtering section.
* The dropdowns should feel unified with the existing design system and theme.

### 4. Category Creation Redesign

Rename the category section to **Create Category** and make it more flexible for customization.

Required fields and behavior:

* **Category Name**
* **Icon**

  * Icon-only display, with **no text inside the icon selector**
  * Add a wider range of options, around **20 icons**
  * The icon selection UI should follow a **chip-style design**
* **Color Selection**

  * Keep color options limited according to the existing **color rules protocol**
  * Make the selection visually clear and aligned with the theme

### 5. Modal Structure Improvement

Refactor the modal layout into a clearer structure:

* **Modal Header**
* **Modal Body**
* **Modal Footer**

Design requirement:

* Add a **separator line between the header and body**, similar to the divider style used in the **dashboard page cards**
* Keep the modal clean, structured, and visually balanced

### 6. Date and Time UI Enhancement

* Update the **date picker** to better match the current theme
* Split date inputs into:

  * **Start Date**
  * **End Date**
* Split time inputs into:

  * **Start Time**
  * **End Time**
* Redesign the **date and time picker layout** so it feels more polished, distinct, and theme-based rather than using a default/plain layout

### Expected Outcome

The Tasks Management UI should feel more modern, cohesive, and easier to use, with consistent form elements, better modal structure, improved customization for categories, and date/time controls that better reflect the product’s visual theme.
