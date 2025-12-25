# OpenSim REST Console Driver

This directory contains the necessary components to drive the OpenSim console via its REST interface, providing a reliable, synchronous abstraction over the native asynchronous polling mechanism.

## Components

*   `console_daemon.py`: A Python daemon that maintains a persistent session with the OpenSim REST console. It handles the polling loop, XML parsing, and command echo correlation.
*   `connect_opensim_console_session.sh`: A wrapper script that launches the daemon. It allows for environment-based configuration and serves as a standard entry point.

## Integration

The `Director` harness integrates this driver to control OpenSim instances when `console = "rest"` is specified in the configuration.

### Configuration

To enable the REST console in OpenSim, the following INI settings are required (handled automatically by `Director` when in REST mode):

```ini
[Startup]
    console = "rest"

[Network]
    ConsoleUser = "RestUser"
    ConsolePass = "RestPassword"
```

### Usage (Manual)

You can manually connect to a running OpenSim instance (configured for REST) using the wrapper script:

```bash
export OPENSIM_URL="http://127.0.0.1:9000"
export OPENSIM_USER="RestUser"
export OPENSIM_PASS="RestPassword"
./connect_opensim_console_session.sh
```

### Usage (Scenario-aware)

When running within the Observatory, the script can automatically configure itself using the scenario's synopsis:

```bash
./connect_opensim_console_session.sh --scenario standard
```

This will attempt to read `vivarium/encounter.standard.synopsis.json` to obtain the URL and credentials.

Type commands into standard input. Responses will be emitted as NDJSON lines to standard output.
