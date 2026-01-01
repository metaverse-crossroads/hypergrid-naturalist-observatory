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
import uuid

# --- Configuration ---
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
# SCRIPT_DIR is observatory/
# REPO_ROOT is one level up
REPO_ROOT = os.path.dirname(SCRIPT_DIR)

VIVARIUM_DIR = os.path.join(REPO_ROOT, "vivarium")
MIMIC_DLL = os.path.join(VIVARIUM_DIR, "mimic", "Mimic.dll")
SEQUENCER_DLL = os.path.join(VIVARIUM_DIR, "sequencer", "Sequencer.dll")
ENSURE_DOTNET = os.path.join(REPO_ROOT, "instruments", "substrate", "ensure_dotnet.sh")

MIMIC_SCRIPT = os.path.join(REPO_ROOT, "instruments", "mimic", "run_visitant.sh")
BENTHIC_SCRIPT = os.path.join(REPO_ROOT, "species", "benthic", "0.1.0", "run_visitant.sh")
HIPPOLYZER_CLIENT_SCRIPT = os.path.join(REPO_ROOT, "species", "hippolyzer-client", "0.17.0", "run_visitant.sh")
REST_CONSOLE_WRAPPER = os.path.join(REPO_ROOT, "species", "opensim-core", "rest-console", "connect_opensim_console_session.sh")

# Simulant Configuration Map
SIMULANT_FQN = os.environ.get("SIMULANT_FQN", "opensim-core-0.9.3")

SIMULANT_CONFIGS = {
    "opensim-core-0.9.3": {
        "bin_dir": os.path.join(VIVARIUM_DIR, "opensim-core-0.9.3", "bin"),
        "observatory_dir": os.path.join(VIVARIUM_DIR, "opensim-core-0.9.3", "observatory"),
        "ini_file": os.path.join(REPO_ROOT, "species", "opensim-core", "standalone-observatory-sandbox.ini"),
        "exe": "OpenSim.dll",
        "tag_ua": "species/opensim-core/0.9.3"
    },
    "opensim-ngc-0.9.3": {
        "bin_dir": os.path.join(VIVARIUM_DIR, "opensim-ngc-0.9.3", "build", "Release"),
        "observatory_dir": os.path.join(VIVARIUM_DIR, "opensim-ngc-0.9.3", "observatory"),
        "ini_file": os.path.join(REPO_ROOT, "species", "opensim-core", "standalone-observatory-sandbox.ini"), # Reusing INI for now? Check if valid.
        "exe": "OpenSim.dll",
        "tag_ua": "species/opensim-ngc/0.9.3"
    }
}

if SIMULANT_FQN not in SIMULANT_CONFIGS:
    print(f"[DIRECTOR] Warning: Unknown Simulant '{SIMULANT_FQN}'. Defaulting to opensim-core-0.9.3 config structure (best effort).")
    # Best effort fallback
    SIMULANT_CONFIGS[SIMULANT_FQN] = {
        "bin_dir": os.path.join(VIVARIUM_DIR, SIMULANT_FQN, "bin"),
        "observatory_dir": os.path.join(VIVARIUM_DIR, SIMULANT_FQN, "observatory"),
        "ini_file": os.path.join(REPO_ROOT, "species", "opensim-core", "standalone-observatory-sandbox.ini"),
        "exe": "OpenSim.dll",
        "tag_ua": f"species/{SIMULANT_FQN}"
    }

SIMULANT_CFG = SIMULANT_CONFIGS[SIMULANT_FQN]

# Backwards compatibility globals
OPENSIM_DIR = SIMULANT_CFG["bin_dir"]
OBSERVATORY_DIR = SIMULANT_CFG["observatory_dir"]
OPENSIM_BIN = os.path.join(OPENSIM_DIR, SIMULANT_CFG["exe"])

# --- Global State ---
evidence_log = []
SCENARIO_NAME = "unknown"
SCENARIO_METADATA = {} # Parsed from Frontmatter
ACTORS = {}
next_benthic_port = 12000
SIGINT_COUNT = 0
opensim_proc = None
opensim_console_interface = None # Abstraction for sending commands
active_sensors = [] # List of active Sensor objects

# --- Exceptions ---
class DirectorError(Exception):
    """Exception raised for errors during scenario execution that require cleanup."""
    pass

