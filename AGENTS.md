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

## 8. The Anti-Lazy Protocol (Verification)
* **CONTEXT:** This repository provides a full substrate for .NET, Rust, and Python.
* **PROTOCOL:** You are FORBIDDEN from skipping verification steps by claiming missing dependencies.
    * If a build fails, you must diagnose and fix it using the provided environment.
    * You MUST run tests/builds to verify changes. `grep` is not execution.
    * **HALT** if you are instructed to halt for approval. Do not `submit` or `pre-commit` until authorized.
    * **EXCUSES:** "I don't have the environment" is a lie. The environment is here. Use it.

## 9. The Honesty Protocol (Mandate)
* **CONTEXT:** User trust is paramount. Misleading logging or "stubbed" functionality that mimics success is a critical failure.
* **PROTOCOL:**
    * **NEVER** implement "dead weight" commands that log success but do nothing.
    * If a command is not implemented, you MUST either:
        1. Implement it fully.
        2. Fail explicitly (e.g., throw an error, return a failure status, or log a loud "NOT IMPLEMENTED" warning and do not proceed with a "success" path).
    * **Explicit Failure:** `emit("System", "Warning", "NOT IMPLEMENTED")` is acceptable. `emit("System", "Success", "Done")` when nothing happened is FORBIDDEN.
    * **Benthic Specific:** `LOGOUT` must perform a network logout or explicitly state it is a local-only exit. `REZ` must warn if not implemented.

## 10. The Makefile Protocol (Mandate)
* **CONTEXT:** A `Makefile` exists to standardize acquisition, incubation (build), and execution of species and instruments.
* **PROTOCOL:**
    * **ALWAYS** check the `Makefile` before attempting to build or run anything manually.
    * **USE** `make <target>` instead of invoking shell scripts directly when possible, as the Makefile often handles dependencies and environment setup.
    * **DO NOT** complain about missing environments without first trying the `make` commands provided.
    * **Status Check:** Use `make status` to inspect the state of the vivarium before planning complex operations.

## 11. The Korzybski Protocol (Map vs. Territory)
* **CONTEXT:** You will encounter behaviors that violate official specs (The Map).
* **THE LAW:** "The Map is not the Territory."
    * **The Map:** The Wiki, the IETF drafts, the "Should Be".
    * **The Territory:** The compiled binary, the actual behavior of `DeepSeaClient.cs`.
* **PROTOCOL:**
    * **Observation First:** Your primary duty is to document the Territory as it *is*, not as it *should be*.
    * **The Thorn Rule:** If you encounter a "thorn in the paw" (a bug), you may contemplate removing it, but you **MUST** re-classify the Specimen.
        * *Wild Type:* The broken, original code.
        * *Domesticated Variant:* The patched, working code.
    * **Action:** Never silently patch a Wild Type to make it pass a test. Create a clean room patch in `patches/` or branch into a new Variant definition so the distinction remains visible.

## 12. The Requisite Variety Protocol (The Director's Burden)
* **CONTEXT:** The ecosystem is chaotic. Specimens are rigid.
* **THE LAW:** "Only variety can absorb variety." (Law of Requisite Variety)
* **IMPLICATION:** The `Director` (and you) must possess *more* behavioral flexibility than the specimens you observe.
    * If a specimen fails to `LOGIN`, do not retry the exact same way. Adapt the inputs, change the timing, or "Match Complexity" with a nuanced fallback.
    * Your internal "Arsenal" of responses must be larger than the variety of bugs you encounter.

## 13. The Aladdin Rug Protocol (Environmental Instability)
* **CONTEXT:** The runtime environment is subject to spontaneous "Rug Pulls" (Hard Resets) where the entire container/VM is rebooted to a fresh state.
* **SYMPTOMS:**
    *   `uptime` is < 5 minutes despite a long chat history.
    *   `/tmp` and `/dev/shm` are empty.
    *   Uncommitted files and staged changes are **LOST**.
    *   The `canary` function is missing (command not found).
* **PROTOCOL:**
    *   **The Canary:** You must use the `canary` wrapper for significant commands (e.g., `canary make status`).
    *   **The Warning:** If `canary: command not found` occurs, the environment has been reset.
    *   **The Recovery:**
        1.  **STOP.** Do not run panic commands.
        2.  **READ.** Review the Chat History to understand what state was lost.
        3.  **RE-APPLY.** Manually re-create files and re-run setup steps based on your memory of the session.
        4.  **RE-SOURCE.** Run `source instruments/substrate/observatory_env.bash` to restore the immune system.
