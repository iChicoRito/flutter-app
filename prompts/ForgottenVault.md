## Enhanced Logic – Vault Recovery Keys (2×3 Grid, 6 Keys Total)

**Core Principle:**  
When a user creates or secures a vault (tasks/spaces with a password), the system generates and displays **6 unique recovery keys** in a **2×3 grid layout**. These keys are the **only** way to recover access if the password is forgotten.

---

### 1. When Are Recovery Keys Generated?

- **Trigger:** User successfully creates a vault password for tasks/spaces.
- **Also triggered if:** User changes the vault password (new keys are generated).
- **Display method:** Modal window, shown immediately after vault creation.

---

### 2. Recovery Key Format & Structure

- **Format example:** `A7F2-K9L3`
- **Total keys:** 6 keys
- **Layout:** 2 rows × 3 columns (2×3 grid)

**Example display (modal):**

```
Your Vault Recovery Keys – Save these securely.

┌─────────────┬─────────────┬─────────────┐
│  A7F2-K9L3  │  M4N8-Q2R6  │  X1C5-V7B9  │
├─────────────┼─────────────┼─────────────┤
│  D3E6-W0T4  │  F9H2-J7K1  │  L5P8-Z3M0  │
└─────────────┴─────────────┴─────────────┘
```

- **Character set:** Alphanumeric (A-Z, 0-9), excluding ambiguous characters (O, 0, I, 1) to avoid confusion.
- **Pattern:** 4 characters – dash – 4 characters per key.

---

### 3. Recovery Process (When Password Is Forgotten)

**Step 1 – User clicks "Forgot Vault Password"** on the locked tasks/spaces screen.

**Step 2 – System prompts:** "Enter any one of your 6 recovery keys."

**Step 3 – User enters** a single valid recovery key (e.g., `A7F2-K9L3`).

**Step 4 – System validates:**
- If key matches **any** stored recovery key for that vault → **Grant access.**
- If key is invalid → Reject and log attempt (security measure).

**Step 5 – Upon successful recovery:**
- User is **immediately granted access** to the vault (tasks/spaces are unlocked).
- **Recommended:** Force user to **create a new vault password** before continuing.

---

### 4. Security & Storage Rules

| Item | Rule |
|------|------|
| **Where keys are stored** | Hashed or encrypted, same as password. Never stored in plain text. |
| **User responsibility** | User must save/print/write down the 6 keys. System does not email or SMS them. |
| **Key regeneration** | Each new vault password generates a brand new set of 6 keys. Old keys become invalid. |
| **Key usage limit** | Each key can be used only once for recovery (after use, that key is invalidated, but the other 5 remain valid). |
| **Failed attempts** | Max 5 failed recovery attempts → temporary lockout (e.g., 15 minutes). |
| **Recovery completion** | After recovery and password reset, generate a new set of 6 keys and show modal again. |

---

### 5. Modal Behavior

- **Title:** "Your Vault Recovery Keys – Save These Securely"
- **Warning text:** "If you lose these keys and forget your password, your vault cannot be recovered."
- **Layout:** 2 rows × 3 columns grid
- **Options in modal:**
  - Copy all keys (one-click copy, 6 keys as plain text separated by commas or lines)
  - Download as PDF/TXT
  - Print
  - "I have saved my recovery keys" (button to close modal)

- **Modal does NOT close** until user explicitly confirms they have saved the keys (checkbox or button).

---

### 6. Summary Table – 6 Recovery Keys (2×3)

| Item | Value |
|------|-------|
| **Grid size** | 2 rows × 3 columns |
| **Total keys** | 6 |
| **Format per key** | `XXXX-XXXX` (e.g., `A7F2-K9L3`) |
| **Display** | 2×3 grid modal |
| **Purpose** | Sole recovery method for forgotten vault password |
| **Requirement** | User must save them at vault creation |