# Naturalist Observatory

The Observatory is the mission control center for automated encounters between `Species` (e.g. OpenSim) and `Visitants` (e.g. Mimic, Benthic).

## Components

- **director.py**: The Python harness that parses Literate Scenarios (Markdown) and orchestrates the encounter.
- **run_encounter.sh**: The entry point script to launch a scenario.
- **editor.py**: A tool to analyze `vivarium/` logs and generate dailies/reports.
- **scenarios/**: A collection of Literate Scenarios defining encounters.

## Usage

To run a scenario:

```bash
./observatory/run_encounter.sh observatory/scenarios/standard.md
```

With options:

```bash
./observatory/run_encounter.sh observatory/scenarios/benthic.md -- --mode rejection
```

## Features

### Scenario Teleplay (Reification)
Before execution, the Director resolves all `[#include]` directives and saves the full, flattened scenario to `vivarium/encounter.{scenario}.teleplay.md`. This artifact represents the exact script being executed and is useful for debugging and review.

### Context Inference
Verification blocks (`VERIFY`, `AWAIT`) support "Context Inference" to avoid hardcoding log paths.

**Legacy Syntax:**
```markdown
File: vivarium/encounter.standard.visitant.VisitantOne.log
Contains: "sig": "Success"
```

**New Syntax:**
```markdown
Subject: Visitant One
Contains: "sig": "Success"
```

Supported Subjects:
- **Territory**: Resolves to the OpenSim encounter log.
- **<Visitant Name>**: Resolves to the specific Visitant's log (e.g., `Visitant One`).

### Stdio-REPL Console
The Director supports direct interaction with the OpenSim console via `opensim` blocks in scenarios. This allows for:
- Runtime provisioning (e.g., `create user`)
- Live administration (e.g., `alert`)
- Graceful shutdowns (e.g., `shutdown`)

Example:
```opensim
alert Attention Citizens: The Observatory is Watching.
```

## Protocol

This folder implements the "Naturalist Observatory" protocols defined in `AGENTS.md`. It emphasizes passive observation (`VERIFY`, `AWAIT`) and diegetic interaction.
