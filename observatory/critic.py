#!/usr/bin/env python3
import sys
import os
import json
import re

# Configuration
REPO_ROOT = (os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DAILIES_PATH = os.path.join(REPO_ROOT, "vivarium", "dailies.json")
TAXONOMY_PATH = os.path.join(REPO_ROOT, "observatory", "taxonomy", "visitant.md")

def load_dailies():
    if not os.path.exists(DAILIES_PATH):
        print(f"[CRITIC] Error: {DAILIES_PATH} not found. Run editor.py first.")
        sys.exit(1)
    with open(DAILIES_PATH, 'r') as f:
        return json.load(f)

def load_taxonomy(filepath):
    """
    Extracts the JSON spec block from a Markdown file.
    Robustness: Looks for the first ```json block. Fails hard if invalid.
    """
    if not os.path.exists(filepath):
        print(f"[CRITIC] Error: Taxonomy {filepath} not found.")
        sys.exit(1)
        
    with open(filepath, 'r') as f:
        content = f.read()

    # Regex to find the json fence. Non-greedy match.
    match = re.search(r"```json\s*(\{.*?\})\s*```", content, re.DOTALL)
    if not match:
        print(f"[CRITIC] Error: No valid JSON configuration block found in {os.path.basename(filepath)}")
        sys.exit(1)
        
    try:
        return json.loads(match.group(1))
    except json.JSONDecodeError as e:
        print(f"[CRITIC] Error: Invalid JSON in taxonomy file: {e}")
        sys.exit(1)

def filter_events(dailies, actor_name):
    # Filters the bag of events for a specific actor
    return [e for e in dailies if e.get("actor") == actor_name]

def check_existence(events, query):
    """Rule Type: Existence (Did it happen?)"""
    for e in events:
        # Check if all keys in query match the event
        if all(e.get(k) == v for k, v in query.items()):
            return True
    return False

def check_topology(events, before_query, after_query):
    """Rule Type: Topology (Did A happen before B?)"""
    ts_before = None
    ts_after = None

    # Find first occurrence of 'before'
    for e in events:
        if all(e.get(k) == v for k, v in before_query.items()):
            ts_before = e['timestamp']
            break
            
    # Find first occurrence of 'after'
    for e in events:
        if all(e.get(k) == v for k, v in after_query.items()):
            ts_after = e['timestamp']
            break
    
    if ts_before is None or ts_after is None:
        return False # One event is missing
        
    return ts_before < ts_after

def main():
    if len(sys.argv) < 2:
        print("Usage: critic.py <Actor Name>")
        print("Example: critic.py 'Visitant One'")
        sys.exit(1)
        
    target_actor = sys.argv[1]
    
    # 1. Load Data
    dailies = load_dailies()
    spec = load_taxonomy(TAXONOMY_PATH)
    
    actor_events = filter_events(dailies, target_actor)
    
    print("\n" + "="*60)
    print(f"NATURALIST CRITIQUE: {target_actor}")
    print(f"Taxonomy Species: {spec['species']}")
    print("="*60)
    
    if not actor_events:
        print(f"[!] No events found for actor '{target_actor}'")
        print("CLASSIFICATION: INERT / GHOST")
        sys.exit(0)

    # 2. Execute Rules
    passed_count = 0
    results = []

    for rule in spec['rules']:
        status = "FAIL"
        
        if rule['type'] == 'existence':
            if check_existence(actor_events, rule['query']):
                status = "PASS"
                
        elif rule['type'] == 'topology':
            if check_topology(actor_events, rule['before'], rule['after']):
                status = "PASS"
        
        results.append((rule['id'], rule['description'], status, rule.get('critical', False)))
        if status == "PASS":
            passed_count += 1

    # 3. Report
    print(f"{'ID':<15} | {'Result':<6} | {'Description'}")
    print("-" * 60)
    
    critical_failure = False
    for r_id, desc, status, is_critical in results:
        print(f"{r_id:<15} | {status:<6} | {desc}")
        if status == "FAIL" and is_critical:
            critical_failure = True

    print("="*60)
    
    # 4. Final Classification
    if critical_failure:
        print(f"VERDICT: DYSFUNCTIONAL SPECIMEN (Critical Failure)")
    elif passed_count == len(results):
        print(f"VERDICT: CONFIRMED SPECIMEN ({spec['species']})")
    else:
        print(f"VERDICT: ATYPICAL SPECIMEN (Partial Match)")
    print("="*60 + "\n")

if __name__ == "__main__":
    main()