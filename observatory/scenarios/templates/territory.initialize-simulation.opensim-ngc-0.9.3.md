```bash
# Create startup commands to auto-shutdown after init
echo "shutdown" > "$OPENSIM_DIR/startup_commands.txt"

# Create configuration overrides for NGC (Adaptation for Headless/Native-less environment)
cat <<EOF > "$OBSERVATORY_DIR/ngc_fixes.ini"
[Startup]
    physics = basicphysics

[UserAccountService]
    StorageProvider = "OpenSim.Data.Null.dll"
EOF

# Create dummy DB files to satisfy Director's CAST injection (since we use Null storage)
touch "$OBSERVATORY_DIR/userprofiles.db"
touch "$OBSERVATORY_DIR/inventory.db"
touch "$OBSERVATORY_DIR/auth.db"
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
Title: Territory Integrity (Config Override)
File: $OBSERVATORY_DIR/ngc_fixes.ini
Contains: physics = basicphysics
Frame: Infrastructure
```
