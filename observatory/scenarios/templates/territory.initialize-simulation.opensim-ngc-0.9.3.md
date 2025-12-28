```bash
# Create startup commands to auto-shutdown after init
echo "shutdown" > "$OPENSIM_DIR/startup_commands.txt"
```

```opensim
# Start OpenSim to initialize DBs (will auto-shutdown)
WAIT_FOR_EXIT
```

```bash
# Remove startup commands so Live session stays up
rm -vf "$OPENSIM_DIR/startup_commands.txt"
```

```verify
Title: Territory Integrity (UserProfiles)
File: $OBSERVATORY_DIR/userprofiles.db
Contains: SQLite format 3
Frame: Infrastructure
```

```verify
Title: Territory Integrity (Inventory)
File: $OBSERVATORY_DIR/inventory.db
Contains: SQLite format 3
Frame: Infrastructure
```
