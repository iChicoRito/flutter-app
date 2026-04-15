**Objective: Add Vault Security for Specific Tasks and Spaces**

To improve user privacy, add a **Vault Security** feature for both **Specific Tasks** and **Spaces**.

### Requirements

**1. Privacy protection for Tasks and Spaces**
At the moment, newly created tasks and spaces are accessible without protection. Since user privacy is a high priority, users should have the option to secure sensitive tasks or spaces.

**2. Add Vault option during creation**
When creating a task or space, include a **Vault toggle switch**.

When the **Vault** switch is turned on, the user must be able to choose a security method:

* **Custom password**
* **4-digit PIN**
* **Device security**

  * Phone password
  * Fingerprint / biometric authentication

This security field should only appear once Vault is activated.

**3. Authentication when opening protected content**
If a task or space has Vault enabled, the app should prompt the user for authentication before opening it.

The prompt should support the security method selected during setup:

* Enter password
* Enter PIN
* Use device password
* Use fingerprint / biometric authentication

**4. Locked indicator for better UI/UX**
Add a **lock icon indicator** to protected tasks and spaces so users can easily identify which items are secured.

### Enhanced Expected Behavior

* Users can decide which tasks or spaces need protection.
* Protected tasks and spaces cannot be opened without successful authentication.
* The UI clearly shows which items are locked.
* The feature gives users more control over privacy and sensitive information.

### Suggested polished version for documentation

**Feature Name:** Vault Security for Tasks and Spaces

**Description:**
Introduce Vault Security to allow users to protect individual tasks and spaces with an extra layer of authentication. During creation, users can enable Vault and select their preferred security method, such as a password, 4-digit PIN, or device-level authentication like fingerprint or phone password. When accessing protected content, the user must authenticate first. Locked items should also display a lock icon for better usability and visibility.
