# OpenSim NGC (Tranquillity)

**Version:** 0.9.3 (Tranquillity Branch)
**Biome:** Deep Sea (Linux/.NET 8 Console)

## Overview
This variant tracks the `OpenSim-NGC/OpenSim-Tranquillity` repository. It is a modernized fork of OpenSim targeting .NET 6/8.

## Known Issues

### 1. SQLite Support Eroded
The SQLite database schema migrations in this repository are significantly outdated compared to the MySQL migrations and the C# code expectations.

*   **MySQL Migrations:** Up to Version 7 (includes `DisplayName`, `NameChanged`).
*   **SQLite Migrations:** Stalled at Version 3 (missing columns).
*   **Symptoms:** Crash with `System.Data.SQLite.SQLiteException: table UserAccounts has no column named DisplayName`.

**Workaround:**
The `incubate.sh` script automatically configures `OpenSim.ini` (via `ngc_fixes.ini` injection in scenarios) to use `OpenSim.Data.Null.dll` (Null Storage) for the `UserAccountService`. This allows the simulator to boot and function in-memory, but **user accounts are not persisted** between restarts.

### 2. Missing Native Libraries
The repository does not include pre-compiled native libraries for `ubODE` or `System.Data.SQLite` for Linux.
*   **Workaround:** `incubate.sh` symlinks the system `libsqlite3.so` and forces `physics = basicphysics` configuration.

### 3. Log4Net Configuration
The build process produces `OpenSim.dll.config` but the application expects `OpenSim.exe.config` for log4net initialization.
*   **Workaround:** `incubate.sh` copies the config file.