# --- Query Engine ---

class AttrDict(dict):
    """
    Dictionary subclass that allows access to keys as attributes.
    Nested dictionaries are also converted to AttrDicts.
    """
    def __getattr__(self, item):
        try:
            value = self[item]
            if isinstance(value, dict):
                return AttrDict(value)
            return value
        except KeyError:
            # Return None for missing keys to allow safe filtering
            return None

def matches(text, pattern):
    """Helper for regex matching in queries."""
    if not isinstance(text, str):
        return False
    return bool(re.search(pattern, text))

def evaluate_query(query, line):
    """Evaluates a python expression against a log line."""
    line = line.strip()
    if not line:
        return False

    try:
        data = json.loads(line)
        entry = AttrDict(data)
    except json.JSONDecodeError:
        entry = line # Fallback to raw string

    context = {
        "entry": entry,
        "matches": matches,
        "re": re,
        "math": __import__("math")
    }

    try:
        # Use eval with restricted globals/locals
        return eval(query, {}, context)
    except Exception as e:
        # Log explicit evaluation errors (syntax, name errors, etc.)
        # We truncate line content if it's too long
        trunc_line = (line[:75] + '..') if len(line) > 75 else line
        print(f"[DIRECTOR] ERROR: Query Evaluation Failed: {e}")
        print(f"  Query: {query}")
        print(f"  Line: {trunc_line}")
        return False

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
        # No cleanup needed here as nothing started yet
        sys.exit(1)

ENV = get_dotnet_env()
ENV["OPENSIM_DIR"] = OPENSIM_DIR
ENV["OBSERVATORY_DIR"] = OBSERVATORY_DIR
ENV["VIVARIUM_ROOT"] = VIVARIUM_DIR
ENV["SIMULANT_FQN"] = SIMULANT_FQN

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
            try:
                self.daemon_proc.terminate()
                try:
                    self.daemon_proc.wait(timeout=2)
                except:
                    self.daemon_proc.kill()
            except Exception as e:
                 print(f"[DIRECTOR] Error closing REST Console Daemon: {e}")
            finally:
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
        try:
            opensim_console_interface.close()
        except Exception as e:
            print(f"[DIRECTOR] Error closing console interface: {e}")

    # 1. Terminate Visitants (Reverse order of creation usually good)
    for p, name in reversed(procs):
        if p == opensim_proc: continue # Skip OpenSim for now

        if p.poll() is None:
            print(f"[DIRECTOR] Terminating {name}...")
            try:
                p.terminate()
                try:
                    p.wait(timeout=2)
                except subprocess.TimeoutExpired:
                    print(f"[DIRECTOR] Killing {name}...")
                    p.kill()
            except Exception as e:
                print(f"[DIRECTOR] Error terminating {name}: {e}")

    # 2. Terminate OpenSim
    if opensim_proc and opensim_proc.poll() is None:
        print("[DIRECTOR] Terminating OpenSim...")
        try:
            opensim_proc.terminate()
            try:
                opensim_proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                 print("[DIRECTOR] Killing OpenSim...")
                 opensim_proc.kill()
        except Exception as e:
            print(f"[DIRECTOR] Error terminating OpenSim: {e}")

    # 3. Stop Async Sensors
    for sensor in active_sensors:
        sensor.stop()

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

# --- Sensors ---

