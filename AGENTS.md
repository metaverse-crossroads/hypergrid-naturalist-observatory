# AGENTS.MD: OPERATIONAL PROTOCOLS & CONSTRAINTS

**WARNING TO AI AGENTS:** You are operating in a **Superexclude Environment** (`.gitignore` contains `*`). Standard git workflows will fail here. You must adhere to the following protocols to survive.

## 1. The Blindfold Rule (Git Hygiene)
* **DO NOT** run `git status` to verify your work. It will return empty/clean even if you have created files. This will confuse you and cause loops.
* **DO NOT** rely on file tracking heuristics.
* **ALWAYS** use `git add --force <file>` to stage your specific changes.
* **TRUST** that if you ran the command, the file is staged. Proceed directly to commit.

## 2. The Assignment Trap (Bash Safety)
* **CONTEXT:** In scripts using `set -e`, variable assignment `VAR=$(cmd)` **MASKS FAILURES**. The script will continue even if `cmd` exits with an error.
* **PROTOCOL:** You must **ALWAYS** append `|| exit 1` to assignments involving subshells.
    * *Wrong:* `DOTNET_ROOT=$("$ENSURE_DOTNET")`
    * *Right:* `DOTNET_ROOT=$("$ENSURE_DOTNET") || exit 1`

## 3. The Tracer Bullet Protocol (Verification)
* **CONTEXT:** Specimen builds (e.g., Benthic, OpenSim) are heavy, slow, and prone to environmental failures.
* **PROTOCOL:** NEVER verify infrastructure (Substrate/Hygiene) using a Production Specimen.
* **ACTION:** Always create a minimal "Tracer" (e.g., Hello World + 1 dependency) to verify plumbing.
    * If the Tracer fails, the infrastructure is broken.
    * If the Tracer succeeds, the infrastructure is valid, regardless of whether the Production Specimen builds.

## 4. The Containment Rule
* **PROTOCOL:** Instruments and Species folders must remain pristine.
* **ACTION:** All build artifacts, intermediate files, and binaries must be directed to `vivarium/`.
    * *Rust:* `export CARGO_TARGET_DIR="$REPO_ROOT/vivarium/..."`
    * *Dotnet:* `dotnet build ... --output "$REPO_ROOT/vivarium/..."`

## 5. Project Specifics
* **Structure:** 'species/' (config), 'instruments/' (tools), 'vivarium/' (workspace), 'OmvTestHarness/' (legacy).
* **Dotnet Substrate:** Managed by `instruments/substrate/ensure_dotnet.sh` (outputs `DOTNET_ROOT`).
* **Rust Substrate:** Managed by `instruments/substrate/ensure_rust.sh` (outputs `CARGO_HOME`).
* **Mimic:** C# .NET 8 instrument in `instruments/mimic/src`. Build artifacts must go to `vivarium/mimic/`.
* **Acquisition:** External repos (OpenSim, Benthic) acquired via `species/<name>/<ver>/acquire.sh` into `vivarium/`.

## 6. Robustness & Recovery
* **Synopsis Generation:** The Director generates `vivarium/encounter.{scenario}.synopsis.json` to allow external tools to self-configure.
* **Limbo State Handling:** `acquire.sh` scripts must detect and recover from "Limbo" states (directory exists but not a git repo) by nuking and re-cloning.
