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
# SCRIPT_DIR is observatory/
# REPO_ROOT is one level up
REPO_ROOT = os.path.dirname(SCRIPT_DIR)

VIVARIUM_DIR = os.path.join(REPO_ROOT, "vivarium")
MIMIC_DLL = os.path.join(VIVARIUM_DIR, "mimic", "Mimic.dll")
SEQUENCER_DLL = os.path.join(VIVARIUM_DIR, "sequencer", "Sequencer.dll")
OPENSIM_DIR = os.path.join(VIVARIUM_DIR, "opensim-core-0.9.3", "bin")
OBSERVATORY_DIR = os.path.join(VIVARIUM_DIR, "opensim-core-0.9.3", "observatory")
OPENSIM_BIN = os.path.join(OPENSIM_DIR, "OpenSim.dll")
ENSURE_DOTNET = os.path.join(REPO_ROOT, "instruments", "substrate", "ensure_dotnet.sh")

MIMIC_SCRIPT = os.path.join(REPO_ROOT, "instruments", "mimic", "run_visitant.sh")
BENTHIC_SCRIPT = os.path.join(REPO_ROOT, "species", "benthic", "0.1.0", "run_visitant.sh")
REST_CONSOLE_WRAPPER = os.path.join(REPO_ROOT, "species", "opensim-core", "rest-console", "connect_opensim_console_session.sh")

# --- Global State ---
evidence_log = []
SCENARIO_NAME = "unknown"
SCENARIO_METADATA = {} # Parsed from Frontmatter
ACTORS = {}
next_benthic_port = 12000
SIGINT_COUNT = 0
opensim_proc = None
opensim_console_interface = None # Abstraction for sending commands

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

# --- Console Abstraction ---

class LocalConsole:
    def __init__(self, process):
        self.process = process

    def send(self, command):
        if self.process and self.process.poll() is None:
            try:
                print(f"  -> OpenSim Command (Local): {command}")
                self.process.stdin.write((command + "\n").encode())
                self.process.stdin.flush()
            except BrokenPipeError:
                print("[DIRECTOR] OpenSim pipe broken.")
        else:
            print("[DIRECTOR] OpenSim is not running. Cannot send command.")

    def close(self):
        pass

class RestConsole:
    def __init__(self, process, url="http://127.0.0.1:9000", user="RestUser", password="RestPassword"):
        self.process = process # We still track the main OpenSim process
        self.daemon_proc = None
        self.url = url
        self.user = user
        self.password = password
        self.connected = False

    def _ensure_connected(self):
        if self.connected and self.daemon_proc and self.daemon_proc.poll() is None:
            return True

        # Wait for OpenSim to be ready?
        # Ideally we should retry connection
        if not self.daemon_proc:
            print("[DIRECTOR] Launching REST Console Daemon...")
            env = ENV.copy()
            env["OPENSIM_URL"] = self.url
            env["OPENSIM_USER"] = self.user
            env["OPENSIM_PASS"] = self.password

            try:
                self.daemon_proc = subprocess.Popen(
                    [REST_CONSOLE_WRAPPER],
                    env=env,
                    stdin=subprocess.PIPE,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE, # Capture stderr to avoid noise
                    text=True
                )

                # Consume initial connection output
                # The daemon outputs {"event": "connected", ...} or {"error": ...}
                # We need to read this carefully without blocking forever
                # But since we are in the main thread and send() is called sequentially...
                # We can't block here for too long.
                # However, the daemon connects on startup.
                pass
            except Exception as e:
                print(f"[DIRECTOR] Failed to launch REST Console Daemon: {e}")
                return False

        return True

    def send(self, command):
        if not self._ensure_connected():
            print("[DIRECTOR] REST Console not connected. Ignoring command.")
            return

        print(f"  -> OpenSim Command (REST): {command}")
        try:
            self.daemon_proc.stdin.write(command + "\n")
            self.daemon_proc.stdin.flush()

            # Read response (blocking for now, as daemon is synchronous)
            # The daemon emits exactly one JSON line per command
            line = self.daemon_proc.stdout.readline()
            if line:
                try:
                    resp = json.loads(line)
                    if "response" in resp:
                         # Log the response to stdout for visibility?
                         # Or just ignore it as per local console behavior (which logs to file)
                         # If we want to see it:
                         # print(f"    <- {resp['response'].strip()}")
                         pass
                    if "error" in resp:
                        print(f"[DIRECTOR] REST Error: {resp['error']}")
                except json.JSONDecodeError:
                    print(f"[DIRECTOR] Invalid REST response: {line.strip()}")
            else:
                print("[DIRECTOR] REST Console Daemon closed stream.")
                self.connected = False
        except Exception as e:
            print(f"[DIRECTOR] Error sending REST command: {e}")
            self.connected = False

    def close(self):
        if self.daemon_proc:
            print("[DIRECTOR] Terminating REST Console Daemon...")
            self.daemon_proc.terminate()
            try:
                self.daemon_proc.wait(timeout=2)
            except:
                self.daemon_proc.kill()
            self.daemon_proc = None