class Sensor(threading.Thread):
    def __init__(self, title, subject, filepath, pattern, action, payload, query=None):
        super().__init__()
        self.title = title
        self.subject = subject
        self.filepath = filepath
        self.pattern = pattern
        self.query = query
        self.action = action # 'abort' or 'log'
        self.payload = payload
        self.daemon = True
        self.running = True
        self._stop_event = threading.Event()

    def stop(self):
        self.running = False
        self._stop_event.set()

    def run(self):
        print(f"[DIRECTOR] Sensor '{self.title}' started on {self.subject}...")

        # Wait for file to appear
        while self.running and not os.path.exists(self.filepath):
            if self._stop_event.wait(1.0):
                return

        if not self.running:
            return

        try:
            # Open file and tail
            with open(self.filepath, 'r') as f:
                # Seek to end initially? Or read from start?
                # Requirement: "if this descriptor block matches at any time during filming"
                # If we start sensor late, we might miss early logs.
                # But usually sensors are defined at top.
                # Let's read from current position (which is start if just opened).
                # But if we read whole file every time, it's slow.
                # `tail -f` behavior: read up to end, then wait.

                # Check existing content first?
                # "if this descriptor block matches at any time" implies we should scan existing content too.
                # But if file is huge?
                # Let's assume we scan everything.

                while self.running:
                    line = f.readline()
                    if line:
                        triggered = False
                        if self.query:
                            if evaluate_query(self.query, line):
                                triggered = True
                        elif self.pattern:
                            if self.pattern in line:
                                triggered = True

                        if triggered:
                            self.trigger(line)
                            if self.action == 'abort':
                                break # Stop sensor after abort trigger
                    else:
                        if self._stop_event.wait(0.5):
                            break
                        # Reset file reading? No, readline handles it if file grows.
                        # But we need to clear EOF state? Python file object usually handles this.
                        # Just loop.
                        pass
        except Exception as e:
            print(f"[DIRECTOR] Sensor '{self.title}' error: {e}")

    def trigger(self, line):
        trigger_desc = f"Query '{self.query}'" if self.query else f"Pattern '{self.pattern}'"
        print(f"[DIRECTOR] Sensor '{self.title}' TRIGGERED by {trigger_desc}")

        if self.action == 'abort':
            print(f"[DIRECTOR] SENSOR ABORT: {self.payload}")
            log_observation(self.title, self.subject, False, f"ABORT TRIGGERED: {self.payload} ({trigger_desc})", "Sensor")

            # Trigger graceful shutdown via signal
            os.kill(os.getpid(), signal.SIGINT)

        elif self.action == 'log':
            # Try to parse payload as JSON
            details = self.payload
            try:
                data = json.loads(self.payload)
                # If JSON, maybe format it nicely?
                # Or just store it.
                details = json.dumps(data)
            except:
                pass

            print(f"[DIRECTOR] SENSOR LOG: {details}")
            log_observation(self.title, self.subject, False, f"SENSOR LOG: {details} ({trigger_desc})", "Sensor")

        elif self.action == 'alert':
            print(f"[DIRECTOR] SENSOR ALERT: {self.payload}")
            # Send alert to console
            if opensim_console_interface:
                opensim_console_interface.send(f"alert {self.payload}")
            else:
                print(f"[DIRECTOR] CRITICAL ERROR: Async Sensor triggered ALERT but OpenSim Console is NOT connected. Alert lost: {self.payload}")

            log_observation(self.title, self.subject, True, f"SENSOR ALERT: {self.payload} ({trigger_desc})", "Sensor")


# --- Block Handlers ---

def run_async_sensor(content):
    """Parses and starts an ASYNC-SENSOR block."""
    config = parse_kv_block(content)

    title = config.get('title', 'Untitled Sensor')
    subject = config.get('subject')
    pattern = config.get('contains')
    query = config.get('query')

    # Determine action
    action = None
    payload = None

    # Check for director#abort or director#log
    # parse_kv_block lowercases keys.
    if 'director#abort' in config:
        action = 'abort'
        payload = config['director#abort']
    elif 'director#log' in config:
        action = 'log'
        payload = config['director#log']
    elif 'director#alert' in config:
        action = 'alert'
        payload = config['director#alert']

    if not subject or (not pattern and not query) or not action:
        print("[DIRECTOR] Error: Invalid Async Sensor configuration. Requires Subject, Contains (or Query), and director#abort/log/alert.")
        return # Or raise Error?

    filepath = resolve_log_source(config)
    if not filepath:
        print(f"[DIRECTOR] Error: Could not resolve file for subject '{subject}'")
        return

    if not os.path.isabs(filepath):
        filepath = os.path.join(REPO_ROOT, filepath)

    sensor = Sensor(title, subject, filepath, pattern, action, payload, query=query)
    active_sensors.append(sensor)
    sensor.start()


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
        raise DirectorError("Bash block execution failed")

def run_bash(content):
    """Executes a bash script block."""
    print(f"[DIRECTOR] Executing BASH block...")
    try:
        subprocess.run(["bash", "-c", content], env=ENV, cwd=REPO_ROOT, check=True)
    except subprocess.CalledProcessError as e:
        print(f"Error in BASH block: {e}")
        raise DirectorError("Bash block execution failed")

