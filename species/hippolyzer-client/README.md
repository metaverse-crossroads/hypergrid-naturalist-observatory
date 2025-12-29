# Hippolyzer Client Visitant

This species adapts the [Hippolyzer](../../instruments/hippolyzer/README.md) protocol analyzer into a standalone OpenSim client visitant (Deep Sea variant).

## Overview

Hippolyzer is primarily a "man-in-the-middle" instrument for inspecting OpenSim traffic, but it exposes a client library that can be used to connect directly to simulators. This visitant leverages `hippolyzer.lib.client` to implement the standard Visitant protocols.

## Usage

See `0.17.0/README.md` (if available) or simply use the standard `run_visitant.sh` interface.

## Reference

*   [Hippolyzer Instrument](../../instruments/hippolyzer/README.md)

## Integration Patterns & Observations

When utilizing `hippolyzer-client` as a Visitant (e.g. via `DeepSeaClient`), several adaptations are required to ensure robustness against the raw, sometimes non-compliant, behavior of the Event Queue and OpenSim messaging protocol:

1.  **Robust Event Polling:** The standard `hippolyzer` client may crash if the Event Queue delivers data types that do not match the expected LLSD template schema (e.g., receiving raw integers where byte-packed structs are expected). The client wrapper (`deepsea_client.py`) monkeypatches `LLSDDataPacker` to gracefully handle these discrepancies.

2.  **Missing Block Handling:** Certain messages (e.g., `AvatarAppearance`) may arrive with missing blocks (like `AppearanceData`), which can cause internal `IndexError`s in the `ObjectManager`. The client wrapper intercepts and suppresses these errors to keep the session alive.

3.  **Chat Wiring:** Listening for chat involves subscribing to `ChatFromSimulator`. The message payload structure is standard, containing `ChatData` with `FromName` and `Message`.

These patches are applied at runtime in `deepsea_client.py` to avoid maintaining a forked version of the upstream library.

---

## ⚠️ SCIENTIFIC PROTOCOL: LESSONS LEARNED

**WE SHALL BE PERPETUALLY EXPECTING ALL LESSONS LEARNED AS CRITICAL OBSERVATORY EVIDENCE. NOT DOCUMENTING LESSONS LEARNED IS AKIN TO DESTROYING SCIENTIFIC EVIDENCE AND KNOWLEDGE.**

### Investigation Log (Dec 2025)

The integration of `hippolyzer-client` required navigating several undocumented behaviors and failure modes. The following unsuccessful attempts and findings are documented to prevent regression:

#### 1. Handler Patching Complexity
*   **Attempt:** Initially attempted to patch the `AvatarAppearance` crash by subclassing `HippoClient` and calling `unsubscribe` on the original handler in `__init__`.
*   **Failure:** This failed because `self.session` (and thus `message_handler`) is not initialized until `login()` is called. Additionally, attempting to unsubscribe the specific bound method of `ClientWorldObjectManager` proved unreliable, possibly due to instance identity or registration timing.
*   **Solution:** The robust fix involved patching *after* login (in `DeepSeaClient.do_login`) and using `clear_subscribers()` on the specific event ("AvatarAppearance") to forcefully remove the upstream handler before registering the safe wrapper.

#### 2. Presence Detection Latency
*   **Observation:** The scenario `hippolyzer_TDD_chat` failed to detect "Visual Confirmation" of the Reference Beacon.
*   **Failure:** Relying solely on `ObjectUpdate` events with `PCode.AVATAR` was insufficient because `obj.Name` was initially `None`. The `hippolyzer` NameCache does not always automatically request names for new objects, or the `ObjectUpdate` packet arrived without `NameValue` data.
*   **Solution:** Implemented an explicit `UUIDNameRequest` trigger in the `ObjectUpdate` handler when a nameless avatar is detected. Subscribing to `UUIDNameReply` ensured the name was resolved and the "Presence Avatar" signal could be emitted reliably within the test timeout.

#### 3. Log Matching Strictness
*   **Observation:** The test passed Downlink (Client Rx) but failed Uplink (Control Rx) despite the Reference Beacon (Mimic) logging the message.
*   **Failure:** The scenario file `hippolyzer_TDD_chat.md` expected `val` to contain *only* the message body (e.g., "SYS_ACK_BETA_02"). However, both Mimic and the initial Hippolyzer implementation logged `From: {Name}, Msg: {Body}`. The harness uses strict matching on the JSON `val` field.
*   **Solution:** Updated `hippolyzer_TDD_chat.md` to expect the full string format used by Mimic (`From: ..., Msg: ...`) and ensured `DeepSeaClient` matched this format exactly. This aligns the test expectation with the "wild type" behavior of the reference instrument.
