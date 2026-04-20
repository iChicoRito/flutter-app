## Objective: Design and Functionality Refractor

### 1. Profile Page – Typography Adjustment

- **Increase font size** of the **Name** and **Status** labels on the Profile Page.
- The increase should be **small / just a bit**.

### 2. Profile Page – Four Counters (Text Change)

- Replace the existing multi‑word labels with **single‑word labels only**:
  - `"Completed"`
  - `"Pending"`
  - `"Overdue"`
  - `"Vaults"`
- (No extra words, no descriptions under/above these single words.)

### 3. Vault / Secured Tasks & Space – Incorrect Password Lockout

- **Trigger:** User enters an **incorrect vault password**.
- **Limit:** After **5 failed attempts** (consecutive or within a session – clarify later), the **tasks and space** become **locked**.
- **Lock duration:** **5 minutes**.
- During lockout:
  - No access to secured tasks and space.
  - Password attempts are either blocked or ignored.
  - User must wait 5 minutes before trying again.
- (No deletion, no permanent lock, no email recovery required for this feature.)
