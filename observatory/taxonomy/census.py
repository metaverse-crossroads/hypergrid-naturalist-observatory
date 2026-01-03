#!/usr/bin/env python3
import os
import re
import sys
import json
from collections import defaultdict

# Configuration
REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SEARCH_PATHS = [
    os.path.join(REPO_ROOT, "species"),
    os.path.join(REPO_ROOT, "observatory/scenarios"),
    os.path.join(REPO_ROOT, "instruments"),
]

# Patterns
PATTERNS_PRODUCER = [
    # C# / Python: EncounterLogger.Log("Side", "Sys", "Sig", ...)
    # Note: Matches C# patches and Python source
    (re.compile(r'EncounterLogger\.Log\(\s*"([^"]+)"\s*,\s*"([^"]+)"\s*,\s*"([^"]+)"'), "EncounterLogger"),

    # Rust: log_encounter("Sys", "Sig", ...)
    (re.compile(r'log_encounter\(\s*"([^"]+)"\s*,\s*"([^"]+)"'), "RustLogger"),

    # Python Client: emit("Sys", "Sig", ...)
    (re.compile(r'emit\(\s*"([^"]+)"\s*,\s*"([^"]+)"'), "PythonEmit"),
]

# Markdown Consumers: Contains: "sys": "X", "sig": "Y"
# We look for lines containing sys OR sig keys
REGEX_SYS = re.compile(r'["\']sys["\']\s*:\s*["\']([^"\']+)["\']')
REGEX_SIG = re.compile(r'["\']sig["\']\s*:\s*["\']([^"\']+)["\']')

# Query DSL: entry.sys == 'X' ... entry.sig == 'Y'
REGEX_QUERY_SYS = re.compile(r'entry\.sys\s*==\s*["\']([^"\']+)["\']')
REGEX_QUERY_SIG = re.compile(r'entry\.sig\s*==\s*["\']([^"\']+)["\']')

def scan_file(filepath):
    producers = []
    consumers = []

    try:
        with open(filepath, 'r', errors='ignore') as f:
            lines = f.readlines()

        is_patch = filepath.endswith(".patch")

        for i, line in enumerate(lines):
            line_num = i + 1

            # --- Producers ---
            # If it's a patch, only check lines starting with '+'
            if is_patch and not line.startswith('+'):
                continue

            for pattern, kind in PATTERNS_PRODUCER:
                match = pattern.search(line)
                if match:
                    if kind == "EncounterLogger":
                        # side, sys, sig
                        via = match.group(1)
                        system = match.group(2)
                        signal = match.group(3)
                        producers.append({
                            "file": filepath,
                            "line": line_num,
                            "via": via,
                            "sys": system,
                            "sig": signal,
                            "raw": line.strip()
                        })
                    elif kind == "RustLogger":
                        # sys, sig (via is implied Visitant)
                        system = match.group(1)
                        signal = match.group(2)
                        producers.append({
                            "file": filepath,
                            "line": line_num,
                            "via": "Visitant", # Implied
                            "sys": system,
                            "sig": signal,
                            "raw": line.strip()
                        })
                    elif kind == "PythonEmit":
                        # sys, sig (via is implied Visitant)
                        system = match.group(1)
                        signal = match.group(2)
                        producers.append({
                            "file": filepath,
                            "line": line_num,
                            "via": "Visitant", # Implied
                            "sys": system,
                            "sig": signal,
                            "raw": line.strip()
                        })

            # --- Consumers (Markdown only) ---
            if filepath.endswith(".md"):
                # "Contains" Pattern
                if "sys" in line or "sig" in line: # Relaxed check
                    if "Contains" in line or "{" in line or "echo" in line: # Echo for tests
                        m_sys = REGEX_SYS.search(line)
                        m_sig = REGEX_SIG.search(line)

                        if m_sys or m_sig:
                            sys_val = m_sys.group(1) if m_sys else "*"
                            sig_val = m_sig.group(1) if m_sig else "*"

                            consumers.append({
                                "file": filepath,
                                "line": line_num,
                                "sys": sys_val,
                                "sig": sig_val,
                                "type": "Contains",
                                "raw": line.strip()
                            })

                # "Query" Pattern
                if "Query:" in line or "entry." in line:
                    m_q_sys = REGEX_QUERY_SYS.search(line)
                    m_q_sig = REGEX_QUERY_SIG.search(line)

                    if m_q_sys or m_q_sig:
                        sys_val = m_q_sys.group(1) if m_q_sys else "*"
                        sig_val = m_q_sig.group(1) if m_q_sig else "*"

                        consumers.append({
                            "file": filepath,
                            "line": line_num,
                            "sys": sys_val,
                            "sig": sig_val,
                            "type": "Query",
                            "raw": line.strip()
                        })

    except Exception as e:
        print(f"Error reading {filepath}: {e}", file=sys.stderr)

    return producers, consumers