def inject_sql(db_path, sql_script):
    """Injects SQL script into DB, statement by statement, ignoring errors."""
    if not os.path.exists(db_path):
        print(f"ERROR: DB {db_path} not found. CRITICAL FAILURE.")
        raise DirectorError(f"Database {db_path} not found")

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

def run_legacy_cast(content):
    """Parses JSON content to inject users via Sequencer."""
    print(f"[DIRECTOR] Executing LEGACY CAST block...")
    try:
        cast_list = json.loads(content)

        # Use OBSERVATORY_DIR (which maps to correct species folder)
        dbs = [
            os.path.join(OBSERVATORY_DIR, "userprofiles.db"),
            os.path.join(OBSERVATORY_DIR, "inventory.db"),
            os.path.join(OBSERVATORY_DIR, "auth.db")
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
        raise DirectorError("Invalid JSON in CAST block")
    except Exception as e:
        print(f"Error in CAST block: {e}")
        raise DirectorError("CAST block execution failed")

def check_user_exists(first, last):
    """Checks if a user exists in the userprofiles.db."""
    db_path = os.path.join(OBSERVATORY_DIR, "userprofiles.db")
    if not os.path.exists(db_path):
        return False
    try:
         # Use read-only mode if possible to avoid locking
         uri = f"file:{db_path}?mode=ro"
         with sqlite3.connect(uri, uri=True) as conn:
             cursor = conn.cursor()
             cursor.execute("SELECT PrincipalID FROM UserAccounts WHERE FirstName=? AND LastName=?", (first, last))
             return cursor.fetchone() is not None
    except Exception as e:
         # print(f"DB Check Error: {e}")
         return False

def run_cast(content):
    """Parses JSON content to create users via OpenSim Console."""
    print(f"[DIRECTOR] Executing CAST block (create user strategy)...")

    if not opensim_console_interface:
         print("[DIRECTOR] Error: OpenSim must be running to execute CAST block (create user strategy).")
         raise DirectorError("OpenSim not running for CAST block")

    try:
        cast_list = json.loads(content)

        for actor in cast_list:
            first = actor.get("First", "Test")
            last = actor.get("Last", "User")
            password = actor.get("Password", "secret")
            uuid = actor.get("UUID", "00000000-0000-0000-0000-000000000000")
            email = actor.get("Email", "test@example.com")
            model = actor.get("Model", "default")
            species = actor.get("Species", "Mimic").lower()

            full_name = f"{first} {last}"
            ACTORS[full_name] = actor # Store full actor config

            print(f"  -> Casting {first} {last} ({uuid}) as {species}")

            # Command: create user <first> <last> <pass> <email> <uuid> <model>
            command = f"create user {first} {last} {password} {email} {uuid} {model}"
            opensim_console_interface.send(command)

            # Verification loop
            print(f"  -> Verifying creation of {first} {last}...")
            start_time = time.time()
            found = False
            while time.time() - start_time < 10: # 10s timeout
                if check_user_exists(first, last):
                    found = True
                    print(f"  -> Verified: {first} {last} exists in DB.")
                    break
                time.sleep(0.5)

            if not found:
                 print(f"  -> Warning: verification timed out for {first} {last}. It might still be created later.")
                 raise DirectorError(f"Failed to verify user creation for {first} {last}")

    except json.JSONDecodeError as e:
        print(f"Invalid JSON in CAST block: {e}")
        raise DirectorError("Invalid JSON in CAST block")
    except Exception as e:
        print(f"Error in CAST block: {e}")
        raise DirectorError("CAST block execution failed")

def run_opensim(content):
    """Manages OpenSim process."""
    global opensim_proc
    global opensim_console_interface

    if opensim_proc is None or opensim_proc.poll() is not None:
        print(f"[DIRECTOR] Starting OpenSim ({SIMULANT_FQN})...")

        # Determine Console Mode
        console_mode = os.environ.get("OPENSIM_CONSOLE", "local").lower()
        use_rest = console_mode == "rest"

        if use_rest:
            print("[DIRECTOR] Mode: REST Console")
            # Inject REST configuration
            rest_ini_path = os.path.join(OBSERVATORY_DIR, "RestConsole.ini")
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
            "dotnet", SIMULANT_CFG["exe"],
            f"-inifile={SIMULANT_CFG['ini_file']}",
            f"-inidirectory={OBSERVATORY_DIR}"
        ]

        # Log file for Console output
        log_file = open(os.path.join(OBSERVATORY_DIR, "opensim_console.log"), "w")

        # Configure the predictable Encounter Log path
        encounter_log = os.path.join(VIVARIUM_DIR, f"encounter.{SCENARIO_NAME}.territory.log")

        proc_env = ENV.copy()
        proc_env["OPENSIM_ENCOUNTER_LOG"] = encounter_log
        proc_env["TAG_UA"] = SIMULANT_CFG["tag_ua"]

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

                    raise DirectorError(f"OpenSim exited abnormally with code {exit_code}")
        elif line.startswith("#"):
            pass # Ignore comments
        else:
            if opensim_console_interface:
                opensim_console_interface.send(line)
            else:
                 print("[DIRECTOR] CRITICAL ERROR: Attempted to send command to OpenSim but interface is NOT initialized.")
                 raise DirectorError("OpenSim Console not initialized when command requested.")

