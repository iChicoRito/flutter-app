## Current Problem
- Editing a task or space forces the user to also go through vault password editing.
- The vault password field is treated as required during edit, even if the user doesn’t want to change it.

## Desired Behavior
When editing a task or space:

1. **Vault section is NOT required**  
   - The vault password field does not block saving the task/space edits.
   - The existing vault stays unchanged by default.

2. **Optional vault change**  
   - Add a **“Change Vault”** switch (toggle / checkbox) near the vault password field.
   - Default state: **OFF** → vault password field is disabled / hidden / ignored.
   - When user turns the switch **ON**:  
     - Vault password field becomes editable.  
     - User can enter a new password to update the vault.  
     - On save, only then does the system change the vault password.

## User Flow Example
1. User opens edit screen for a task.
2. Sees task fields + vault section with “Change Vault” switch (default OFF).
3. User edits task name, date, etc.
4. User does **not** touch the vault switch → saves → only task updates, vault unchanged.
5. If user wants to change vault:  
   - Turns ON “Change Vault” → enters new password → saves → task + vault both update.