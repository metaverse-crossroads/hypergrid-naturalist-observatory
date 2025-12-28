# OpenSim NGC (Tranquillity)

**Version:** 0.9.3 (Tranquillity Branch)
**Biome:** Deep Sea (Linux/.NET 8 Console)

## Overview
This variant tracks the `OpenSim-NGC/OpenSim-Tranquillity` repository. It is a modernized fork of OpenSim targeting .NET 6/8.

## Operational Architecture: Hybrid Storage
This variant utilizes a **Hybrid Null/SQLite** storage architecture to resolve incomplete implementations in both drivers.

### 1. Null Driver Services (In-Memory)
The following services are configured to use `OpenSim.Data.Null.dll` to avoid broken SQLite migrations or to provide transient sandbox state:
*   **UserAccountService**: Required due to eroded SQLite support (missing `DisplayName` columns).
*   **AuthenticationService**: Kept consistent with UserAccounts.
*   **AvatarService**: Kept consistent with UserAccounts.
*   **FriendsService**: Kept consistent with UserAccounts.
*   **PresenceService**: In-memory session tracking.

### 2. SQLite Driver Services (Persisted)
The following services **must** use `OpenSim.Data.SQLite.dll` because `OpenSim.Data.Null.dll` lacks the required interface implementations (missing source files):
*   **GridUserService**: `NullGridUserData.cs` is missing in this version.
*   **InventoryService (XInventory)**: `NullXInventoryData` is missing (only legacy `NullInventoryData` exists).
*   **AssetService**: Persists assets to `Asset.db`.
*   **GridService**: Persists regions to `OpenSim.db`.

## Critical Patches
To ensure a stable boot in this Hybrid environment, the following patches are applied by `incubate.sh`:

1.  **CommandConsole.patch**:
    *   **Issue:** In headless environments (e.g., CI/CD, background scripts) where `stdin` is closed, `Console.ReadLine()` returns `null`. This causes `CommandConsole.cs` to crash with a `NullReferenceException` or enter a 100% CPU spin loop.
    *   **Fix:** The patch detects `null` input, sleeps for 5000ms, and returns an empty string, keeping the process alive and responsive to other threads.

2.  **MigrationFixes.patch**:
    *   **Issue:** The SQLite migration scripts (`.migrations`) for `XInventoryStore` and `AgentPrefs` contain logic to import data from legacy tables (`old.inventoryfolders`) or duplicate table creation logic that fails on fresh installations (`SQL logic error: no such table`).
    *   **Fix:** The patch comments out legacy import logic and redundant `CREATE TABLE` statements, ensuring a clean, error-free boot for fresh databases.

## Known Issues & Zigzag Avoidance

### 1. "Pure Null" is Impossible
Do not attempt to force `GridUserService` or `InventoryService` to use `OpenSim.Data.Null.dll`. The driver classes do not exist in this branch, and the service will crash on startup with `Could not find a storage interface`.

### 2. "Pure SQLite" is Broken
Do not attempt to use SQLite for `UserAccountService`. The schema migrations are stalled at version 3, while the C# code expects version 7 columns (`DisplayName`), causing unavoidable crashes.

### 3. Native Libraries
The repository lacks pre-compiled native libraries for `ubODE` or `System.Data.SQLite` on Linux. `incubate.sh` handles this by symlinking system libraries (`libsqlite3.so`) and forcing `physics = basicphysics`.