def main():
    print("NATURALIST OBSERVATORY: TAXONOMY CENSUS")
    print("=======================================")

    all_producers = []
    all_consumers = []

    # 1. Walk Files
    for path in SEARCH_PATHS:
        for root, dirs, files in os.walk(path):
            for file in files:
                if file.endswith(('.cs', '.rs', '.py', '.md', '.patch')):
                    filepath = os.path.join(root, file)
                    p, c = scan_file(filepath)
                    all_producers.extend(p)
                    all_consumers.extend(c)

    # 2. Analyze Unique Signals
    produced_sigs = set((p['sys'], p['sig']) for p in all_producers)
    consumed_sigs = set((c['sys'], c['sig']) for c in all_consumers)

    # 3. Report Producers
    print(f"\n[PRODUCERS FOUND]: {len(all_producers)}")
    print(f"{'SYS':<15} | {'SIG':<20} | {'VIA':<15} | {'LOCATION'}")
    print("-" * 80)
    for p in all_producers:
        rel_path = os.path.relpath(p['file'], REPO_ROOT)
        print(f"{p['sys']:<15} | {p['sig']:<20} | {p['via']:<15} | {rel_path}:{p['line']}")

    # 4. Report Consumers
    print(f"\n[CONSUMERS FOUND]: {len(all_consumers)}")
    print(f"{'SYS':<15} | {'SIG':<20} | {'TYPE':<10} | {'LOCATION'}")
    print("-" * 80)
    for c in all_consumers:
        rel_path = os.path.relpath(c['file'], REPO_ROOT)
        print(f"{c['sys']:<15} | {c['sig']:<20} | {c['type']:<10} | {rel_path}:{c['line']}")

    # 5. Gap Analysis
    print(f"\n[GAP ANALYSIS]")
    print("-" * 80)

    # Loose matching for gap analysis:
    # If a consumer asks for (*, SIG), and we produce (SYS, SIG), it's a match.
    # If a consumer asks for (SYS, *), and we produce (SYS, SIG), it's a match.

    orphans = []
    for p in produced_sigs:
        consumed = False
        for c in consumed_sigs:
            match_sys = (c[0] == '*' or c[0] == p[0])
            match_sig = (c[1] == '*' or c[1] == p[1])
            if match_sys and match_sig:
                consumed = True
                break
        if not consumed:
            orphans.append(p)

    hallucinations = []
    for c in consumed_sigs:
        produced = False
        for p in produced_sigs:
            match_sys = (c[0] == '*' or c[0] == p[0])
            match_sig = (c[1] == '*' or c[1] == p[1])
            if match_sys and match_sig:
                produced = True
                break
        if not produced:
            hallucinations.append(c)

    print("\nORPHANS (Produced but never Consumed):")
    if orphans:
        for s in sorted(list(orphans)):
            print(f"  - {s[0]}: {s[1]}")
    else:
        print("  (None)")

    print("\nHALLUCINATIONS (Consumed but never Produced):")
    if hallucinations:
        for s in sorted(list(hallucinations)):
            print(f"  - {s[0]}: {s[1]}")
            # Identify which file expects this
            for c in all_consumers:
                if c['sys'] == s[0] and c['sig'] == s[1]:
                    rel_path = os.path.relpath(c['file'], REPO_ROOT)
                    print(f"    -> Expected by: {rel_path}")
    else:
        print("  (None)")

    # 6. Bad Teleplay Heuristic
    print("\n[BAD TELEPLAY SUSPECTS]")
    print("Checking for verification of 'Sent' signals (checking Intent instead of Effect)...")
    suspicious_keywords = ["Sent", "Output", "Gossip", "Shout"] # Heuristic

    found_suspicious = False
    for c in all_consumers:
        if any(k in c['sig'] for k in suspicious_keywords):
            print(f"  SUSPECT: {c['sys']}:{c['sig']} in {os.path.relpath(c['file'], REPO_ROOT)}")
            found_suspicious = True

    if not found_suspicious:
        print("  (None found based on heuristics)")

if __name__ == "__main__":
    main()
