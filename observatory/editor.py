#!/usr/bin/env python3
import sys
import os
import json
import fnmatch
from datetime import datetime

# Configuration
LOG_DIR = "vivarium"

def parse_log_line(filename, line):
    """
    Attempts to parse a line as a Naturalist JSON fragment.
    Returns a normalized dict if valid, None if carrier wave noise.
    """
    line = line.strip()
    # Fast reject carrier wave
    if not line.startswith("{") or not line.endswith("}"):
        return None

    try:
        entry = json.loads(line)
        
        # Schema Validation
        if "at" not in entry:
            print("SKIPPING JSON PARSEABLE BUT NOT ATed", entry, line)
            return None

        # 1. Normalize Timestamp
        # Handle 'Z' for Python < 3.11 robustness
        ts_str = entry["at"].replace('Z', '+00:00') 
        dt = datetime.fromisoformat(ts_str)

        # 2. Disambiguate Actor via Filename Context
        # "via": "Visitant" is ambiguous; "via": "Ranger" is not.
        actor = entry.get("via", "Unknown")
        fname = os.path.basename(filename)
        
        if "visitant." in fname.lower():
            # Extract specific identity from filename (e.g., encounter...VisitantOne.log)
            # Heuristic: Split by '.' and look for the part after 'visitant'
            parts = fname.split('.')
            if len(parts) >= 4:
                # "VisitantOne" -> "Visitant One"
                raw_name = parts[3]
                actor = re_insert_space(raw_name)
        elif "territory" in fname.lower():
            actor = "Territory"

        return {
            "iso_time": dt.isoformat(), # Store as string for JSON serialization later
            "timestamp": dt.timestamp(), # Store as float for sorting
            "actor": actor,
            "system": entry.get("sys", "?"),
            "signal": entry.get("sig", "?"),
            "payload": entry.get("val", ""),
            "source_log": fname
        }

    except (json.JSONDecodeError, ValueError):
        return None

def re_insert_space(name):
    # Simple helper to turn "VisitantOne" into "Visitant One" if needed
    import re
    return re.sub(r"([a-z])([A-Z])", r"\1 \2", name)

def generate_ascii_table(events):
    if not events:
        return ["No events found."]
        
    start_time = events[0]['timestamp']
    lines = []
    
    # Header
    lines.append(f"| {'Time (T+)':<10} | {'Actor':<15} | {'System':<10} | {'Signal':<22} | {'Payload':<35} |")
    lines.append(f"|{'-'*12}|{'-'*17}|{'-'*12}|{'-'*24}|{'-'*37}|")
    
    for e in events:
        delta = e['timestamp'] - start_time
        t_plus = f"{delta:.3f}s"
        
        # Truncate payload for ASCII display
        payload = e['payload']
        if not isinstance(payload, str): payload = str(payload)
        if len(payload) > 35 + 40:
            payload = payload[:32+40] + "..."
            
        lines.append(f"| {t_plus:<10} | {e['actor']:<15} | {e['system']:<10} | {e['signal']:<22} | {payload:<35} |")
        
    return lines

def main():
    if len(sys.argv) < 2:
        print("Usage: editor.py <scenario_path>")
        sys.exit(1)

    scenario_path = sys.argv[1]
    scenario_name = os.path.splitext(os.path.basename(scenario_path))[0]

    # Output file: encounter.<scenario>.dailies.json
    dailies_output = os.path.join(LOG_DIR, f"encounter.{scenario_name}.dailies.json")
    # Input filter: encounter.<scenario>.*.log
    log_pattern = f"encounter.{scenario_name}.*.log"

    all_events = []
    
    # 1. Harvest
    if not os.path.exists(LOG_DIR):
        print(f"[EDITOR] Error: {LOG_DIR} not found.")
        sys.exit(1)

    print(f"[EDITOR] Scanning {LOG_DIR} for Field Marks (Scenario: {scenario_name})...")
    
    match_count = 0
    for f in os.listdir(LOG_DIR):
        if fnmatch.fnmatch(f, log_pattern):
            match_count += 1
            path = os.path.join(LOG_DIR, f)
            print("PARSE", path, file=sys.stderr)
            with open(path, 'r', errors='replace') as log_file:
                for line in log_file:
                    event = parse_log_line(path, line)
                    if event:
                        all_events.append(event)

    if match_count == 0:
        print(f"[EDITOR] Warning: No logs found matching {log_pattern}")

    # 2. Sort (Temporal Truth)
    all_events.sort(key=lambda x: x['timestamp'])

    # 3. Feed-Forward (Save to JSON)
    try:
        with open(dailies_output, 'w') as f:
            json.dump(all_events, f, indent=2)
        print(f"[EDITOR] Saved {len(all_events)} events to {dailies_output}")
    except Exception as e:
        print(f"[EDITOR] Warning: Could not save dailies: {e}")

    # 4. Visualization (ASCII Table)
    print("\n" + "="*106)
    print(f"NATURALIST OBSERVATORY: DAILIES ({scenario_name.upper()})")
    print("="*106)
    for line in generate_ascii_table(all_events):
        print(line)
    print("="*106 + "\n")

if __name__ == "__main__":
    main()
