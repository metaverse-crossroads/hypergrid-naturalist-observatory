# Spike Report: OpenSim REST Console Investigation

**Date:** December 2025
**Status:** Success (Abstraction Layer Verified)

## 1. Objective
Investigate whether the OpenSim REST Console (`console = rest`) can provide a reliable, synchronous REPL interface for controlling OpenSim instances, replacing the current subprocess stdio/log-tailing strategy.

## 2. Findings

### 2.1. Underlying Architecture: Asynchronous Polling
The native REST interface is **asynchronous** and polling-based, not synchronous RPC:
1.  **StartSession:** POST to `/StartSession/`. Returns XML with `SessionID` and initial `HelpTree`.
2.  **SendCommand:** POST to `/SessionCommand/`. Returns `<Result>OK</Result>` (queued), **not** the output.
3.  **ReadOutput:** Client must poll `/ReadResponses/<SessionID>` to retrieve console scrollback lines as structured XML.

### 2.2. The Solution: Synchronous Abstraction Layer
We successfully implemented a synchronous abstraction layer (`connect_opensim_console_session.sh` wrapping `console_daemon.py`) that bridges the gap.

**Architecture:**
*   **Daemon:** A Python process maintains the session and polling loop.
*   **Correlation:** It sends a command and polls until it sees the command "echoed" back by the server (Input=true), then captures all subsequent output lines until the prompt returns.
*   **Interface:** It reads commands from STDIN and emits 1:1 correlated NDJSON responses to STDOUT.

**Example Interaction:**
*Input (STDIN):*
```text
show users
```
*Output (STDOUT):*
```json
{"command": "show users", "response": "\nRoot agents in region Default Region: 0 (root 0, child 0)\n", "status": "OK"}
```

## 3. Recommendation

**Adopt the Abstraction Layer.**

### Rationale:
1.  **Robustness:** The `console_daemon.py` handles the complexities of polling, XML parsing, and session management, isolating `director.py` from the fragility observed in raw REST calls.
2.  **Clean Interface:** The NDJSON output allows for precise verification of command results without log tailing race conditions.
3.  **Future-Proofing:** This "external executable" pattern allows `director.py` to support other console types (e.g., Telnet, SSH) by simply swapping the connector script, keeping the core logic focused on scenario orchestration.

## 4. Artifacts
*   `vivarium/skunkworks/opensim_console/console_daemon.py`: The Python abstraction logic.
*   `vivarium/skunkworks/opensim_console/connect_opensim_console_session.sh`: The standard entry point.
*   `vivarium/skunkworks/opensim_console/rest_console.ini`: Configuration fragment.
