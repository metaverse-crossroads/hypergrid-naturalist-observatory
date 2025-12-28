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
*   OpenSim Core 0.9.3
*   Mimic (built via `make mimic`)

**Note:** For headless testing of OpenSim 0.9.3, the `CommandConsole.patch` must be applied to prevent CPU spinning when `stdin` is closed/redirected.

### Execution Steps

1.  **Start Hippolyzer**:
    Start the packet analyzer daemon first to bind ports 9061/9062.
    ```bash
    hippolyzer-cli > hippolyzer.log 2>&1 &
    # Wait ~5s for startup
    ```

2.  **Start Proxy**:
    Start the injection proxy to bind port 9050 and connect to Hippolyzer.
    ```bash
    python3 instruments/hippolyzer/observatory_proxy.py > proxy.log 2>&1 &
    # Wait ~5s for startup
    ```

3.  **Start OpenSim**:
    Ensure OpenSim is running and listening on port 9000.
    ```bash
    # Using the Observatory boot script
    observatory/boot_opensim_core.sh > opensim.log 2>&1 &
    ```

4.  **Connect Visitant**:
    Connect Mimic through the proxy port (9050).
    ```bash
    make run-mimic -- --firstname Test --lastname User --password password --uri http://127.0.0.1:9050/
    ```

## Status & Findings (Dec 2025)

### Status: Partial Success (TCP/UDP Injection Works, Session Tracking Fails)
We have successfully established the infrastructure for packet interception, but full end-to-end login verification via `Mimic` fails due to an internal session tracking issue in `hippolyzer`.

### Verified Working Components
1.  **TCP Injection**: The `observatory_proxy.py` correctly intercepts the Login Request, rewrites the `Host` header (to satisfy Hippolyzer), strips `Accept-Encoding` (to prevent gzip), and rewrites the Login Response `SimPort` (from 9000 to 9050).
2.  **UDP Association**: The Proxy successfully establishes a SOCKS5 UDP tunnel with Hippolyzer and buffers initial packets to prevent race conditions.
3.  **Traffic Flow**:
    *   **Client -> Proxy**: Client successfully connects to Proxy (TCP) and sends UDP packets to the Proxy (UDP).
    *   **Proxy -> Hippolyzer**: Traffic is forwarded via SOCKS5.
    *   **Hippolyzer -> OpenSim**: OpenSim logs reception of `StartPingCheck` packets from the proxy chain.
    *   **OpenSim -> Client**: Login Response is successfully returned and parsed by the client.

### Failure Mode
The login process hangs at "Connecting to simulator...".
*   **Symptom**: OpenSim logs "Received unexpected message StartPingCheck ... before circuit open".
*   **Cause**: The critical `UseCircuitCode` packet (Packet ID 1) is either dropped or rejected by Hippolyzer.
*   **Root Cause**: `hippolyzer.log` reports `Wasn't able to claim session UUID(...)`. This indicates that Hippolyzer failed to extract the Session ID from the intercepted Login HTTP transaction. Because it doesn't recognize the session, it likely drops the `UseCircuitCode` packet (which establishes the circuit), causing OpenSim to reject subsequent packets.

### Fixes Applied to Proxy
*   **Packet Queueing**: Implemented a packet queue in `observatory_proxy.py` to buffer UDP packets (like `UseCircuitCode`) that arrive before the SOCKS tunnel is fully established.
*   **0.0.0.0 Binding**: Changed listen host to `0.0.0.0` to handle cases where OpenSim redirects the client to a LAN IP (e.g., `192.168.x.x`) instead of localhost.
*   **Header Normalization**: Added logic to rewrite the `Host` header to `127.0.0.1:9000` and remove `Accept-Encoding` to ensure compatible inspection.

### Next Steps
Investigation should focus on why `hippolyzer-cli` fails to parse the Session ID from the Login Response, despite the traffic flowing through its HTTP proxy. This may require debugging `hippolyzer.lib.packet.processor`.