mimic_sessions = {}

def get_mimic_session(name, strict=False):
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
         # NOTE: We might want to make this strict for 'actor' blocks
         print(f"[DIRECTOR] Warning: {name} not found in CAST.")
         if strict: assert False
         actor_config = {"First": "Test", "Last": "User", "Species": "mimic"}
    else:
         actor_config = ACTORS[name]

    species = actor_config.get("Species", "mimic").lower()
    print(f"[DIRECTOR] Spawning {species.capitalize()}: {name}")

    # Predictable log path: encounter.{SCENARIO>.visitant.{clean_name}.log
    clean_name = name.replace(" ", "")
    log_path = os.path.join(VIVARIUM_DIR, f"encounter.{SCENARIO_NAME}.visitant.{clean_name}.log")

    log_file = open(log_path, "w")

    proc_env = ENV.copy()
    # Remove encounter log env var to avoid confusion, though stdout capture is main method
    if "MIMIC_ENCOUNTER_LOG" in proc_env:
        del proc_env["MIMIC_ENCOUNTER_LOG"]

    # Derive TAG_UA & TAG_SOURCE_URL
    repo_base = "https://github.com/metaverse-crossroads/hypergrid-naturalist-observatory/blob/main"

    if species == "benthic":
        tag_ua = "benthic/0.1.0"
        source_url = f"{repo_base}/species/benthic/0.1.0/deepsea_client.rs"
    elif species == "hippolyzer-client":
        tag_ua = "hippolyzer-client/0.17.0"
        source_url = f"{repo_base}/species/hippolyzer-client/0.17.0/deepsea_client.py"
    else:
        tag_ua = "instruments/mimic"
        # Mimic is the compiled form of LibreMetaverse DeepSeaClient.cs
        source_url = f"{repo_base}/species/libremetaverse/src/DeepSeaClient.cs"

    proc_env["TAG_UA"] = tag_ua
    proc_env["TAG_SOURCE_URL"] = source_url

    if species == "benthic":
        # Allocate ports
        global next_benthic_port
        ui_port = next_benthic_port
        core_port = next_benthic_port + 1
        next_benthic_port += 2

        cmd = [
            BENTHIC_SCRIPT,
            "--ui-port", str(ui_port),
            "--core-port", str(core_port),
        ]

        cwd = os.path.dirname(BENTHIC_SCRIPT)

    elif species == "hippolyzer-client":
        cmd = [HIPPOLYZER_CLIENT_SCRIPT]

        cwd = os.path.dirname(HIPPOLYZER_CLIENT_SCRIPT)

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

def run_mimic_block(name, content, strict=False):
    if strict and name not in ACTORS:
        print(f"[DIRECTOR] Error: Actor '{name}' not found in casting call.")
        raise DirectorError(f"Actor '{name}' not found in casting call")

    p = get_mimic_session(name, strict=strict)

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
                raise DirectorError(f"Connection to actor {name} lost (BrokenPipe)")
        else:
            print(f"[DIRECTOR] CRITICAL ERROR: p.stdin with {name} not available.")
            raise DirectorError(f"Input stream for actor {name} is unavailable.")


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

        if subject.lower() == "simulant":
             return os.path.join(OBSERVATORY_DIR, "opensim_console.log")

        # Assume it's a Visitant (Subject: Visitant One)
        clean_name = subject.replace(" ", "")
        return os.path.join(VIVARIUM_DIR, f"encounter.{SCENARIO_NAME}.visitant.{clean_name}.log")

    return None

