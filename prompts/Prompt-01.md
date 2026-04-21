## Objective: System Design / Functionality Changes

### Context Menu

1. **New "Archive" Option**  
   In the **Tasks** and **Space** pages, the context menu currently includes only **Delete**, **Move to Space**, and **Edit**.  
   → Add a new menu item: **"Archive"**.

2. **Icons for Better UI/UX**  
   Add the following provided icons to their respective context menu items:

   - **Delete**  
     `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="icon icon-tabler icons-tabler-outline icon-tabler-trash"><path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M4 7l16 0" /><path d="M10 11l0 6" /><path d="M14 11l0 6" /><path d="M5 7l1 12a2 2 0 0 0 2 2h8a2 2 0 0 0 2 -2l1 -12" /><path d="M9 7v-3a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v3" /></svg>`

   - **Edit**  
     `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="icon icon-tabler icons-tabler-outline icon-tabler-edit"><path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M7 7h-1a2 2 0 0 0 -2 2v9a2 2 0 0 0 2 2h9a2 2 0 0 0 2 -2v-1" /><path d="M20.385 6.585a2.1 2.1 0 0 0 -2.97 -2.97l-8.415 8.385v3h3l8.385 -8.415" /><path d="M16 5l3 3" /></svg>`

   - **Move to Space**  
     `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="icon icon-tabler icons-tabler-outline icon-tabler-folder-share"><path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M13 19h-8a2 2 0 0 1 -2 -2v-11a2 2 0 0 1 2 -2h4l3 3h7a2 2 0 0 1 2 2v4" /><path d="M16 22l5 -5" /><path d="M21 21.5v-4.5h-4.5" /></svg>`

   - **Archive** (new item)  
     `<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="icon icon-tabler icons-tabler-outline icon-tabler-archive"><path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M3 6a2 2 0 0 1 2 -2h14a2 2 0 0 1 2 2a2 2 0 0 1 -2 2h-14a2 2 0 0 1 -2 -2" /><path d="M5 8v10a2 2 0 0 0 2 2h10a2 2 0 0 0 2 -2v-10" /><path d="M10 12l4 0" /></svg>`

3. **Vault/Locked Restriction**  
   If a task is in the **vault** or **locked**, the user must **enter the vault password** before moving the task to any space.

---

### Rich Editing Page

1. **Full-Screen Editor**  
   - The rich editing page for tasks should be **full-screen** (fills the entire width of the screen, not confined to a container).  
   - The **WYSIWYG tabs** should be placed **below** the editor and remain **sticky** so they stay visible at the bottom of the viewport when scrolling (similar to standard rich editors).

2. **Context Menu (Upper Right)**  
   - Apply the same changes as the main context menu:  
     - Add icons to existing items.  
     - Add the **"Archive"** menu item.

---

### Space Page

1. **Category Creation (Like Tasks Page)**  
   - In space creation, allow users to **add new categories** with the same functionality as in the Tasks page.  
   - Users can create their own category, choose an **icon**, and choose a **color**.

2. **Space Title Validation**  
   - Maximum of **16 characters** for the Space Title.

3. **Button Styling Consistency**  
   - Reduce the border-radius of the **"+ New"** button in Category creation to match the radius of other fields.

---

### Tasks Page

1. **Space Title Validation**  
   - Maximum of **16 characters** for the Space Title.

2. **Button Styling Consistency**  
   - Reduce the border-radius of the **"+ New"** button in Category creation to match the radius of other fields.

---

### Profile Page

1. **Typography Adjustments**  
   - Slightly **increase** the font size of the **User's Name**.  
   - Set the **font-weight** of the user's status to **"medium"**.

---