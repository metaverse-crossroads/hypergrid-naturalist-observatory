#!/usr/bin/env python3
import sys
import os
import re
import subprocess
import time
import json
import signal
import threading
import sqlite3

# --- Configuration ---
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(os.path.dirname(SCRIPT_DIR))
VIVARIUM_DIR = os.path.join(REPO_ROOT, "vivarium")
MIMIC_DLL = os.path.join(VIVARIUM_DIR, "mimic", "Mimic.dll")
SEQUENCER_DLL = os.path.join(VIVARIUM_DIR, "sequencer", "Sequencer.dll")
OPENSIM_DIR = os.path.join(VIVARIUM_DIR, "opensim-core-0.9.3", "bin")
OBSERVATORY_DIR = os.path.join(VIVARIUM_DIR, "opensim-core-0.9.3", "observatory")
OPENSIM_BIN = os.path.join(OPENSIM_DIR, "OpenSim.dll")
ENSURE_DOTNET = os.path.join(REPO_ROOT, "instruments", "substrate", "ensure_dotnet.sh")

# --- Global State ---
evidence_log = []

# --- Environment Setup ---
def get_dotnet_env():
    """Retrieves the DOTNET_ROOT and PATH from ensure_dotnet.sh"""
    try:
        result = subprocess.run([ENSURE_DOTNET], capture_output=True, text=True, check=True)
        dotnet_root = result.stdout.strip()
        env = os.environ.copy()
        env["DOTNET_ROOT"] = dotnet_root
        env["PATH"] = f"{dotnet_root}:{env.get('PATH', '')}"
        return env
    except subprocess.CalledProcessError as e:
        print(f"Error initializing substrate: {e}")
        sys.exit(1)

ENV = get_dotnet_env()
ENV["OPENSIM_DIR"] = OPENSIM_DIR
ENV["OBSERVATORY_DIR"] = OBSERVATORY_DIR
ENV["VIVARIUM_ROOT"] = VIVARIUM_DIR

# --- Process Management ---
procs = []

def cleanup():
    """Kills all tracked processes."""
    print("\n[DIRECTOR] Shutting down...")
    for p in procs:
        if p.poll() is None:
            # print(f"Killing PID {p.pid}...")
            # Send SIGTERM first
            p.terminate()
            try:
                p.wait(timeout=5)
            except subprocess.TimeoutExpired:
                p.kill() # Force kill if stubborn
    print("[DIRECTOR] Done.")

def signal_handler(sig, frame):
    print_report()
    cleanup()
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

# --- Reporting ---

def print_report():
    print("\n" + "="*80)
    print(f"{'NATURALIST OBSERVATORY: EXPEDITION REPORT':^80}")
    print("="*80)
    print(f"{'OBSERVATION':<40} | {'FRAME':<20} | {'RESULT':<10}")
    print("-" * 80)

    all_passed = True
    for entry in evidence_log:
        status = "PASSED" if entry['passed'] else "FAILED"
        if not entry['passed']:
            all_passed = False
        print(f"{entry['title']:<40} | {entry['frame']:<20} | {status}")
        if not entry['passed']:
            print(f"  -> EVIDENCE MISSING: {entry['details']}")

    print("="*80)
    if all_passed and evidence_log:
        print(f"{'MISSION SUCCESS':^80}")
    elif not evidence_log:
        print(f"{'NO OBSERVATIONS RECORDED':^80}")
    else:
        print(f"{'MISSION FAILURE':^80}")
    print("="*80 + "\n")

# --- Block Handlers ---

