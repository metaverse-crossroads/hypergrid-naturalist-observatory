# Salvage Protocol Wisdom

**Status:** ARCHIVED (Absorbed & Memorialized)
**Origin:** Interdimensional Merge Conflict (Branch `_salvage`)

This directory preserves the unique strategies and "Mindsets" discovered in the Salvage timeline. While the Mainline has absorbed the superior code artifacts (Granular Patching, Rich Mimic Instrumentation), the specific *workflows* and *philosophies* of the Salvage protocol are documented here as recoverable wisdom.

## Technique 1: Runtime Console Injection
**Strategy:** Instead of generating SQL offline (The Sequencer), the Salvage protocol utilized OpenSim's `startup_console_commands_file` configuration to inject users and environment settings at runtime.
**Benefit:** Zero external dependencies (no SQlite, no Sequencer DLL). Pure config-based setup.
**Executable Example:** See `archive/setup_encounter_salvage.sh` logic.
```bash
# Key Logic
cat <<EOF > startup_commands.txt
create user Test User2 password test2@example.com
change region My Estate
EOF
sed -i 's/; startup_console_commands_file = "startup_commands.txt"/startup_console_commands_file = "startup_commands.txt"/' OpenSim.ini
```

## Technique 2: The Bootstrap Protocol
**Strategy:** In environments where pre-compiled binaries (`bin/prebuild.dll`) are missing or corrupt, the Salvage protocol implemented a self-healing bootstrap step.
**Benefit:** Extreme resilience. Code compiles its own build tools before building itself.
**Adoption:** This technique has been **ABSORBED** into the Mainline `incubate.sh`.
**Key Logic:**
```bash
dotnet build Prebuild/src/Prebuild.Bootstrap.csproj -c Release
cp Prebuild/src/bin/Release/net8.0/prebuild.dll bin/
```

## Technique 3: Single-Stream Verification
**Strategy:** Instead of managing parallel log files for each agent, the Salvage protocol directed all entropy into a single `encounter.log` and used complex `grep` patterns to discern "Success".
**Benefit:** Simplicity of execution (one log to rule them all).
**Trade-off:** High I/O contention and difficulty in separating cause/effect.
**Legacy Artifact:** `archive/run_encounter_salvage.sh`.

## Technique 4: The "Observer & Actor" Pattern
**Strategy:** Assigning distinct behavioral roles to Visitants. Visitant 1 observes (logs), while Visitant 2 acts (rezzes, chats).
**Adoption:** Absorbed into Mainline `run_encounter.sh`.
