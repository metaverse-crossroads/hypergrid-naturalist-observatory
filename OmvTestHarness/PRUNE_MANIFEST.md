# Pruning Manifest: OmvTestHarness

This manifest lists resources from the legacy `OmvTestHarness/` directory that have been migrated, superseded, or deemed obsolete.

## Migrated Resources
*   **Narrator**: `generate_story.py` -> `instruments/narrator/generate_story.py`
*   **Documentation**:
    *   `Documentation/*` -> `journals/archive/`
    *   `agent-omv-journal.md` -> `journals/omv_legacy_protocols.md`
*   **Patches (Verification Complete)**:
    *   `probes/benthic-0.1.0/headless_client.patch` is equivalent to `species/benthic/0.1.0/adapt_deepsea.patch`.
    *   `probes/opensim-0.9.3/UserAuthenticator.patch` logic is subsumed by `species/opensim-core/0.9.3/instrument_encounter.patch` (MatingRitualLogger) and `adapt_console.patch` (Input Redirection).
    *   *Note*: The `UserAuthenticator.patch` also contained logic for creating a test user/estate setup. This logic might need to be explicitly handled by `instruments/mimic` or a new `incubate.sh` step if not already present.

## Obsolete Resources
*   **Scripts**:
    *   `bootstrap.sh`: Superseded by `instruments/substrate/ensure_dotnet.sh` and species `acquire.sh`.
    *   `run_scenarios.sh`: Logic should be handled by `instruments/mimic` or a future orchestrator.
*   **Junkdrawer**:
    *   `junkdrawer/`: Contains legacy build scripts and snippets (`test_runner.cs`) which are superseded by `mimic`.

## Pending Deletion
*   `OmvTestHarness/OmvTestHarness.csproj`: This C# project contains the actual test logic (Ghost, Wallflower).
    *   **ACTION REQUIRED**: Verify `instruments/mimic` implements these scenarios before deleting this file.
*   `OmvTestHarness/probes/`: Can be deleted once `mimic` is confirmed to handle the scenarios.
*   `OmvTestHarness/targets/`: Can be deleted.

## Instructions for Next Agent
1.  Verify `instruments/mimic` covers the scenarios in `OmvTestHarness.csproj`.
2.  Delete `OmvTestHarness/` recursively.