# Sync with os.environ so os.path.expandvars works immediately
os.environ.update(ENV)

# --- Process Management ---
procs = [] # List of (process_handle, name/type) tuples

def cleanup_graceful():
    """Terminates Visitants first, then OpenSim."""
    print("\n[DIRECTOR] Graceful shutdown initiated...")

    # Close Console Interface
    global opensim_console_interface
    if opensim_console_interface:
        opensim_console_interface.close()

    # 1. Terminate Visitants (Reverse order of creation usually good)
    for p, name in reversed(procs):
        if p == opensim_proc: continue # Skip OpenSim for now

        if p.poll() is None:
            print(f"[DIRECTOR] Terminating {name}...")
            p.terminate()
            try:
                p.wait(timeout=2)
            except subprocess.TimeoutExpired:
                print(f"[DIRECTOR] Killing {name}...")
                p.kill()

    # 2. Terminate OpenSim
    if opensim_proc and opensim_proc.poll() is None:
        print("[DIRECTOR] Terminating OpenSim...")
        opensim_proc.terminate()
        try:
            opensim_proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
             print("[DIRECTOR] Killing OpenSim...")
             opensim_proc.kill()

    print("[DIRECTOR] Shutdown complete.")

def cleanup_force():
    """Immediately kills all processes."""
    print("\n[DIRECTOR] Forced shutdown initiated...")
    for p, name in procs:
        if p.poll() is None:
            try:
                p.kill()
            except: pass
    print("[DIRECTOR] All processes killed.")

def signal_handler(sig, frame):
    global SIGINT_COUNT
    SIGINT_COUNT += 1

    if SIGINT_COUNT == 1:
        print("\n[DIRECTOR] Interrupt received. Cleaning up... (Press Ctrl-C again to force quit)")
        print_report()
        cleanup_graceful()
        sys.exit(0)
    else:
        cleanup_force()
        sys.exit(1)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

# --- Reporting ---

def print_report():
    print("\n" + "="*100)
    title_line = "NATURALIST OBSERVATORY: EXPEDITION REPORT"
    if SCENARIO_METADATA.get("Title"):
        title_line += f" ({SCENARIO_METADATA['Title']})"
    print(f"{title_line:^100}")
    print("="*100)
    print(f"{'OBSERVATION':<40} | {'FRAME':<30} | {'RESULT':<10} | {'TYPE':<10}")
    print("-" * 100)

    all_passed = True
    for entry in evidence_log:
        status = "PASSED" if entry['passed'] else "FAILED"
        if not entry['passed']:
            all_passed = False

        # Infer type from title/frame if not present, but AWAIT usually implies Event
        obs_type = entry.get('type', 'State')

        print(f"{entry['title']:<40} | {entry['frame']:<30} | {status:<10} | {obs_type:<10}")
        if not entry['passed']:
            print(f"  -> EVIDENCE MISSING: {entry['details']}")

    print("="*100)
    if all_passed and evidence_log:
        print(f"{'MISSION SUCCESS':^100}")
    elif not evidence_log:
        print(f"{'NO OBSERVATIONS RECORDED':^100}")
    else:
        print(f"{'MISSION FAILURE':^100}")
    print("="*100 + "\n")

def log_observation(title, frame, passed, details, obs_type="State"):
    evidence_log.append({
        "title": title,
        "frame": frame,
        "passed": passed,
        "details": details,
        "type": obs_type
    })

