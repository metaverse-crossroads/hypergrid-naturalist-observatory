#!/usr/bin/env python3
import os
import sys
import argparse
import tempfile
import shutil
import subprocess
import re
import signal
import io
import concurrent.futures

# Force stdout and stderr to use UTF-8 regardless of the environment (*cough* python3 on windows)
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

def signal_handler(sig, frame):
    print("\n[!] Ctrl-C detected. Cleaning up temporary workspace and exiting...")
    sys.exit(0)

# Gracefully handle Ctrl-C. The tempfile context manager will automatically clean up on sys.exit()
signal.signal(signal.SIGINT, signal_handler)

def parse_args():
    parser = argparse.ArgumentParser(description="Probe C# files against various TFMs/LangVersions to find syntax compatibility.")
    parser.add_argument('paths', nargs='*', default=['.'], help="Files or directories to analyze (defaults to current directory)")
    parser.add_argument('-v', '--verbose', action='store_true', help="Expand all unique blockers for the most recent non-viable TFM.")
    parser.add_argument('-N', '--num', type=int, help="Only test the top N candidate tuples.")
    parser.add_argument('-t', '--tfm', type=str, help="Filter to a specific TFM (e.g., net8.0)")
    parser.add_argument('-l', '--lang', type=str, help="Filter to a specific LangVersion (e.g., 12.0)")
    parser.add_argument('-x', '--excludes', type=str, help="CSV list of verbatim full path exclude patths (eg: '/Tests/,/obj/')")
    return parser.parse_args()

def gather_cs_files(paths, excludes = []):
    cs_files = []
    for p in paths:
        if os.path.isfile(p) and p.endswith('.cs'):
            if os.path.basename(p).lower() != 'assemblyinfo.cs':
                cs_files.append(p)
        elif os.path.isdir(p):
            for root, dirs, files in os.walk(p):
                # Prune out 'bin' and 'obj' directories so we don't grab already-compiled auto-gen files
                dirs[:] = [d for d in dirs if d.lower() not in ('bin', 'obj')]
                for f in files:
                    if f.endswith('.cs') and f.lower() != 'assemblyinfo.cs':
                        cs_files.append(os.path.join(root, f))
        else:
            print(f"[!] Warning: Path '{p}' is not a valid directory or .cs file. Skipping.")
    def exclude(y):
        for x in excludes:
            if x in y.replace('\\', '/'):
                print("excluding", x, y, file=sys.stderr)
                return True
        return False
    return [y for y in cs_files if not exclude(y)]

def format_table(dotnet_version, results):
    headers = ["SDK", "TFM", "LangVer", "Result", "Key Blocker"]
    
    # Calculate column widths
    widths = [len(h) for h in headers]
    for row in results:
        for i, col in enumerate(row):
            widths[i] = max(widths[i], len(str(col)))
            
    # Add a little padding
    widths = [w + 2 for w in widths]

    def print_row(row_data, is_header=False):
        formatted_cols = []
        for item, width in zip(row_data, widths):
            item_str = str(item)
            padding = width - len(item_str)
            # Left align
            formatted_cols.append(f" {item_str}{' ' * (padding - 1)}")
            
        row_str = "|".join(formatted_cols)
        print(f"|{row_str}|")

    def print_separator():
        formatted = "+".join("-" * width for width in widths)
        print(f"+{formatted}+")

    print("\n")
    print_separator()
    print_row(headers, is_header=True)
    print_separator()
    for row in results:
        print_row(row)
    print_separator()
    print()

