# Simulant CLI Documentation

This document outlines the command-line interface (CLI) arguments supported by the OpenSim Core simulant.

Based on analysis of `OpenSim/Region/Application/OpenSim.cs`.

## Usage

```bash
OpenSim.exe [options]
```

## Options

| Option | Description |
| :--- | :--- |
| `-console <type>` | Console type (`local`, `basic`, `rest`). Default is `local` (or from `Startup` config). |
| `-gui` | Run with GUI enabled. |
| `-inifile <path>` | Path to the main configuration file. Default: `OpenSim.ini`. |
| `-inidirectory <path>` | Directory to load configuration files from. |
| `-logconfig <path>` | Path to the logging configuration file (log4net). |
| `-prompt <string>` | Custom console prompt. |
| `-hypergrid <bool>` | Enable or disable Hypergrid mode. |

**Note:** OpenSim uses Nini for configuration, so command line arguments often override `[Startup]` section settings.

## Startup Files

*   `startup_commands.txt`: If present, these commands are executed on startup.
*   `shutdown_commands.txt`: If present, these commands are executed on shutdown.
