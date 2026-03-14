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

import re
import os

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Match group 1: existing frontmatter content
    # Match group 2: the rest of the file after the second '---'
    pattern = re.compile(r'^---\r?\n(.*?)\r?\n---\r?\n?(.*)', re.DOTALL)
    match = pattern.match(content)

    if not match:
        # No frontmatter at all -> prepend a fresh block
        new_content = "---\nterritory: opensim-core-0.9.3\n---\n" + content
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Migrated (Added full block): {os.path.relpath(filepath, OBSERVATORY_DIR)}")
        
    else:
        existing_frontmatter = match.group(1)
        rest_of_content = match.group(2)
        
        # Check if it has a frontmatter block but is missing the territory key
        if 'territory:' not in existing_frontmatter:
            # Strip trailing whitespace to avoid double blank lines, then inject
            new_frontmatter = existing_frontmatter.rstrip() + "\nterritory: opensim-core-0.9.3\n"
            new_content = f"---\n{new_frontmatter}---\n{rest_of_content}"
            
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"Migrated (Injected territory): {os.path.relpath(filepath, OBSERVATORY_DIR)}")


def old_process_file(filepath):
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
