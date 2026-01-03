# HYPERGRID NATURALIST OBSERVATORY: FIELD GUIDE TO SIGNAL INSTRUMENTATION
# =======================================================================
# A reference for instrumenting distributed agents (Visitants) and
# habitats (Territory) with diegetic consistency.

## 1. THE PHILOSOPHY: SOURCE HYGIENE
In a distributed simulation, "Truth" is relative. A log entry is not an absolute record of reality; it is a testament from a specific observer.

To make sense of multi-agent interactions without a "God View" translator, we must practice **Diegetic Logging**.

* **Rule 1: Subjectivity.** Log events as they are experienced by the entity, not as they are defined by the protocol.
* **Rule 2: Causality.** Distinguish between the *cause* (Motor), the *medium* (Signal), and the *effect* (Sensory).
* **Rule 3: Biological Metaphor.** Use faculties (Senses, Voice, Reflex) rather than technical implementation details (Packets, Sockets, Handlers).

---

## 2. THE TAXONOMY OF FACULTIES (SYS/SIG)

When instrumenting code, map the internal technical event to one of these biological faculties.

### A. The Subjective Frame (Visitants)
These signals are emitted by the agents themselves (Benthic, Hippo, Mimic).

| SYS (Faculty) | SIG (Behavior)       | Definition                                                                 |
| :---          | :---                 | :---                                                                       |
| **MOTOR** | `VOCALIZATION`       | The exertion of will to speak. (e.g., Typing into chat).                   |
| **MOTOR** | `LOCOMOTION`         | The exertion of will to move. (e.g., Sending a movement vector).           |
| **SENSORY** | `AUDITION`           | The perception of sound/text. (e.g., Receiving a chat packet).             |
| **SENSORY** | `VISION`             | The perception of objects/avatars. (e.g., Receiving an ObjectUpdate).      |
| **SENSORY** | `TREMOR`             | Perception of environmental shifts. (e.g., Land/Region updates).           |
| **STATE** | `IDENTITY`           | Internal realization of self (e.g., "I know my Name is X").                |
| **MIGRATION** | `HANDSHAKE`          | Negotiating entry into a new region.                                       |

### B. The Environmental Frame (Territory/OpenSim)
These signals are emitted by the habitat/server.

| SYS (Faculty) | SIG (Behavior)       | Definition                                                                 |
| :---          | :---                 | :---                                                                       |
| **TERRITORY** | `SIGNAL`             | The authoritative relay of an event. (e.g., Server broadcasting chat).     |
| **TERRITORY** | `PHYSICS`            | Low-level infrastructure reality. (e.g., Wire dialect, socket closure).    |
| **RANGER** | `INTERVENTION`       | Administrative actions taken by the system (e.g., Kicking a user).         |

---

## 3. SOLVING "FRAME OF REFERENCE" CONFUSION

The most critical distinction for the Director (and the LLM writing Scenarios) is separating **Motor** from **Sensory**.

### The Inverted Loop (How to verify communication)
If Actor A wants to tell Actor B something, the log flow looks like this:

1.  **Actor A (Motor):** "I *attempted* to say 'Hello'."
    * *Log:* `sys: MOTOR`, `sig: VOCALIZATION`, `val: "Hello"`
    * *Status:* Unconfirmed. The wire might be cut.

2.  **Territory (Signal):** "I *received* a request from A and *relayed* it."
    * *Log:* `sys: TERRITORY`, `sig: SIGNAL`, `val: "Chat: Hello"`
    * *Status:* In Transit.

3.  **Actor A (Sensory):** "I *heard* myself say 'Hello'." (The Echo)
    * *Log:* `sys: SENSORY`, `sig: AUDITION`, `val: "Source: Me, Msg: Hello"`
    * *Status:* Confirmed Transmission (Loopback).

4.  **Actor B (Sensory):** "I *heard* A say 'Hello'."
    * *Log:* `sys: SENSORY`, `sig: AUDITION`, `val: "Source: A, Msg: Hello"`
    * *Status:* Confirmed Reception.

**Common Pitfall:**
* *Bad Teleplay:* Awaiting Actor A's `MOTOR` event to prove Actor B heard it.
* *Good Teleplay:* Awaiting Actor B's `SENSORY` event to prove Actor B heard it.

---

## 4. AUTHORING LITERATE SCENARIOS (TELEPLAYS)

When writing `await` blocks in Markdown Scenarios, choose your **Subject** and **Contains** pattern carefully based on the Frame of Reference.

### Example 1: Verifying a Visitant Can Speak
Don't just check if they typed it. Check if the world heard it.

```yaml
# BAD: Only checks if the bot tried to type.
await:
  Subject: Benthic Visitant
  Contains: "sys": "MOTOR"

# GOOD: Checks if the bot heard its own echo (Server confirmed receipt).
await:
  Subject: Benthic Visitant
  Contains: "sys": "SENSORY", "sig": "AUDITION"
```

### Example 2: Verifying Cross-Species Communication
Director instructs Hippo to speak. We verify Libre heard it.

```yaml
# Step 1: The Instruction (Director -> Hippo)
actor: Hippo Visitant
command: CHAT Hello Libre!

# Step 2: The Proof (Libre's Ears)
await:
  Title: Libre Hears Hippo
  Subject: Libre Visitant
  # We look for AUDITION because that is the receiving faculty
  Contains: "sys": "SENSORY", "sig": "AUDITION", "val": "Hello Libre!"
```

### Example 3: Verifying "Mindbending" (Instruction vs. Action)
Sometimes we instruct a Visitant to do something via REPL, and we want to verify the *instruction* was received before we verify the *action*.

```yaml
# 1. Verify the Cortex received the command
await:
  Title: Hippo Cortex Instruction
  Subject: Hippo Visitant
  Contains: "sys": "DEBUG", "sig": "Stdin", "val": "CHAT Hello"

# 2. Verify the Motor acted on it
await:
  Title: Hippo Motor Action
  Subject: Hippo Visitant
  Contains: "sys": "MOTOR", "sig": "VOCALIZATION", "val": "Hello"
```

---

## 5. INSTRUMENTATION CHEATSHEET (FOR CODING)

When inserting probes into the source code of a new Species:

**If you are hooking into the UI/Input Loop:**
* You are instrumenting **Will/Intent**.
* Use `sys: MOTOR`.

**If you are hooking into the Network/Packet Handler:**
* You are instrumenting **Perception**.
* Use `sys: SENSORY`.

**If you are hooking into a low-level byte inspector (like `ChatDialect`):**
* You are instrumenting **Physics**.
* Use `sys: TERRITORY` (or `PHYSICS`), `sig: WIRE_FORMAT`.
* *Note:* This is not a behavior of the agent; it is a property of the universe.