# --- Block Handlers ---

def run_bash_export(content):
    """Executes a bash block and captures exported variables."""
    print(f"[DIRECTOR] Executing BASH-EXPORT block...")

    # Marker to separate script output from env dump
    marker = "___ENV_MARKER___"

    # Wrap content to dump env after execution
    wrapper = f"{content}\necho '{marker}'\nprintenv"

    try:
        # Run and capture output
        result = subprocess.run(
            ["bash", "-c", wrapper],
            env=ENV,
            cwd=REPO_ROOT,
            check=True,
            capture_output=True,
            text=True
        )

        # Parse output
        output = result.stdout
        if marker in output:
            script_out, env_out = output.split(marker, 1)
            if script_out.strip():
                print(script_out.strip())

            # Parse env vars
            for line in env_out.splitlines():
                if '=' in line:
                    key, val = line.split('=', 1)
                    # Only update if new or changed (and not internal bash vars ideally, but simple overwrite is okay)
                    if key not in ENV or ENV[key] != val:
                        ENV[key] = val
                        os.environ[key] = val # Update os.environ too
                        print(f"  -> Exported: {key}={val}")
        else:
            print("Warning: Could not capture environment from bash-export block.")

    except subprocess.CalledProcessError as e:
        print(f"Error in BASH-EXPORT block: {e}")
        print(f"Stderr: {e.stderr}")
        print_report()
        cleanup_graceful()
        sys.exit(1)

