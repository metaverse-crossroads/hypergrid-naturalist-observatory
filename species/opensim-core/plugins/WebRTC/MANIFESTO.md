# OpenSim WebRTC Voice Blueprint:<br/> The "Talk Radio" Architecture

## 1. The Core Mandate

This architecture is designed to graft WebRTC spatial voice onto the OpenSim hypergrid. It explicitly rejects "enterprise cargo-culting," speculative optimizations, and the pursuit of low-latency bare-metal performance in a non-RTOS C# environment.


**The Prime Directives:**
- **Evidence Over Inference:** We build only to the *de facto*  behaviors verifiable in the SLOS C++ Viewer and LibreMetaverse C# Client reference code.
- **Eradicate Guesswork (Observability):** We do not trust our ears as the evolutionary measure of correctness. The system must mathematically prove its health via internal telemetry and consider the human ear the foremost yet the final QA layer.
- **The Telemetry Gate (No Premature Physical Testing):** Under no circumstances is the system's efficacy to be judged by listening to audio hardware until the internal telemetry explicitly proves that 1) Packets are surviving the Bouncer, 2) The Tape Delay is physically enforcing its buffer depth, and 3) The Mixing Desk is actively generating Non-Zero RMS math.
- **Scream, Don't Hide:** We do not silently swallow edge cases or undocumented viewer behaviors (e.g., RTP packets arriving before Data Channel Join). We fail loudly and spam the observable logs so the system documents the *actual*  protocol for us.
- **Working Hypotheses (Pending Verification):** Where the implicit specification is fuzzy, we explicitly declare our assumptions. For example, we operate under the tentative assumption that a viewer only ever contributes its microphone to a single "elected" channel at a time, simplifying upstream routing expectations.
 - **Modern Metal (C# 10+):** We explicitly assume a modern C# compiler, aggressively utilizing netstandard2.0-framework compatible features like target-typed `new()`, pattern matching, and minimal allocations to keep the execution overhead microscopic. We aim for hacker-centric, highly cohesive C# that favors readability and performance over enterprise boilerplate.

## 2. The 3-Room Separation of Concerns

To protect our logic from the OpenSim framework and survive the complexities of Parcel vs. Region routing, the system is strictly divided into three optically decoupled "Rooms."

### Room 1: The Switchboard (Signaling & Transport)
- **Responsibility:** Handle the messy, asynchronous `ProvisionVoiceAccountRequest` (CAPS) and WebRTC ICE trickling. Terminates DTLS/SRTP.
- **Output:** Raw, decrypted Opus frames handed to Room 2. Raw JSON strings handed to Room 3 (via the Ledger).
- **Health Assessment (Early Aborts & Edge Diagnostics):** Sitting at the raw network edge, Room 1 acts as the bouncer. It enforces "No-Show" aborts (killing sessions if DTLS/ICE times out) and "Rogue Streamer" aborts (dropping RTP payloads that arrive before a Data Channel `{"j": {"p": true}}` join). It also passively monitors RTCP Receiver Reports to prove downstream network health independent of grid performance.

### Room 2: The Tape Room (Ingest & Spooling)
- **Responsibility:** Decode Opus to PCM. Calculate RMS volume to feed Data Channel `p` (Power) and `v` (Voice Active) state.
- **The Reservoir:** All incoming PCM audio is deposited into a deep, thread-safe Ring Buffer ("The Tape").
- **Output:** Clean, uniform buffers of PCM audio, completely detached from network jitter.
- **Health Assessment (Dimensions of Uniformity):** "Clean" ingest is mathematically enforced across two dimensions. **Temporal Uniformity:** The reservoir absorbs chaotic network jitter and yields perfectly rhythmic blocks of audio to the Mixing Desk, padding the end with absolute silence (zeroes) in the event of an underrun. **Format Uniformity:** All incoming streams, regardless of client quirks, are normalized to a strict internal PCM standard (e.g., 48kHz Mono) before spooling.

### Room 3: The Mixing Desk (BYOSM - Bring Your Own Spatial Mixing)
- **Responsibility:** A decoupled clock loop that pulls from the Tape Room Reservoirs and generates bespoke outgoing audio.
- **Localized N-1 Mixing (Mix-Minus):** Every participant connected to this specific region/island receives a unique mix containing all *other*  active speakers on this region, explicitly minus their own voice to prevent echo.
- **Viewer-Side Summing:** The server does not route audio between regions. The viewer establishes connections to multiple regions (if in earshot) and sums their respective N-1 mixes locally in its own audio engine.
- **Output:** PCM encoded back to Opus and dispatched down the respective WebRTC pipes.
- **Health Assessment (Dispatch Certainty):** We establish certainty that our audio reaches the downstream ear through two distinct proxies. First, RTCP Receiver Reports confirm network-level packet arrival. Second, the "Ear-in-the-Loop" UI verification (the Nextel ACK/NAK system detailed below) confirms the viewer's audio engine successfully rendered the stream to human headphones.

## 3. The "Nextel" Latency & Diagnostics Protocol

To survive the thread-starvation and GC-pauses inherent to C#, we intentionally abandon 20ms real-time latency in favor of a massive, un-starvable buffer.
- **The Tape Delay:** Room 3 pulls from Room 2's Reservoirs with an intentional 1000ms - 3000ms delay. We trade immediacy for buttery-smooth, stutter-free playback.
- **The "ACK" (Chirp) & "NAK" (Dead Key):** Room 2 continuously calculates the RMS (Root Mean Square volume) of the incoming PCM. When a user releases Push-To-Talk (Data Channel `v` transitions `true` -> `false`), Room 3 evaluates the recent RMS.
- If speech was detected, it injects a cheerful 100ms 800Hz sine wave (ACK) into their specific N-1 return buffer, mathematically proving their upstream is functional.
- If the RMS remained near zero, it injects a subtle, dull radio click (a "NAK" or "Dead Key"), instantly informing the user that while the grid heard their button press, their hardware microphone is muted or dead.
- **Look-Ahead VAD (The Latency Advantage):** Rather than strictly punishing open-mic users (e.g., cutting them off after 10 seconds), the Tape Delay is weaponized as a luxury Server-Side Voice Activity Detection (VAD) feature. Because Room 3 operates 1000ms in the past, it looks *forward*  into a user's tape. If the upcoming RMS represents background noise or keyboard clacking, it dynamically gates (mutes) them. The millisecond the future RMS spikes with actual speech, Room 3 fades them back in precisely on time, picking up the slack for relaxed PTT habits.

## 4. Identity: The Hierarchical Ledger (The Pocket Universe)

WebRTC sessions (`SessionID`) are transient and overlap during sim-crossings. To prevent corrupted or "ghost" connections, state is keyed hierarchically.

### The Master Key: `AgentID` (The Human)
- Holds the "Expando Stash" (Blindly unioned Data Channel telemetry like `sp`, `sh`, `m`, `ug`—stashed without complex parsing for future Phase 2 spatialization).
- Holds global telemetry (Consecutive Underruns, Drift Milliseconds, Rogue Frames Received).

### The Transient Sub-Keys: `SessionID` (The Pipes)
- Belongs to an `AgentID`.
- **The "Elected Channel" Rule:** We do not track "Primary" or "Secondary" states server-side. We simply assume a viewer only transmits microphone audio to the one connection it has currently *elected*  to speak into.
- If a session is receiving RTP payloads but hasn't properly signaled its intentions (or violates our elected channel hypothesis), we log the anomaly loudly and are free to drop the packets.
- Regardless of whether a session is the *elected*  microphone contributor, Room 3 provides an outbound N-1 mix to every connected session so the user can hear the surrounding region.

## 5. Implementation Roadmap

- **Phase 1 (The Dumb Mixer):** Implement the 3 Rooms. Flat N-1 audio per region. Nextel Tape Delay. Basic Data Channel `p` and `v` loopback. Health Assessment logging.
- **Phase 2 (The BYOSM Interface):** Refine Room 3 to accept plugin spatializers (e.g., C# wrappers around High Fidelity/Resonance Audio), utilizing the `sp`/`sh` data stored in the Expando Stash.
- **Phase 3 (Routing & Rules):** Implement `ug` (User Gain), `m` (Mute) math, Look-Ahead VAD, and Dead Key generation in Room 3.

