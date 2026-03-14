import sys
import os
import json
import subprocess

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
MANIFEST_PATH = os.path.join(REPO_ROOT, "species", "manifest.json")
VIVARIUM_DIR = os.path.join(REPO_ROOT, "vivarium")

def run_provision(fqn):
    try:
        with open(MANIFEST_PATH, "r") as f:
            manifest_data = json.load(f)
    except Exception as e:
        print(f"[STAGEHAND] Error reading manifest.json: {e}")
        sys.exit(1)

    simulant_cfg = None
    for entry in manifest_data.get("registry", []):
        entry_fqn = f"{entry['genus']}-{entry['species']}"
        if entry_fqn == fqn:
            simulant_cfg = entry
            break

    if not simulant_cfg:
        print(f"[STAGEHAND] Error: Simulant '{fqn}' not found in manifest.")
        sys.exit(1)

    base_dir = os.path.join(VIVARIUM_DIR, fqn)
    acquire_script = os.path.join(REPO_ROOT, simulant_cfg["acquire_script"])
    incubate_script = os.path.join(REPO_ROOT, simulant_cfg["incubate_script"])

    # Setup environment? The scripts rely on `source observatory_env.bash` inside them
    # But let's run them directly since they start with #!/bin/bash and source it themselves.

    # Check if the directory exists
    if not os.path.isdir(base_dir):
        print(f"[STAGEHAND] Directory '{base_dir}' is missing. Acquiring...")
        try:
            subprocess.run([acquire_script], check=True, cwd=REPO_ROOT)
        except subprocess.CalledProcessError as e:
            print(f"[STAGEHAND] Failed to acquire '{fqn}': {e}")
            sys.exit(1)
    else:
        print(f"[STAGEHAND] Directory '{base_dir}' exists. Skipping acquisition.")

    # Always execute the incubate script
    print(f"[STAGEHAND] Incubating '{fqn}'...")
    try:
        subprocess.run([incubate_script], check=True, cwd=REPO_ROOT)
    except subprocess.CalledProcessError as e:
        print(f"[STAGEHAND] Failed to incubate '{fqn}': {e}")
        sys.exit(1)

    print(f"[STAGEHAND] Provisioning for '{fqn}' complete.")

if __name__ == "__main__":
    if len(sys.argv) < 3 or sys.argv[1] != "provision":
        print("Usage: python3 stagehand.py provision <FQN>")
        sys.exit(1)

    fqn = sys.argv[2]
    run_provision(fqn)