def run_bash(content):
    """Executes a bash script block."""
    print(f"[DIRECTOR] Executing BASH block...")
    try:
        subprocess.run(["bash", "-c", content], env=ENV, cwd=REPO_ROOT, check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error in BASH block: {e}")
        print_report()
        cleanup_graceful()
        sys.exit(1)

def inject_sql(db_path, sql_script):
    """Injects SQL script into DB, statement by statement, ignoring errors."""
    if not os.path.exists(db_path):
        print(f"ERROR: DB {db_path} not found. CRITICAL FAILURE.")
        print_report()
        cleanup_graceful()
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
            species = actor.get("Species", "Mimic").lower()

            full_name = f"{first} {last}"
            ACTORS[full_name] = actor # Store full actor config

            print(f"  -> Casting {first} {last} ({uuid}) as {species}")

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
        cleanup_graceful()
        sys.exit(1)

def run_opensim(content):
    """Manages OpenSim process."""
    global opensim_proc
    global opensim_console_interface

    if opensim_proc is None or opensim_proc.poll() is not None:
        print("[DIRECTOR] Starting OpenSim...")
        observatory_dir = os.path.join(VIVARIUM_DIR, "opensim-core-0.9.3", "observatory")
        standalone_ini = os.path.join(REPO_ROOT, "species", "opensim-core", "standalone-observatory-sandbox.ini")

        # Determine Console Mode
        console_mode = os.environ.get("OPENSIM_CONSOLE", "local").lower()
        use_rest = console_mode == "rest"

        if use_rest:
            print("[DIRECTOR] Mode: REST Console")
            # Inject REST configuration
            rest_ini_path = os.path.join(observatory_dir, "RestConsole.ini")
            with open(rest_ini_path, "w") as f:
                f.write("[Startup]\n")
                f.write('    console = "rest"\n\n')
                f.write("[Network]\n")
                f.write('    ConsoleUser = "RestUser"\n')
                f.write('    ConsolePass = "RestPassword"\n')

            # Generate Synopsis for external tools
            synopsis = {
                "Scenario": SCENARIO_NAME,
                "Metadata": SCENARIO_METADATA,
                "OpenSimURL": "http://127.0.0.1:9000",
                "OpenSimUser": "RestUser",
                "OpenSimPass": "RestPassword"
            }
            synopsis_path = os.path.join(VIVARIUM_DIR, f"encounter.{SCENARIO_NAME}.synopsis.json")
            try:
                with open(synopsis_path, "w") as f:
                    json.dump(synopsis, f, indent=4)
                print(f"[DIRECTOR] Wrote synopsis to {synopsis_path}")
            except Exception as e:
                print(f"[DIRECTOR] Error writing synopsis: {e}")

        else:
             print("[DIRECTOR] Mode: Local Console")

        cmd = [
            "dotnet", "OpenSim.dll",
            f"-inifile={standalone_ini}",
            f"-inidirectory={observatory_dir}"
        ]

        # Log file for Console output
        log_file = open(os.path.join(observatory_dir, "opensim_console.log"), "w")

        # Configure the predictable Encounter Log path
        encounter_log = os.path.join(VIVARIUM_DIR, f"encounter.{SCENARIO_NAME}.territory.log")

        proc_env = ENV.copy()
        proc_env["OPENSIM_ENCOUNTER_LOG"] = encounter_log

        # Inject TAG_UA for OpenSim
        # Assuming species/opensim-core/0.9.3 for now
        proc_env["TAG_UA"] = "species/opensim-core/0.9.3"

        opensim_proc = subprocess.Popen(
            cmd,
            cwd=OPENSIM_DIR,
            env=proc_env,
            stdin=subprocess.PIPE,
            stdout=log_file,
            stderr=subprocess.STDOUT
        )
        procs.append((opensim_proc, "OpenSim"))
        print(f"[DIRECTOR] OpenSim started (PID {opensim_proc.pid})")
        print(f"[DIRECTOR] Encounter Log: {encounter_log}")
        time.sleep(1)

        # Initialize Interface
        if use_rest:
            opensim_console_interface = RestConsole(opensim_proc)
        else:
            opensim_console_interface = LocalConsole(opensim_proc)

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
            if opensim_console_interface:
                opensim_console_interface.close()

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
                    cleanup_graceful()
                    sys.exit(1)
        elif line.startswith("#"):
            pass # Ignore comments
        else:
            if opensim_console_interface:
                opensim_console_interface.send(line)
            else:
                 print("[DIRECTOR] Console interface not initialized.")

mimic_sessions = {}

def get_mimic_session(name):
    """Get or create a Visitant process for a named actor."""
    if name in mimic_sessions:
        p = mimic_sessions[name]
        if p.poll() is None:
            return p
        else:
            print(f"[DIRECTOR] Session {name} died.")
            assert False

    if name not in ACTORS:
         # Fallback for actors not explicitly CAST?
         print(f"[DIRECTOR] Warning: {name} not found in CAST.")
         assert False
         actor_config = {"First": "Test", "Last": "User", "Species": "mimic"}
    else:
         actor_config = ACTORS[name]

    species = actor_config.get("Species", "mimic").lower()
    print(f"[DIRECTOR] Spawning {species.capitalize()}: {name}")

    # Predictable log path: encounter.<SCENARIO>.visitant.<NAME>.log
    clean_name = name.replace(" ", "")
    log_path = os.path.join(VIVARIUM_DIR, f"encounter.{SCENARIO_NAME}.visitant.{clean_name}.log")

    log_file = open(log_path, "w")

    proc_env = ENV.copy()
    # Remove encounter log env var to avoid confusion, though stdout capture is main method
    if "MIMIC_ENCOUNTER_LOG" in proc_env:
        del proc_env["MIMIC_ENCOUNTER_LOG"]

    # Derive TAG_UA
    # For now, hardcoded derivation logic as requested
    if species == "benthic":
        tag_ua = "benthic/0.1.0"
    else:
        tag_ua = "instruments/mimic"

    proc_env["TAG_UA"] = tag_ua

    if species == "benthic":
        # Benthic requires args
        first = actor_config.get("First")
        last = actor_config.get("Last")
        password = actor_config.get("Password")

        # Allocate ports
        global next_benthic_port
        ui_port = next_benthic_port
        core_port = next_benthic_port + 1
        next_benthic_port += 2

        cmd = [
            BENTHIC_SCRIPT,
            "--repl",
            "--user", first,
            "--lastname", last,
            "--password", password,
            "--ui-port", str(ui_port),
            "--core-port", str(core_port),
        ]

        cwd = os.path.dirname(BENTHIC_SCRIPT)

    else:
        # Default to Mimic
        cmd = ["dotnet", MIMIC_DLL, "--repl"]
        cwd = os.path.dirname(MIMIC_DLL)

    p = subprocess.Popen(
        cmd,
        cwd=cwd,
        env=proc_env,
        stdin=subprocess.PIPE,
        stdout=log_file,
        stderr=subprocess.STDOUT
    )
    mimic_sessions[name] = p
    procs.append((p, f"{species.capitalize()}:{name}"))
    return p

def run_mimic_block(name, content):
    p = get_mimic_session(name)

    # Check species to see if we should send commands
    species = "mimic"
    if name in ACTORS:
        species = ACTORS[name].get("Species", "mimic").lower()

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
        else:
            print(f"[DIRECTOR] p.stdin with {name} not available {p.stdin}.")
            break


def parse_kv_block(content):
    lines = content.strip().split('\n')
    config = {}
    for line in lines:
        if ':' in line:
            key, val = line.split(':', 1)
            config[key.strip().lower()] = os.path.expandvars(val.strip())
    return config

def resolve_log_source(config):
    """Resolves the file path from 'File' or 'Subject' keys."""
    filepath = config.get('file')
    subject = config.get('subject')

    if filepath:
        # Explicit file takes precedence, but we still expand vars
        return os.path.expandvars(filepath)

    if subject:
        if subject.lower() == "territory":
             return os.path.join(VIVARIUM_DIR, f"encounter.{SCENARIO_NAME}.territory.log")

        # Assume it's a Visitant (Subject: Visitant One)
        clean_name = subject.replace(" ", "")
        return os.path.join(VIVARIUM_DIR, f"encounter.{SCENARIO_NAME}.visitant.{clean_name}.log")

    return None

def run_verify(content):
    """Parses and executes a VERIFY block."""
    config = parse_kv_block(content)

    title = config.get('title', 'Untitled Verification')
    pattern = config.get('contains')
    frame = config.get('frame', 'General')
    subject = config.get('subject')

    # If frame is default, try to infer from subject
    if frame == 'General' and subject:
        frame = subject

    print(f"[DIRECTOR] Verifying: {title} ({frame})")

    filepath = resolve_log_source(config)
    if not filepath:
        print("  -> Error: No 'File' or 'Subject' specified for verification.")
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

    log_observation(title, frame, passed, details, "State")

    if not passed:
        print_report()
        cleanup_graceful()
        sys.exit(1)

def run_await(content):
    """Parses and executes an AWAIT block (blocking verification)."""
    config = parse_kv_block(content)

    title = config.get('title', 'Untitled Event')
    pattern = config.get('contains')
    frame = config.get('frame', 'General')
    subject = config.get('subject')
    timeout_ms = int(config.get('timeout', 30000))

    # If frame is default, try to infer from subject
    if frame == 'General' and subject:
        frame = subject

    print(f"[DIRECTOR] Awaiting: {title} ({frame}) [Timeout: {timeout_ms}ms]")

    filepath = resolve_log_source(config)
    if not filepath:
        print("  -> Error: No 'File' or 'Subject' specified for await.")
        sys.exit(1)

    if not os.path.isabs(filepath):
        full_path = os.path.join(REPO_ROOT, filepath)
    else:
        full_path = filepath

    start_time = time.time()
    passed = False
    details = ""

    # Poll loop
    while (time.time() - start_time) * 1000 < timeout_ms:
        if os.path.exists(full_path):
            with open(full_path, 'r', errors='replace') as f:
                # Optimized: We could seek, but for now reading whole file is safer for patterns
                # occurring at any time. Given log sizes are small for encounters, this is fine.
                log_content = f.read()
                if pattern and pattern in log_content:
                    passed = True
                    details = f"Event observed: '{pattern}'"
                    print(f"  -> PASSED: Event observed in {int((time.time() - start_time)*1000)}ms.")
                    break
        time.sleep(0.5)

    if not passed:
        details = f"Timeout waiting for '{pattern}' in {os.path.basename(filepath)}"
        print(f"  -> FAILED: {details}")

    log_observation(title, frame, passed, details, "Event")

    if not passed:
        print_report()
        cleanup_graceful()
        sys.exit(1)

# --- Parser ---

def resolve_includes(content, base_path, depth=0):
    """Recursively resolves [#include](path) directives."""
    if depth > 10:
        print("Error: Include depth limit exceeded (cycle detected?).")
        sys.exit(1)

    def replacer(match):
        rel_path = match.group(1)
        # Verify it's a relative path to avoid confusing semantics
        full_path = os.path.normpath(os.path.join(base_path, rel_path))

        if not os.path.exists(full_path):
            print(f"Error: Included file not found: {full_path}")
            sys.exit(1)

        print(f"[DIRECTOR] Including: {rel_path}")
        with open(full_path, 'r') as f:
            included_text = f.read()

        # Recurse with the directory of the included file as the new base
        return resolve_includes(included_text, os.path.dirname(full_path), depth + 1)

    # Regex: literal [#include](...)
    pattern = re.compile(r'\[#include\]\((.*?)\)')
    return pattern.sub(replacer, content)

def parse_frontmatter(text):
    """Extracts YAML frontmatter from the start of the text."""
    global SCENARIO_METADATA

    # Matches yaml block at start of file: --- ... ---
    pattern = re.compile(r'^---\n(.*?)\n---', re.DOTALL)
    match = pattern.match(text)

    if match:
        content = match.group(1)
        # Simple Key: Value parser
        try:
            for line in content.splitlines():
                if ':' in line:
                    key, val = line.split(':', 1)
                    SCENARIO_METADATA[key.strip()] = val.strip()

            if SCENARIO_METADATA:
                print(f"[DIRECTOR] Loaded metadata: {SCENARIO_METADATA}")
        except Exception as e:
            print(f"[DIRECTOR] Warning: Invalid Frontmatter Parsing: {e}")

        # Return text without the frontmatter
        return text[match.end():]

    return text

def parse_and_execute(filepath):
    print(f"[DIRECTOR] Loading scenario: {filepath}")

    with open(filepath, 'r') as f:
        text = f.read()

    # Parse Frontmatter
    text = parse_frontmatter(text)

    # Resolve Includes (Pre-processor)
    text = resolve_includes(text, os.path.dirname(os.path.abspath(filepath)))

    # Reify Scenario (Teleplay)
    teleplay_path = os.path.join(VIVARIUM_DIR, f"encounter.{SCENARIO_NAME}.teleplay.md")
    try:
        with open(teleplay_path, 'w') as f:
            f.write(text)
        print(f"[DIRECTOR] Reified scenario (Teleplay) saved to: {teleplay_path}")
    except Exception as e:
        print(f"[DIRECTOR] Warning: Could not save teleplay: {e}")

    # Parse Code Blocks
    pattern = re.compile(r'^```([\w-]+)(?:[ \t]+(.*?))?\n(.*?)```', re.MULTILINE | re.DOTALL)

    pos = 0
    while True:
        match = pattern.search(text, pos)
        if not match:
            break

        block_type = match.group(1).lower()
        block_args = match.group(2).strip() if match.group(2) else ""
        block_content = match.group(3)

        print(f"\n--- STEP: {block_type.upper()} {block_args} ---")

        if block_type == 'bash-export':
            run_bash_export(block_content)
        elif block_type == 'bash':
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
        elif block_type == 'await':
            run_await(block_content)
        elif block_type == 'wait':
            try:
                ms = int(block_content.strip())
                print(f"[DIRECTOR] Waiting {ms}ms...")
                time.sleep(ms / 1000.0)
            except:
                print("[DIRECTOR] Invalid Wait")

        pos = match.end()

    print_report()
    cleanup_graceful()
    # Check if any failure occurred
    if any(not entry['passed'] for entry in evidence_log):
        print("\n[DIRECTOR] SCENARIO FAILED.")
        sys.exit(1)

    print("\n[DIRECTOR] SCENARIO COMPLETED SUCCESSFULLY.")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: director.py <scenario.md>")
        sys.exit(1)

    scenario_file = sys.argv[1]
    if not os.path.exists(scenario_file):
        print(f"Error: File {scenario_file} not found.")
        sys.exit(1)

    SCENARIO_NAME = os.path.splitext(os.path.basename(scenario_file))[0]
    ENV["SCENARIO_NAME"] = SCENARIO_NAME
    os.environ["SCENARIO_NAME"] = SCENARIO_NAME

    try:
        parse_and_execute(scenario_file)
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        print_report()
        cleanup_graceful()
        sys.exit(1)
