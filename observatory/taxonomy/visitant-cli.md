# Visitant CLI Documentation

This document outlines the command-line interface (CLI) arguments supported by the Visitant clients (Mimic and Benthic).

## Usage

```bash
make run-mimic -- [options]
make run-benthic -- [options]
```

## Options

| Option | Alias | Description | Default |
| :--- | :--- | :--- | :--- |
| `--firstname` | `-f`, `--user` | First name of the agent. | `Test` |
| `--lastname` | `-l` | Last name of the agent. | `User` |
| `--password` | `-p` | Password of the agent. | `password` |
| `--uri` | `-u`, `-s` | Login URI of the grid/region. | `http://localhost:9000/` |
| `--help` | `-h` | Show help message. | - |
| `--version` | `-v` | Show version information. | - |

## Examples

**Login as Test User (Default):**
```bash
make run-mimic
```

**Login as Custom User:**
```bash
make run-mimic -- --firstname John --lastname Doe --password secret
```

**Login to Custom URI:**
```bash
make run-benthic -- --uri http://127.0.0.1:9000/
```

**Pipe commands from a file:**
```bash
make run-mimic < commands.txt
```
