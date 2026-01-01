# Director Literate Markdown Protocol

The Director interprets Markdown files as "Teleplays" (Scenarios), executing embedded code blocks to orchestrate simulations within the Naturalist Observatory.

## General Structure

A Scenario is a Markdown file with YAML Frontmatter. The Director parses the file, resolving `[#include](path)` directives, and then executes code blocks sequentially.

```markdown
---
Title: My Scenario
---

# My Scenario

Description of the scenario.

```block-type arguments
block content
```
```

## Block Types

### `bash`
Executes a bash script in the repository root.

```bash
echo "Hello from Bash"
mkdir -p my/dir
```

### `bash-export`
Executes a bash script and captures exported environment variables for subsequent blocks.

```bash-export
export MY_VAR="some value"
```

### `cast`
Casts actors (Visitants) by creating User Accounts in the Simulator.
Takes a JSON list of actor objects.

```cast
[
    {
        "First": "Test",
        "Last": "User",
        "Password": "password",
        "UUID": "11111111-1111-1111-1111-111111111111",
        "Species": "mimic"
    }
]
```

### `legacy-cast`
Same as `cast`, but uses the legacy `sequencer` tool to inject SQL directly into databases. Used for specific offline setups.

### `territory` (or `opensim`)
Interacts with the OpenSim simulator process.
If OpenSim is not running, it starts it.
Lines are sent as console commands.

```territory
# Start Simulator
alert Hello World
```

Special commands:
- `WAIT <ms>`: Sleeps for N milliseconds.
- `WAIT_FOR_EXIT`: Blocks until the OpenSim process exits.
- `QUIT`: Gracefully terminates OpenSim.

### `mimic` (or `actor`)
Interacts with a Visitant (Actor) process.
The argument specifies the actor's name (First Last).

```actor Test User
LOGIN Test User password
CHAT Hello World
LOGOUT
```

Commands depend on the specific Visitant implementation (e.g., Mimic REPL). See [Visitant REPL](taxonomy/visitant-repl.md).

### `verify`
Verifies the state of the simulation by searching log files.
If the pattern is found, the step passes. If not, the scenario fails.

```verify
Title: Check Login
Subject: Territory
Contains: Test User logged in
```

Keys:
- `Title`: Descriptive title.
- `Subject`: `Territory`, `Simulant`, or Actor Name. Maps to the appropriate log file.
- `File`: Explicit file path (overrides Subject).
- `Contains`: The string pattern to search for.
- `Frame`: (Optional) Analysis frame.

### `await`
Blocking verification. Waits (polls) for a pattern to appear in the log within a timeout.

```await
Title: Wait for Login
Subject: Territory
Contains: Test User logged in
Timeout: 10000
```

Keys: Same as `verify`, plus `Timeout` (ms).

### `wait`
Pauses execution for N milliseconds.

```wait
5000
```

### `async-sensor`
Registers a background monitor that watches a log file for a specific pattern. When triggered, it performs an action.

```async-sensor
Title: Abort Trigger
Subject: Territory
Contains: END SIMULATION
director#abort: Simulation ended by trigger.
```

Keys:
- `Title`: Descriptive title.
- `Subject`: `Territory` or Actor Name.
- `Contains`: The pattern to watch for.
- Action (One of):
    - `director#abort: <message>`: Aborts the scenario immediately.
    - `director#alert: <message>`: Sends an `alert` command to the Simulator console.
    - `director#log: <message>`: Logs a message to the Director's evidence log.

## Scenarios including Tests

The following scenarios serve as key references and test suites for the Director's capabilities:

- **[Standard Encounter](scenarios/standard.md)**: The baseline verification scenario. Demonstrates casting, login, chat, and basic verification.
- **[Test Async Sensors (Abort)](scenarios/test/async_test.md)**: Verifies the `director#abort` functionality of async sensors.
- **[Test Async Sensors (Alert)](scenarios/test/async_alert_test.md)**: Verifies the `director#alert` functionality of async sensors.
- **[Human Visitant Teleplay](scenarios/human_visitant_teleplay.md)**: An interactive scenario designed for human participation, demonstrating the usage of sensors to react to human chat commands ("ping", "goodbye!").