def run_verify(content):
    """Parses and executes a VERIFY block."""
    config = parse_kv_block(content)

    title = config.get('title', 'Untitled Verification')
    pattern = config.get('contains')
    query = config.get('query')
    frame = config.get('frame', 'General')
    subject = config.get('subject')

    # If frame is default, try to infer from subject
    if frame == 'General' and subject:
        frame = subject

    print(f"[DIRECTOR] Verifying: {title} ({frame})")

    filepath = resolve_log_source(config)
    if not filepath:
        print("  -> Error: No 'File' or 'Subject' specified for verification.")
        raise DirectorError("No 'File' or 'Subject' specified for verification")

    # Handle paths relative to repo root if not absolute
    if not os.path.isabs(filepath):
        full_path = os.path.join(REPO_ROOT, filepath)
    else:
        full_path = filepath

    passed = False
    details = ""

    if os.path.exists(full_path):
        with open(full_path, 'r', errors='replace') as f:
            if query:
                # Line-by-line query evaluation
                found = False
                for line in f:
                    if evaluate_query(query, line):
                        found = True
                        break

                if found:
                    passed = True
                    details = f"Query matched in {os.path.basename(filepath)}"
                    print(f"  -> PASSED: Query '{query}' matched.")
                else:
                    details = f"Query '{query}' NOT matched in {os.path.basename(filepath)}"
                    print(f"  -> FAILED: {details}")

            elif pattern:
                # Basic string search
                log_content = f.read()
                if pattern in log_content:
                    passed = True
                    details = f"Found '{pattern}' in {os.path.basename(filepath)}"
                    print(f"  -> PASSED: Found expected evidence.")
                else:
                    details = f"Pattern '{pattern}' NOT found in {os.path.basename(filepath)}"
                    print(f"  -> FAILED: {details}")
            else:
                print("  -> Error: Neither 'Contains' nor 'Query' specified.")
                raise DirectorError("Missing verification criteria")
    else:
        details = f"File {filepath} does not exist."
        print(f"  -> FAILED: {details}")

    log_observation(title, frame, passed, details, "State")

    if not passed:
        raise DirectorError("Verification failed")

def run_await(content):
    """Parses and executes an AWAIT block (blocking verification)."""
    config = parse_kv_block(content)

    title = config.get('title', 'Untitled Event')
    pattern = config.get('contains')
    query = config.get('query')
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
        raise DirectorError("No 'File' or 'Subject' specified for await")

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
                if query:
                    # Line-by-line query evaluation
                    for line in f:
                        if evaluate_query(query, line):
                            passed = True
                            details = f"Event observed via query: '{query}'"
                            print(f"  -> PASSED: Event observed in {int((time.time() - start_time)*1000)}ms.")
                            break
                elif pattern:
                    log_content = f.read()
                    if pattern in log_content:
                        passed = True
                        details = f"Event observed: '{pattern}'"
                        print(f"  -> PASSED: Event observed in {int((time.time() - start_time)*1000)}ms.")

                if passed:
                    break
        time.sleep(0.5)

    if not passed:
        criteria = f"Query '{query}'" if query else f"Pattern '{pattern}'"
        details = f"Timeout waiting for {criteria} in {os.path.basename(filepath)}"
        print(f"  -> FAILED: {details}")

    log_observation(title, frame, passed, details, "Event")

    if not passed:
        raise DirectorError(f"Await timeout: {details}")

# --- Parser ---

def mask_comments(text):
    mask_map = {}
    def mask_replacer(match):
        token = f"__COMMENT_MASK_{uuid.uuid4().hex}__"
        mask_map[token] = match.group(0)
        return token
    # Match <!-- ... --> non-greedy
    pattern = re.compile(r'<!--((?!-->).)*-->', re.DOTALL)
    masked_text = pattern.sub(mask_replacer, text)
    return masked_text, mask_map

def unmask_comments(text, mask_map):
    for token, comment in mask_map.items():
        text = text.replace(token, comment)
    return text

