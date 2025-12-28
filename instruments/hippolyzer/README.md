# Hippolyzer Instrument

## Overview
This instrument provides tools for packet-level inspection and manipulation of the OpenSim protocol (LibOMV) by injecting a proxy between the client (Visitant) and the simulator (Territory).

## Components

### 1. `observatory_proxy.py`
A custom Python script that acts as a "Dumb Proxy".
*   **TCP (Login)**: Intercepts HTTP login traffic. It rewrites the `SimPort` in the login response to point the client to the proxy's UDP port instead of the real simulator.
*   **UDP (Simulation)**: Wraps UDP packets in SOCKS5 headers and forwards them to `hippolyzer-cli`, which then relays them to the actual simulator.

### 2. `hippolyzer-cli`
The core Hippolyzer tool (from `pip install hippolyzer`). It runs as a background daemon listening on UDP/TCP ports (default 9061/9062) to dissect and log packets.

### 3. `Mimic` (Modified)
The `Mimic` instrument has been updated to accept a `--uri` (or `-s`) argument, allowing it to target the proxy's login URL (e.g., `http://127.0.0.1:9050/`) instead of the default `localhost:9000`.

## Architecture

```
[ Visitant (Mimic) ]
       |
       v
[ Observatory Proxy (TCP:9050 / UDP:9050) ]
       |
       +--- TCP Login ---> [ Hippolyzer HTTP Proxy (9062) ] ---> [ OpenSim HTTP (9000) ]
       |
       +--- UDP Sim   ---> [ Hippolyzer SOCKS Proxy (9061) ] ---> [ OpenSim UDP (9000) ]
```

## Setup & Usage

### Prerequisites
*   Python 3.12+
*   `pip install hippolyzer mitmproxy outleap`
*   OpenSim Core 0.9.3 (configured with REST console recommended for automation)
*   Mimic (built via `make mimic`)

### Execution Steps

1.  **Start OpenSim**:
    Ensure OpenSim is running and listening on port 9000.
    ```bash
    cd vivarium/opensim-core-0.9.3/bin && dotnet OpenSim.dll
    ```

2.  **Start Hippolyzer**:
    Start the packet analyzer daemon.
    ```bash
    hippolyzer-cli > hippolyzer.log 2>&1 &
    ```

3.  **Start Proxy**:
    Start the injection proxy.
    ```bash
    python3 instruments/hippolyzer/observatory_proxy.py > proxy.log 2>&1 &
    ```

4.  **Connect Visitant**:
    Connect Mimic through the proxy port (9050).
    ```bash
    dotnet vivarium/mimic/Mimic.dll -u Test -l User -p 1234 -s http://127.0.0.1:9050/
    ```

## Status & Known Issues
*   **Authentication Instability**: In the current test environment, establishing a stable baseline connection between `Mimic` and `OpenSim` (even without the proxy) has proven difficult due to "authentication failed" or "user not found" errors, possibly related to SQLite database locking or race conditions during initialization.
*   **Proxy Functionality**: The `observatory_proxy.py` script correctly binds ports and attempts to establish the SOCKS5 tunnel with Hippolyzer, but end-to-end packet logging could not be fully verified due to the upstream login failures.
