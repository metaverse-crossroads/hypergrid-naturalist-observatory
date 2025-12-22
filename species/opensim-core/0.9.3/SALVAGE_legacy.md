# R&D Journal: The Timeline Merge

**Date:** December 2025
**Topic:** Consolidating "Surgical Injection" (Main) vs. "Native Configuration" (Crashed)
**Status:** ARCHIVAL

## 1. The Divergence
During the "Naturalist Observatory" migration, two distinct evolutionary paths emerged for populating the environment and handling the headless state.
* **Timeline A (Main):** Relied on external tooling (`Sequencer.dll`) and monkey-patching.
* **Timeline B (Crashed):** Leveraged internal OpenSim features (`startup_commands`) and cleaner .NET APIs.

This document preserves the unique value of *both* before the merge.

---

## 2. If we kept the Main Branch (Surgical)
**What would be lost from the Crashed Session?**

### A. The "Native Boot" Discovery
We would lose the realization that OpenSim has a built-in macro system for bootstrapping.
* **The Discovery:** `OpenSim.ini` supports `startup_console_commands_file = "startup_commands.txt"`.
* **The Value:** This allows for "No-Code" population. We don't need to maintain a C# tool (`Sequencer`) just to create users. It is robust against database schema changes because it uses the server's own logic.

### B. The "Deep Sea" Console Detection
We would lose the correct way to detect a headless environment in .NET 8.
* **Main Branch Hack:** Reads `null` from `ReadLine` and sleeps for 1000ms. Brittle; causes lag.
* **Crashed Session Fix:** Checks `System.Console.IsInputRedirected`.
* **The Code (Preserved):**
    ```csharp
    // The Superior Check
    if (System.Console.IsInputRedirected)
    {
         return null; // Correctly signals "No Input Available" to the caller
    }
    ```

### C. The Granular Patch Strategy
We would lose the organizational clarity of splitting "Fixes" (required for survival) from "Instrumentation" (required for observation).
* **Insight:** "Fixes" should be applied via `git apply`. "Instrumentation" should be applied via the Agent reading the "Field Marks" manual.

---

## 3. If we kept the Crashed Session (Native)
**What would be lost from the Main Branch?**

### A. The "Sequencer" Instrument (Direct SQL Injection)
If we delete `instruments/sequencer/` to adopt the "Native Boot" method, we lose the capability to perform **Offline, High-Volume Data Injection**.
* **The Loss:** The `startup_commands.txt` method requires the server to be running and processes commands sequentially (slow). The `Sequencer` generated raw SQL that could be piped into SQLite instantly (fast).
* **Use Case for Resurrection:** If we ever need to generate a "Stress Test" world with 50,000 prims or 1,000 users, the `startup_commands` method will time out. The `Sequencer` method is instant.

### B. The Schema Knowledge (Hard-Coded Wisdom)
The `Sequencer` contained specific knowledge of the OpenSim 0.9.3 database schema (UserAccounts, Auth, Inventory). This is "Tribal Knowledge" that is otherwise hidden inside OpenSim DLLs.

#### **ARCHIVE: The Sequencer Fossil**
*Preserving the raw logic for offline user/prim generation.*

**1. User Generation Logic (The "Trinity" of Tables)**
To create a user *without* the server, you must hit three tables: `UserAccounts`, `auth`, and `inventoryfolders`.
```csharp
// 1. UserAccounts: The Identity
string serviceURLs = "HomeURI= InventoryServerURI= AssetServerURI=";
Console.WriteLine($"INSERT OR IGNORE INTO UserAccounts (PrincipalID, ScopeID, FirstName, LastName, Email, ServiceURLs, Created, UserLevel, UserFlags, active) VALUES ('{uuid}', '00000000-0000-0000-0000-000000000000', '{first}', '{last}', '{email}', '{serviceURLs}', {created}, 0, 0, 1);");

// 2. Auth: The Gatekeeper (MD5 Hash with Salt)
// Note: OpenSim uses specific hashing: MD5(MD5(password) + ":" + salt)
string salt = "12345678901234567890123456789012"; 
string md5Pass = ComputeMD5(pass);
string finalHash = ComputeMD5($"{md5Pass}:{salt}");
Console.WriteLine($"INSERT OR IGNORE INTO auth (UUID, passwordHash, passwordSalt, accountType) VALUES ('{uuid}', '{finalHash}', '{salt}', 'UserAccount');");

// 3. Inventory: The Root Folder (Required for login)
string rootFolderUUID = Guid.NewGuid().ToString();
Console.WriteLine($"INSERT OR IGNORE INTO inventoryfolders (folderID, agentID, parentFolderID, folderName, type, version) VALUES ('{rootFolderUUID}', '{uuid}', '00000000-0000-0000-0000-000000000000', 'My Inventory', 8, 1);");
```

**2. Prim Generation Logic (The "God Mode" Object)**
To rez an object offline (e.g., for a terrain seed):
```csharp
// The 'Texture' field is a raw byte blob. This hex string represents the default plywood texture.
string textureHex = "8955674724CB43ED920B47CAED15465F0000000000000000803F000000803F0000000000000000000000000000000000000000000000000000000000000000";

Console.WriteLine($"INSERT OR IGNORE INTO prims (UUID, RegionUUID, CreationDate, Name, SceneGroupID, CreatorID, OwnerID, GroupID, LastOwnerID, RezzerID, PositionX, PositionY, PositionZ, OwnerMask, NextOwnerMask, GroupMask, EveryoneMask, BaseMask) VALUES ('{primUUID}', '{region}', {created}, 'MimicBox', '{primUUID}', '{owner}', '{owner}', '00000000-0000-0000-0000-000000000000', '{owner}', '00000000-0000-0000-0000-000000000000', {posX}, {posY}, {posZ}, 2147483647, 2147483647, 0, 0, 2147483647);");

// OpenSim requires a matching shape entry
Console.WriteLine($"INSERT OR IGNORE INTO primshapes (UUID, Shape, ScaleX, ScaleY, ScaleZ, PCode, PathBegin, PathEnd, PathScaleX, PathScaleY, PathShearX, PathShearY, PathSkew, PathCurve, PathRadiusOffset, PathRevolutions, PathTaperX, PathTaperY, PathTwist, PathTwistBegin, ProfileBegin, ProfileEnd, ProfileCurve, ProfileHollow, State, Texture, ExtraParams) VALUES ('{primUUID}', 1, 0.5, 0.5, 0.5, 9, 0, 0, 100, 100, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, X'{textureHex}', X'');");
```

---

## 4. The Verdict (Merge Strategy)

1.  **Adopt Timeline B (Crashed)** for the active `main` branch. The `startup_commands.txt` and `IsInputRedirected` fixes are superior for the current "Naturalist" use case.
2.  **Delete `instruments/sequencer/`**, but **Commit this Journal**. This ensures that if we ever need the "Surgical" capability again, the exact SQL templates and hashing algorithms are preserved in the repository history, without carrying the dead code weight of the compiled tool.

