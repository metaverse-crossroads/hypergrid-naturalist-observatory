# Hippolyzer Client (Deep Sea Variant)

This species adapts the [Hippolyzer](../../instruments/hippolyzer/README.md) protocol analyzer into a standalone OpenSim client visitant (Deep Sea variant).

Hippolyzer is primarily a "man-in-the-middle" instrument for inspecting OpenSim traffic, but it exposes a client library that can be used to connect directly to simulators. This visitant leverages `hippolyzer.lib.client` to implement the standard Visitant protocols.

## Compliance

This client implements the **Deep Sea** visitant contract:
*   **Visitant CLI**: Supports standard arguments (`--firstname`, `--lastname`, `--password`, `--uri`).
*   **Visitant REPL**: Supports standard commands (`LOGIN`, `CHAT`, `WHOAMI`, `WHERE`, `LOGOUT`, `EXIT`, `SLEEP`) via stdin.
*   **NDJSON Logging**: Emits structured logs to stdout using the schema: `{"at": "ISO8601", "ua": "TAG_UA", "via": "Visitant", "sys": "...", "sig": "...", "val": "..."}`.

## Usage

### Auto-Login
By default, the client attempts to login as `Test User` to `http://127.0.0.1:9000/`.

```bash
./run_visitant.sh
```

### Custom Login
```bash
./run_visitant.sh --firstname Alice --lastname Wonderland --uri http://grid.example.com:8002/
```

### REPL Usage
You can interact with the client via standard input.

```bash
# Connect at runtime
LOGIN Bob Builder secret http://127.0.0.1:9000/

# Send chat
CHAT Hello World!

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
{"at": "2023-10-27T10:00:00.123456Z", "via": "Visitant", "sys": "System", "sig": "Status", "val": "Ready"}
{"at": "2023-10-27T10:00:01.000000Z", "via": "Visitant", "sys": "Network", "sig": "Login", "val": "Success"}
{"at": "2023-10-27T10:00:05.500000Z", "via": "Visitant", "sys": "Chat", "sig": "Heard", "val": "From: Test User, Msg: Hello"}
```

## Reference

*   [Visitant REPL Protocol](../../observatory/taxonomy/visitant-repl.md)
*   [Hippolyzer Instrument](../../instruments/hippolyzer/README.md)