def run_bash(content):
    """Executes a bash script block."""
    print(f"[DIRECTOR] Executing BASH block...")
    try:
        subprocess.run(["bash", "-c", content], env=ENV, cwd=REPO_ROOT, check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error in BASH block: {e}")
        print_report()
        cleanup()
        sys.exit(1)

def inject_sql(db_path, sql_script):
    """Injects SQL script into DB, statement by statement, ignoring errors."""
    if not os.path.exists(db_path):
        print(f"ERROR: DB {db_path} not found. CRITICAL FAILURE.")
        print_report()
        cleanup()
        sys.exit(1)

    try:
        with sqlite3.connect(db_path) as conn:
            cursor = conn.cursor()
            lines = sql_script.strip().split('\n')
            for line in lines:
                line = line.strip()
                if not line: continue
                try:
                    cursor.execute(line)
                except sqlite3.Error as e:
                    if "no such table" in str(e):
                        pass
                    else:
                        print(f"Warning: SQL Error in {os.path.basename(db_path)}: {e}")
            conn.commit()
    except sqlite3.Error as e:
        print(f"Warning: Connection Error to {db_path}: {e}")

def run_cast(content):
    """Parses JSON content to inject users via Sequencer."""
    print(f"[DIRECTOR] Executing CAST block...")
    try:
        cast_list = json.loads(content)

        observatory_dir = os.path.join(VIVARIUM_DIR, "opensim-core-0.9.3", "observatory")
        dbs = [
            os.path.join(observatory_dir, "userprofiles.db"),
            os.path.join(observatory_dir, "inventory.db"),
            os.path.join(observatory_dir, "auth.db")
        ]

        for actor in cast_list:
            first = actor.get("First", "Test")
            last = actor.get("Last", "User")
            password = actor.get("Password", "secret")
            uuid = actor.get("UUID", "00000000-0000-0000-0000-000000000000")

            print(f"  -> Casting {first} {last} ({uuid})")

            # Generate User SQL
            cmd_user = [
                "dotnet", SEQUENCER_DLL, "gen-user",
                "--first", first,
                "--last", last,
                "--pass", password,
                "--uuid", uuid
            ]
            sql_user = subprocess.check_output(cmd_user, env=ENV, cwd=VIVARIUM_DIR).decode()

            # Broadcast to all DBs
            for db in dbs:
                inject_sql(db, sql_user)

    except json.JSONDecodeError as e:
        print(f"Invalid JSON in CAST block: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"Error in CAST block: {e}")
        print_report()
        cleanup()
        sys.exit(1)

opensim_proc = None

def run_opensim(content):
    """Manages OpenSim process."""
    global opensim_proc

    if opensim_proc is None or opensim_proc.poll() is not None:
        print("[DIRECTOR] Starting OpenSim...")
        observatory_dir = os.path.join(VIVARIUM_DIR, "opensim-core-0.9.3", "observatory")
        standalone_ini = os.path.join(REPO_ROOT, "species", "opensim-core", "standalone-observatory-sandbox.ini")

        cmd = [
            "dotnet", "OpenSim.dll",
            f"-inifile={standalone_ini}",
            f"-inidirectory={observatory_dir}"
        ]

        log_file = open(os.path.join(observatory_dir, "opensim_console.log"), "w")

        opensim_proc = subprocess.Popen(
            cmd,
            cwd=OPENSIM_DIR,
            env=ENV,
            stdin=subprocess.PIPE,
            stdout=log_file,
            stderr=subprocess.STDOUT
        )
        procs.append(opensim_proc)
        print(f"[DIRECTOR] OpenSim started (PID {opensim_proc.pid})")
        time.sleep(1)

    lines = content.strip().split('\n')
    for line in lines:
        line = line.strip()
        if not line: continue

        if line.startswith("WAIT "):
            try:
                ms = int(line.split()[1])
                time.sleep(ms / 1000.0)
            except: pass
        elif line == "QUIT":
            print("[DIRECTOR] Terminating OpenSim...")
            if opensim_proc:
                opensim_proc.terminate()
                try:
                    opensim_proc.wait(timeout=5)
                except:
                    opensim_proc.kill()
                opensim_proc = None
        elif line == "WAIT_FOR_EXIT":
            print("[DIRECTOR] Waiting for OpenSim to exit...")
            if opensim_proc:
                exit_code = opensim_proc.wait()
                print(f"[DIRECTOR] OpenSim exited with code {exit_code}.")
                opensim_proc = None
                if exit_code != 0:
                    print("[DIRECTOR] OpenSim exited abnormally. CRITICAL FAILURE.")

                    # Print log tail for diagnostics
                    log_path = os.path.join(ENV["OBSERVATORY_DIR"], "opensim_console.log")
                    if os.path.exists(log_path):
                        print(f"\n--- DIAGNOSTIC: TAIL of {log_path} ---")
                        try:
                            subprocess.run(["tail", "-n", "20", log_path], check=False)
                        except Exception as e:
                            print(f"[DIRECTOR] Could not read log: {e}")
                        print("------------------------------------------\n")

                    print_report()
                    cleanup()
                    sys.exit(1)
        elif line.startswith("#"):
            pass # Ignore comments
        else:
            print(f"  -> OpenSim Command: {line}")
            if opensim_proc and opensim_proc.poll() is None:
                try:
                    opensim_proc.stdin.write((line + "\n").encode())
                    opensim_proc.stdin.flush()
                except BrokenPipeError:
                    print("[DIRECTOR] OpenSim pipe broken.")
            else:
                print("[DIRECTOR] OpenSim is not running. Cannot send command.")

mimic_sessions = {}

def get_mimic_session(name):
    """Get or create a Mimic process for a named actor."""
    if name in mimic_sessions:
        p = mimic_sessions[name]
        if p.poll() is None:
            return p
        else:
            print(f"[DIRECTOR] Session {name} died. Restarting...")

    print(f"[DIRECTOR] Spawning Mimic: {name}")
    log_path = os.path.join(VIVARIUM_DIR, f"mimic_{name.replace(' ', '_')}.log")
    log_file = open(log_path, "w")

    cmd = ["dotnet", MIMIC_DLL, "--repl"]

    p = subprocess.Popen(
        cmd,
        cwd=os.path.dirname(MIMIC_DLL), # Run in mimic dir
        env=ENV,
        stdin=subprocess.PIPE,
        stdout=log_file,
        stderr=subprocess.STDOUT
    )
    mimic_sessions[name] = p
    procs.append(p)
    return p

def run_mimic_block(name, content):
    p = get_mimic_session(name)

    lines = content.strip().split('\n')
    for line in lines:
        line = line.strip()
        if not line: continue

        print(f"  -> {name}: {line}")
        if p.stdin:
            try:
                p.stdin.write((line + "\n").encode())
                p.stdin.flush()
            except BrokenPipeError:
                print(f"[DIRECTOR] Connection to {name} lost.")
                break

def run_verify(content):
    """Parses and executes a VERIFY block."""
    lines = content.strip().split('\n')
    config = {}
    for line in lines:
        if ':' in line:
            key, val = line.split(':', 1)
            config[key.strip().lower()] = val.strip()

    title = config.get('title', 'Untitled Verification')
    filepath = config.get('file')
    pattern = config.get('contains')
    frame = config.get('frame', 'General')

    print(f"[DIRECTOR] Verifying: {title} ({frame})")

    if not filepath:
        print("  -> Error: No file specified for verification.")
        sys.exit(1)

    # Handle paths relative to repo root if not absolute
    if not os.path.isabs(filepath):
        full_path = os.path.join(REPO_ROOT, filepath)
    else:
        full_path = filepath

    passed = False
    details = ""

    if os.path.exists(full_path):
        with open(full_path, 'r', errors='replace') as f:
            log_content = f.read()
            if pattern and pattern in log_content:
                passed = True
                details = f"Found '{pattern}' in {os.path.basename(filepath)}"
                print(f"  -> PASSED: Found expected evidence.")
            else:
                details = f"Pattern '{pattern}' NOT found in {os.path.basename(filepath)}"
                print(f"  -> FAILED: {details}")
    else:
        details = f"File {filepath} does not exist."
        print(f"  -> FAILED: {details}")

    evidence_log.append({
        "title": title,
        "passed": passed,
        "details": details,
        "frame": frame
    })

    # Atomic Verification: Fail Fast on Critical Checks?
    # The prompt implies failing fast ("exiting with error code 1 on failure").
    # But we want to print the report first.
    if not passed:
        print_report()
        cleanup()
        sys.exit(1)

# --- Parser ---

def parse_and_execute(filepath):
    print(f"[DIRECTOR] Loading scenario: {filepath}")
    with open(filepath, 'r') as f:
        text = f.read()

    pattern = re.compile(r'^```(\w+)(?:[ \t]+(.*?))?\n(.*?)```', re.MULTILINE | re.DOTALL)

    pos = 0
    while True:
        match = pattern.search(text, pos)
        if not match:
            break

        block_type = match.group(1).lower()
        block_args = match.group(2).strip() if match.group(2) else ""
        block_content = match.group(3)

        print(f"\n--- STEP: {block_type.upper()} {block_args} ---")

        if block_type == 'bash':
            run_bash(block_content)
        elif block_type == 'cast':
            run_cast(block_content)
        elif block_type == 'opensim':
            run_opensim(block_content)
        elif block_type == 'mimic':
            name = block_args if block_args else "Visitant"
            run_mimic_block(name, block_content)
        elif block_type == 'verify':
            run_verify(block_content)
        elif block_type == 'wait':
            try:
                ms = int(block_content.strip())
                print(f"[DIRECTOR] Waiting {ms}ms...")
                time.sleep(ms / 1000.0)
            except:
                print("[DIRECTOR] Invalid Wait")

        pos = match.end()

    print_report()
    cleanup()
    print("\n[DIRECTOR] SCENARIO COMPLETED SUCCESSFULLY.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: director.py <scenario.md>")
        sys.exit(1)

    scenario_file = sys.argv[1]
    if not os.path.exists(scenario_file):
        print(f"Error: File {scenario_file} not found.")
        sys.exit(1)

    try:
        parse_and_execute(scenario_file)
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        print_report()
        cleanup()
        sys.exit(1)
