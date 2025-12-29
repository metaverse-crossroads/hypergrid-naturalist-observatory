# Visitant REPL Documentation

This document describes the commands available in the Visitant Read-Eval-Print Loop (REPL). The REPL is the primary interface for interacting with the client once it is running.

Commands are case-insensitive in Mimic (DeepSeaClient.cs), but implementation details may vary slightly in Benthic.

## Output Format

All REPL output is structured as NDJSON (Newline Delimited JSON) to facilitate machine parsing.

Format:
```json
{ "at": "ISO_TIMESTAMP", "via": "Visitant", "sys": "SYSTEM", "sig": "SIGNAL", "val": "PAYLOAD" }
```

## Commands

### `LOGIN [First] [Last] [Pass] [URI]`
*   **Description**: Initiates a login sequence if not already logged in or if re-logging is needed.
*   **Payload**: `First Last Pass URI` (Mimic specific arguments).
*   **Output**: Login success or failure log.

### `CHAT <message>`
*   **Description**: Sends a chat message to the local region.
*   **Output**: None (Chat echo is handled by incoming packets).

### `SLEEP <seconds>`
*   **Description**: Pauses execution for the specified number of seconds (non-blocking sleep in client thread context).
*   **Output**:
    ```json
    { "sys": "System", "sig": "Sleep", "val": "Slept X.Xs" }
    ```

### `WHOAMI`
*   **Description**: Reports the current agent's identity.
*   **Output**:
    ```json
    { "sys": "Self", "sig": "Identity", "val": "Name: First Last, UUID: ..." }
    ```

### `WHO`
*   **Description**: Lists encountered visitants (avatars) in the current simulator.
*   **Output**: One entry per avatar.
    ```json
    { "sys": "Sight", "sig": "Avatar", "val": "Name: ..., UUID: ..., LocalID: ..." }
    ```

### `WHERE`
*   **Description**: Reports current location metadata.
*   **Output**:
    ```json
    { "sys": "Navigation", "sig": "Location", "val": "Sim: ..., Pos: ..., Global: ..." }
    ```

### `WHEN`
*   **Description**: Reports the grid apparent time.
*   **Output**:
    ```json
    { "sys": "Chronology", "sig": "Time", "val": "GridTime: ISO_TIME" }
    ```

### `SUBJECTIVE_WHY`
*   **Description**: Emits the last assigned "BECAUSE" rationale.
*   **Output**:
    ```json
    { "sys": "Cognition", "sig": "Why", "val": "..." }
    ```

### `SUBJECTIVE_BECAUSE <text>`
*   **Description**: Stores a text describing a purpose or rationale. This is memoized and returned by `SUBJECTIVE_WHY`.
*   **Output**:
    ```json
    { "sys": "Cognition", "sig": "Because", "val": "Updated" }
    ```

### `SUBJECTIVE_LOOK`
*   **Description**: Emits details of what is observed (avatars, objects, etc.).
*   **Output**:
    ```json
    { "sys": "Sight", "sig": "Observation", "val": "Avatars: N, Primitives: M" }
    ```

### `SUBJECTIVE_GOTO <x>,<y>[,<z>]`
*   **Description**: Instructs the agent to move to the specified coordinates.
*   **Output**:
    ```json
    { "sys": "Action", "sig": "Move", "val": "Dest: x,y,z" }
    ```

### `POS <x>,<y>,<z>`
*   **Description**: Slams the absolute agent "global" position (Teleport).
*   **Output**:
    ```json
    { "sys": "Action", "sig": "Teleport", "val": "Dest: x,y,z" }
    ```

### `REZ`
*   **Description**: Creates a primitive object at the agent's location (plus offset).
*   **Output**: Log of the attempt.

### `LOGOUT`
*   **Description**: Logs out of the grid.
*   **Output**: Logout initiation log.

### `EXIT`
*   **Description**: Exits the client process.
*   **Output**: Exit log.
