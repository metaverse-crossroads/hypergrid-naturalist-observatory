# The Timing Gearbox: Temporal Mechanics & Buffering
This document maps the mechanical timing constraints, asynchronous actors, and buffering thresholds of the 3-Room WebRTC Voice Architecture. It serves as the definitive diagnostic blueprint for diagnosing Overruns (Spaghettification), Underruns (Starvation), and Latency Drift.

## 1. The Input Drive (Network Ingest)
**The Asynchronous Push**
- **The Actor:** The Remote Viewer (Firestorm/LibreMetaverse), traversing the internet, terminating at SIPSorcery `OnRtpPacketReceived`.
- **The Cadence:** Asynchronous, bursty, and wholly unpredictable.
- **The Baseline Rate:** A healthy viewer transmits exactly 1000ms of Opus audio per 1000 real-world milliseconds (typically in 20ms UDP packets).
- **The Entropy (Sources of Slippage):**
- **Network Jitter:** Packets arrive in clumps or out of order.
- **Corrupted Payload:** RTCP, Forward Error Correction (FEC), and Retransmission (RTX) packets can masquerade as audio payloads. If naively decoded and padded with zeroes, they artificially *inflate*  the input rate > 1000ms/sec.
- **Silence Suppression:** When a user stops speaking, the Input Drive completely halts (0ms/sec).

## 2. The Reservoir (The Clutch / Tape)
**The Tension Regulator**
- **The Actor:** `AudioReservoir` (Room 2).
- **The Mechanics:** A thread-safe PCM queue that absorbs the mismatch between the Input Drive (Push) and the Engine Spindle (Pull).
- **The Ideal State:** Net-zero growth. Ingests 1000ms/sec; Dispenses 1000ms/sec.
- **Mechanical Failure Modes & Bulkheads:**
- **Underrun (The Snap):** When `Input Rate < Output Rate`. The tape runs dry.
- *The Bulkhead (The Spooler):*  The Reservoir must lock (`IsSpooling = true`) and dispense absolute silence until a minimum tension (e.g., 1000ms) is re-established.
- **Overrun (Spaghettification):** When `Input Rate > Output Rate`. Tape grows infinitely.
- *The Bulkhead (The Splicer):*  If tension exceeds a maximum threshold (e.g., 3000ms), the Reservoir must ruthlessly discard the oldest data to forcefully restore tension.

## 3. The Engine Spindle (The Clock)
**The Synchronous Pull**
- **The Actor:** `WebRTCVoiceEngine.ClockLoop` driving `MixingDesk.Tick()`.
- **The Cadence:** Synchronous, blocking, governed by the Operating System thread scheduler.
- **The Target Rate:** Designed to pull audio in fixed `Tick` increments (e.g., 100ms ticks, 10 times per second) equating to exactly 1000ms of audio extracted per real-world second.
- **The Entropy (Sources of Slippage):**
- **OS Scheduler Drift:** `Thread.Sleep(100)` is not a real-time guarantee. The OS may sleep for 115ms due to CPU load.
- **Garbage Collection Pauses:** C# GC can freeze the thread for anywhere from 5ms to 500ms.
- **The Relative Timer Trap:** If the loop uses a relative timer (measuring elapsed time *per loop*  and sleeping the difference), any OS drift permanently erases ticks. (e.g., ticking only 8 times a second extracts only 800ms of tape, guaranteeing Overrun/Spaghettification in the Reservoir).

## 4. The Output Drive (Network Dispatch)
**The WebRTC Payload Restrictor**
- **The Actor:** `MixingDesk` Opus Encoder -> SIPSorcery `SendAudio()`.
- **The Constraint (`ptime`):** WebRTC negotiates a specific packet timing (usually `ptime=20`, or 20ms audio frames) during the SDP handshake.
- **The Gear Mismatch:** The Engine Spindle pulls large chunks (e.g., 100ms) to optimize CPU/Mixing overhead. However, the Output Drive *must*  dispatch in sizes compliant with the Viewer's jitter buffer (e.g., 20ms).
- **The Entropy (Sources of Slippage):**
- If a 100ms PCM chunk is encoded as a single Opus frame and dispatched, the Viewer may reject it as an MTU violation or a timestamp collision. The Output Drive must act as a fragmentation gear, slicing the large Spindle tick into network-compliant chunks before transmission.

## The Diagnostic Matrix
When telemetry indicates a failure, cross-reference the symptoms against these spheres of influence:
Symptom
Primary Suspect
Investigation Vector
**Endless Overruns** (Tape keeps hitting 3000ms and slicing)
**Engine Spindle** vs **Input Drive**
1. Is the Engine ticking exactly 10x per second? (Accumulator failure).  2. Is the Bouncer passing corrupted RTX/FEC packets that get decoded into fake silence? (Ingest inflation).
**Endless Underruns** (Tape constantly drops to 0 and locks)
**Input Drive**
Is the network dropping massive amounts of packets? Is the remote viewer capturing audio slower than 1000ms/sec?
**Viewer Hears Silence** (But Tape tension is perfect)
**Output Drive**
Is the encoded chunk size violating the viewer's `ptime` or MTU expectations?
**Nextel Chirp Fails**
**Input Drive** / **Reservoir**
Is the PowerLevel failing to decay to 0 because corrupt packets are keeping the tape "alive" even when the user releases PTT?