def main():
    # Safely construct the environment
    run_env = os.environ.copy()
    dotnet_root = os.getenv("DOTNET_ROOT")
    
    # If DOTNET_ROOT is specified, prepend it to the PATH rather than replacing the PATH entirely
    if dotnet_root:
        dotnet_root = dotnet_root.replace('/', os.sep)
        run_env["PATH"] = f"{dotnet_root}{os.pathsep}{run_env.get('PATH', '')}"

    dotnet_exe = shutil.which('dotnet', path=run_env.get("PATH"))

    if not dotnet_exe:
        print("[!] Error: 'dotnet' CLI not found. Please ensure the .NET SDK is installed and in your PATH or DOTNET_ROOT.")
        sys.exit(1)

    # Safely capture the exact dotnet SDK version that the resolved environment will use
    try:
        ver_proc = subprocess.run([dotnet_exe, "--version"], env=run_env, capture_output=True, text=True, check=True)
        dotnet_version = ver_proc.stdout.strip()
    except Exception:
        dotnet_version = "Unknown"

    print(f"Using .NET SDK: {dotnet_version} ({dotnet_exe})", flush=True)

    args = parse_args()
    cs_files = gather_cs_files(args.paths, (args.excludes or '\x00').split(','))

    if not cs_files:
        print("[!] No .cs files found to analyze.")
        sys.exit(0)

    print(f"Found {len(cs_files)} .cs file(s). Preparing test harness...", flush=True)

    matrix = [
        ("net472", "7.3", "Old School"),
        ("netstandard2.0", "7.3", "The Library Standard"),
        ("netcoreapp3.1", "8.0", "The 'Core' Shift"),
        ("net6.0", "10.0", "The Legacy Sunset"),
        ("netstandard2.0", "12.0", "The Polyfill Era"),
        ("net8.0", "12.0", "~2026.03 Older LTS"),
        ("net10.0", "14.0", "~2026.03 Current LTS"),
        ("net11.0", "15.0", "~2026.03 Bleeding Edge")
    ]
    
    # Apply CLI filters
    if args.tfm:
        matrix = [m for m in matrix if m[0] == args.tfm]
    if args.lang:
        matrix = [m for m in matrix if m[1] == args.lang]
    if args.num:
        matrix = matrix[-args.num:]

    if not matrix:
        print("[!] No test targets remain after applying filters.", args.tfm, args.lang)
        sys.exit(0)

    # Pre-allocate results array so we can slot them in out-of-order and preserve the matrix sequence
    results = [None] * len(matrix)

    # tempfile.TemporaryDirectory securely handles creation and automated teardown
    with tempfile.TemporaryDirectory(prefix="cstruth_") as tmpdir:
        src_dir = os.path.join(tmpdir, "src")
        os.makedirs(src_dir, exist_ok=True)
        
        # 1. Isolate the files ONCE for all parallel threads into a dedicated src folder
        for i, file_path in enumerate(cs_files):
            # Flatten files to avoid complex path recreation, prepending index to prevent collisions
            safe_name = f"src_{i}_{os.path.basename(file_path)}"
            shutil.copy(file_path, os.path.join(src_dir, safe_name))

        def run_probe(matrix_item):
            tfm, lang, label = matrix_item
            
            # Safe suffix for isolated build folders
            safe_suffix = f"{tfm}_{lang.replace('.', '_')}"
            
            # Create a truly isolated directory for this specific parallel probe
            run_dir = os.path.join(tmpdir, safe_suffix)
            os.makedirs(run_dir, exist_ok=True)
            
            csproj_name = "harness.csproj"
            
            # Use isolated run directories to completely prevent MSBuild project.assets.json race conditions.
            # Explicitly include the flattened source files from the sibling 'src' directory.
            csproj_content = f"""<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>{tfm}</TargetFramework>
    <LangVersion>{lang}</LangVersion>
    <ImplicitUsings>disable</ImplicitUsings>
    <Nullable>disable</Nullable>
    <GenerateAssemblyInfo>false</GenerateAssemblyInfo>
    <AllowUnsafeBlocks>true</AllowUnsafeBlocks>
  </PropertyGroup>
  <ItemGroup>
    <Compile Include="../src/*.cs" />
  </ItemGroup>
</Project>"""
            
            with open(os.path.join(run_dir, csproj_name), "w") as f:
                f.write(csproj_content)

            # 3. Compile
            process = subprocess.run(
                ["dotnet", "build", csproj_name, "--nologo", "-v", "q"],
                env=run_env,
                cwd=run_dir,
                capture_output=True,
                text=True
            )
            output = process.stdout + process.stderr

            # 4. Analysis
            errors = re.findall(r'error ([A-Za-z]+\d+): (.*?)(?=\s+\[|$)', output)
            
            cs_errors = [e for e in errors if e[0].upper().startswith('CS')]
            
            # --- FLATTENING ARTIFACT FIX ---
            # Squishing multiple independent projects into one compilation context causes:
            # CS0101/CS0111/CS0121: Duplicate internal polyfill definitions and ambiguous calls
            flattening_artifacts = ('CS0101', 'CS0111', 'CS0121')
            cs_errors = [e for e in cs_errors if e[0].upper() not in flattening_artifacts] 

            sdk_errors = [e for e in errors if not e[0].upper().startswith('CS')]
            
            total_cs_errs = len(cs_errors)
            # Acceptable dependency missing errors (Added CS1069)
            missing_type_codes = ('CS0246', 'CS0103', 'CS0234', 'CS0518', 'CS1069')
            missing_type_errs = sum(1 for e in cs_errors if e[0].upper() in missing_type_codes)

            MAXLEN = (255 if args.verbose else 55)
            
            cleaned_cs_errors = []
            seen = set()
            for e in cs_errors:
                msg = e[1]
                msg = re.sub(r"[.] +.*", "", msg)
                msg = re.sub(r"\s*\(are you missing[^)]+\)", "", msg)
                err_str = f"{e[0].upper()}: {msg}"
                
                # Do NOT truncate here! Truncation ruins the sorting namespace check.
                if err_str not in seen:
                    seen.add(err_str)
                    cleaned_cs_errors.append((e[0].upper(), err_str))
            
            def get_sort_weight(code, msg_str):
                m = msg_str.upper()
                # Core framework issues bubble to the absolute top
                if 'SYSTEM' in m or 'MICROSOFT' in m or 'MSCORLIB' in m:
                    return -1
                # Mundane 3rd-party missing types sink to the absolute bottom
                if code in missing_type_codes:
                    return 1
                # Standard syntax or structural blockers stay in the middle
                return 0

            # Sort errors: Prioritize weight first, then error code, then alphabetical message
            cleaned_cs_errors.sort(key=lambda x: (get_sort_weight(x[0], x[1]), x[0], x[1]))
            
            syntax_errs = [e for e in cleaned_cs_errors if e[0] in ('CS8107', 'CS8370', 'CS8652')]

            status = ""
            blockers = []

            # Helper to truncate and re-deduplicate strings immediately prior to display assignment
            def apply_truncation_and_dedup(err_list):
                res = []
                for e in err_list:
                    s = e[1] if isinstance(e, tuple) else e
                    if len(s) > MAXLEN:
                        s = s[:MAXLEN-3] + "..."
                    if s not in res:
                        res.append(s)
                return res

            if sdk_errors:
                status = "[WARN] System Constraint"
                sdk_strs = []
                for se in sdk_errors:
                    msg = se[1]
                    msg = re.sub(r"[.] +.*", "", msg)
                    sdk_strs.append(f"{se[0]}: {msg}")
                blockers = apply_truncation_and_dedup(sdk_strs)
            elif syntax_errs:
                status = "[FAIL] Incompatible"
                blockers = apply_truncation_and_dedup(syntax_errs)
            elif process.returncode != 0 and total_cs_errs == 0:
                status = "[WARN] System Constraint"
                blockers = ["Unknown Build Failure (Check CLI output)"]
            elif total_cs_errs == missing_type_errs:
                status = "[PASS] Viable"
                blockers = []
            else:
                status = "[WARN] System Constraint"
                if cleaned_cs_errors:
                    blockers = apply_truncation_and_dedup(cleaned_cs_errors)
                else:
                    blockers = ["Unknown: Build failed without standard CS code"]

            return (tfm, lang, status, blockers)

        # 2. Parallel Loop with Progress Indicator
        print(f"Spawning {len(matrix)} MSBuild test harnesses in parallel...", flush=True)
        
        spinners = ['|', '/', '-', '\\']
        completed = 0
        total = len(matrix)
        
        with concurrent.futures.ThreadPoolExecutor(max_workers=len(matrix)) as executor:
            # Map the future object to its original matrix index so we don't lose the sequence
            future_to_idx = {executor.submit(run_probe, item): i for i, item in enumerate(matrix)}
            
            for future in concurrent.futures.as_completed(future_to_idx):
                idx = future_to_idx[future]
                results[idx] = future.result()
                completed += 1
                
                spinner = spinners[completed % 4]
                sys.stdout.write(f"\r [{spinner}] Compiling and analyzing... {completed}/{total} completed.")
                sys.stdout.flush()
                
    # Clear the progress line completely
    sys.stdout.write("\r" + " " * 70 + "\r")
    sys.stdout.flush()
            
    # 5. Report Formatting
    final_rows = []
    
    # Find the index of the most recent TFM that did NOT pass, 
    # explicitly IGNORING strict SDK limitations (e.g. NETSDK1045)
    last_fail_idx = -1
    for i, (_, _, status, blockers) in enumerate(results):
        if status != "[PASS] Viable":
            is_sdk_error = any(b.startswith("NETSDK") or b.startswith("MSB") for b in blockers)
            if not is_sdk_error:
                last_fail_idx = i

    for i, (tfm, lang, status, blockers) in enumerate(results):
        if status == "[PASS] Viable" or not blockers:
            final_rows.append((dotnet_version, tfm, lang, status, "-"))
        else:
            # If verbose is flagged and this is the "most recent non-viable syntax" threshold
            if args.verbose and i == last_fail_idx:
                for b in blockers:
                    final_rows.append((dotnet_version, tfm, lang, status, b))
            else:
                final_rows.append((dotnet_version, tfm, lang, status, blockers[0]))

    format_table(dotnet_version, final_rows)

if __name__ == "__main__":
    main()