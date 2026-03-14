#!/usr/bin/env python3
import os
import re

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OBSERVATORY_DIR = os.path.dirname(SCRIPT_DIR)
SCENARIOS_DIR = os.path.join(OBSERVATORY_DIR, "scenarios")

FRONTMATTER_BLOCK = """---
territory: opensim-core-0.9.3
---

"""

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    # Check if file already starts with YAML frontmatter
    pattern = re.compile(r'^---\r?\n(.*?)\r?\n---', re.DOTALL)
    match = pattern.match(content)

    if not match:
        with open(filepath, 'w') as f:
            f.write(FRONTMATTER_BLOCK + content)
        print(f"Migrated: {os.path.relpath(filepath, OBSERVATORY_DIR)}")

def main():
    if not os.path.isdir(SCENARIOS_DIR):
        print(f"Error: Directory {SCENARIOS_DIR} not found.")
        return

    for root, _, files in os.walk(SCENARIOS_DIR):
        for file in files:
            if file.endswith(".md"):
                filepath = os.path.join(root, file)
                process_file(filepath)

if __name__ == "__main__":
    main()