def resolve_includes(content, base_path, depth=0):
    """Recursively resolves [#include](path) directives."""
    if depth > 10:
        print("Error: Include depth limit exceeded (cycle detected?).")
        # Recursion depth exceeded, better to hard fail
        sys.exit(1)

    # 1. Mask comments to prevent processing commented-out includes
    content, mask_map = mask_comments(content)

    def replacer(match):
        rel_path = match.group(1)
        # 1. Try Simulant-specific path: foo.opensim-core-0.9.3.md
        # Split extension
        root, ext = os.path.splitext(rel_path)
        simulant_rel_path = f"{root}.{SIMULANT_FQN}{ext}"

        full_path_simulant = os.path.normpath(os.path.join(base_path, simulant_rel_path))
        full_path_default = os.path.normpath(os.path.join(base_path, rel_path))

        target_path = None
        if os.path.exists(full_path_simulant):
            target_path = full_path_simulant
            print(f"[DIRECTOR] Including (Simulant Resolved): {simulant_rel_path}")
        elif os.path.exists(full_path_default):
            target_path = full_path_default
            print(f"[DIRECTOR] Including (Default): {rel_path}")
        else:
            print(f"Error: Included file not found: {rel_path} (checked {full_path_simulant} and {full_path_default})")
            # We are inside a regex sub callback, so raising Exception is messy but possible.
            # However, resolve_includes happens before execution, so cleaning up is not critical unless early processes?
            # But usually no processes started yet.
            sys.exit(1)

        with open(target_path, 'r') as f:
            included_text = f.read()

        # Recurse with the directory of the included file as the new base
        resolved_content = resolve_includes(included_text, os.path.dirname(target_path), depth + 1)

        # Wrap with metadata
        return f"<!-- [#include]({rel_path}) -->\n<!-- SOURCE: {target_path} -->\n{resolved_content}\n<!-- END SOURCE: {target_path} -->"

    # Regex: literal [#include](...)
    pattern = re.compile(r'\[#include\]\((.*?)\)')
    content = pattern.sub(replacer, content)

    # 2. Unmask comments
    content = unmask_comments(content, mask_map)

    return content

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

            # Handle Casting Call in Frontmatter if we added it?
            # For now keeping it simple as per plan.
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
        elif block_type == 'legacy-cast' or block_type == 'cast-legacy':
            run_legacy_cast(block_content)
        elif block_type == 'opensim' or block_type == 'territory':
            run_opensim(block_content)
        elif block_type == 'mimic':
            name = block_args if block_args else "Visitant"
            run_mimic_block(name, block_content, strict=False)
        elif block_type == 'actor':
            name = block_args if block_args else "Visitant"
            run_mimic_block(name, block_content, strict=True)
        elif block_type == 'verify':
            run_verify(block_content)
        elif block_type == 'await':
            run_await(block_content)
        elif block_type == 'async-sensor':
            run_async_sensor(block_content)
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
    if not os.environ.get("OBSERVATORY_PROTOCOL_VERIFIED"):
        print("=" * 79)
        print("WARNING: DIRECTOR INVOKED DIRECTLY")
        print("This pattern is forbidden and cannot be used to verify correct behavior.")
        print("Please use the Makefile or 'observatory/run_encounter.sh' wrapper.")
        print("=" * 79)

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
    except (DirectorError, SystemExit) as e:
        # Catch explicit SystemExit as well to ensure cleanup,
        # unless it was a normal exit(0) which is caught inside parse_and_execute's flow (no, exit(0) raises SystemExit)
        # But wait, sys.exit(0) is a SystemExit.
        # If it is exit 0, we don't need to panic, but we should ensure cleanup (which is done in parse_and_execute success path).
        # But if it interrupts parse_and_execute, we need to clean up.

        # Check if it's a success exit or not
        code = 0
        if isinstance(e, SystemExit):
            code = e.code

        if isinstance(e, DirectorError) or code != 0:
             print(f"\n[DIRECTOR] Execution interrupted: {e}")
             print_report()
             cleanup_graceful()
             sys.exit(1)
        # If exit(0), we assume cleanup was done or not needed?
        # Actually parse_and_execute calls cleanup_graceful at end.
    except Exception as e:
        print(f"\n[DIRECTOR] An unexpected error occurred: {e}")
        import traceback
        traceback.print_exc()
        print_report()
        cleanup_graceful()
        sys.exit(1)
