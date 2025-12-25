# AGENTS.MD: OPERATIONAL PROTOCOLS & CONSTRAINTS

**WARNING TO AI AGENTS:** You are operating in a **Semi-Permeable Environment**. The `.gitignore` uses a "Deny by Default" strategy with explicit "Safe Harbors".

## 1. The Safe Harbor Protocol (Git Hygiene)
* **The Rule:** The root directory is Lava. `vivarium/` is a Black Hole.
    * The `.gitignore` blocks everything (`/*`) by default.
    * Specific directories (`species/`, `instruments/`, `observatory/`, `journals/`) are **whitelisted** ("Safe Harbors").
* **Implication:**
    * Inside Safe Harbors: `git status` works normally. You can see untracked files. The auto-staging agent ("The Demon") may helpfully stage them for you.
    * In the Root or Vivarium: Files are ignored. `git status` will be blind to them.
* **Adding Root Files:**
    * If you must add a new file to the root (e.g., `.gitattributes`, `.editorconfig`, `.github/`), you **MUST** first add it to the whitelist in `.gitignore`.
    * **DO NOT** use `git add --force` blindly on root files. If it's not in the whitelist, it doesn't belong in the repo.

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
* **Limbo State Handling:** `acquire.sh` scripts must detect and assist in recovery from "Limbo" states (directory exists but not a git repo) by explaining cleanup and re-cloning procedures.

## 7. Version Control Hygiene (STRICT)
* **Strict Prohibition on .gitignore:** You are FORBIDDEN from modifying `.gitignore` preemptively. You may only modify `.gitignore` in response to an explicit instruction from the user. If you encounter untracked files that you believe should be ignored, you must first ask the user or investigate why they are being generated in the wrong place (Containment Breach).
