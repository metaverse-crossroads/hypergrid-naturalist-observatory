import sys
import os
import json
import subprocess
import re

#### WINDOWS MINGW GIT+BASH HELPERS ####
import platform
BASH = os.path.join(os.getenv('EXEPATH', '/bin'), 'bash')
# Replace 'C:\' with '/c/' and flip slashes
def manual_to_cygpath(path):
    path = path.replace('\\', '/')
    if platform.system() != 'Windows':
        return re.sub(r'^([a-zA-Z]):', lambda m: f'/{m.group(1).lower()}', path)
    return path
def maybe_wrap_bash_script(script):
    return [ BASH, script ] if platform.system() == 'Windows' else [ script ]
#### /WINDOWS MINGW GIT+BASH HELPERS ####

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.getenv('REPO_ROOT', os.path.dirname(SCRIPT_DIR))
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
            subprocess.run(maybe_wrap_bash_script(acquire_script), check=True, cwd=REPO_ROOT)
        except subprocess.CalledProcessError as e:
            print(f"[STAGEHAND] Failed to acquire '{fqn}': {e}")
            sys.exit(1)
    else:
        print(f"[STAGEHAND] Directory '{base_dir}' exists. Skipping acquisition.")

    # Always execute the incubate script
    print(f"[STAGEHAND] Incubating '{fqn}'... {incubate_script}")
    try:
        subprocess.run(maybe_wrap_bash_script(incubate_script), check=True, cwd=REPO_ROOT)
    except subprocess.CalledProcessError as e:
        print(f"[STAGEHAND] Failed to incubate '{fqn}': {e}")
        sys.exit(1)

    print(f"[STAGEHAND] Provisioning for '{fqn}' complete.")


def run_teleplay(filepath):
    if not os.path.exists(filepath):
        print(f"[STAGEHAND] Error: File '{filepath}' not found.")
        sys.exit(1)

    with open(filepath, 'r') as f:
        text = f.read()

    pattern = re.compile(r'^---\r?\n(.*?)\r?\n---', re.DOTALL)
    match = pattern.match(text)

    if not match:
        raise ValueError(f"Missing YAML frontmatter in '{filepath}'.")

    frontmatter = match.group(1)

    territory = None
    for line in frontmatter.splitlines():
        if line.startswith('territory:'):
            territory = line.split(':', 1)[1].strip()
            break

    if not territory:
        raise ValueError(f"Missing 'territory:' key in frontmatter of '{filepath}'.")

    #run_provision(territory)

    env = os.environ.copy()
    env["SIMULANT_FQN"] = territory

    director_path = os.path.join(SCRIPT_DIR, "director.py")
    try:
        subprocess.run([sys.executable, director_path, filepath], env=env, check=True)
    except subprocess.CalledProcessError as e:
        sys.exit(e.returncode)

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python3 stagehand.py provision <FQN> OR python3 stagehand.py run <path/to/teleplay.md>")
        sys.exit(1)

    command = sys.argv[1]
    arg = sys.argv[2]

    if command == "provision":
        run_provision(arg)
    elif command == "run":
        run_teleplay(arg)
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)
