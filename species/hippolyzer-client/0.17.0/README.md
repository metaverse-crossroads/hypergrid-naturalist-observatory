# Hippolyzer Client (Deep Sea Variant)

This species adapts the [Hippolyzer](../../instruments/hippolyzer/README.md) protocol analyzer into a standalone OpenSim client visitant (Deep Sea variant).

Hippolyzer is primarily a "man-in-the-middle" instrument for inspecting OpenSim traffic, but it exposes a client library that can be used to connect directly to simulators. This visitant leverages `hippolyzer.lib.client` to implement the standard Visitant protocols.

## Compliance

This client implements the **Deep Sea** visitant contract:
*   **Visitant CLI**: Supports standard arguments (`--firstname`, `--lastname`, `--password`, `--uri`).
*   **Visitant REPL**: Supports standard commands (`LOGIN`, `CHAT`, `WHOAMI`, `WHERE`, `LOGOUT`, `EXIT`, `SLEEP`) via stdin.
*   **NDJSON Logging**: Emits structured logs to stdout using the schema: `{"at": "ISO8601", "ua": "TAG_UA", "via": "Visitant", "sys": "...", "sig": "...", "val": "..."}`.

## Usage

### Interactive Mode (REPL)
Run without arguments to start the interactive shell. You can then log in manually.

```bash
./run_visitant.sh
```

### Auto-Login
To auto-login on startup, you must provide **all** credentials (`firstname`, `lastname`, and `password`).

```bash
./run_visitant.sh --firstname Alice --lastname Wonderland --password secret
```

If any credential is missing, the client will start in REPL mode without logging in.

### REPL Usage
You can interact with the client via standard input.

```bash
# Connect at runtime
LOGIN Bob Builder secret http://127.0.0.1:9000/

# Send chat
CHAT Hello World!

# Send Instant Message (by UUID)
IM_UUID <TargetUUID> <Message>

# Query location
WHERE

# Sleep
SLEEP 5.0

# Disconnect
LOGOUT

# Quit
EXIT
```

## Logging

All significant events (network, chat, errors) are logged to **stdout** in NDJSON format.
Debug and Error logs from the application itself are directed to **stderr**.

Example Output:
```json
{"at": "2023-10-27T10:00:00.123456Z", "via": "Visitant", "sys": "STATE", "sig": "STATUS", "val": "Ready"}
{"at": "2023-10-27T10:00:01.000000Z", "via": "Visitant", "sys": "MIGRATION", "sig": "ENTRY", "val": "Success"}
{"at": "2023-10-27T10:00:05.500000Z", "via": "Visitant", "sys": "SENSORY", "sig": "AUDITION", "val": "From: Test User, Msg: Hello"}
```

## Implementation Notes

*   **Packet Construction**: When manually constructing packets (e.g., `ImprovedInstantMessage`), vector fields (like `Position`) must be passed as a `list` of values (e.g., `[0.0, 0.0, 0.0]`), NOT as packed bytes (`struct.pack`), or the underlying `struct` usage in `data_packer` will fail.
*   **Session Access**: The `HippoClient` object wraps the session logic. Accessing `agent_id` or `session_id` should be done via `self.client.session.agent_id` (and verifying `self.client.session` is not None).

## Reference

*   [Visitant REPL Protocol](../../observatory/taxonomy/visitant-repl.md)
*   [Hippolyzer Instrument](../../instruments/hippolyzer/README.md)
