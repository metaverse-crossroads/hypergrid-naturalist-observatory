```bash
# Cleanup
rm -vf "$VIVARIUM_ROOT/encounter.${SCENARIO_NAME}".*.log
rm -vf "$OBSERVATORY_DIR/opensim.log"
rm -vf "$OBSERVATORY_DIR/opensim_console.log"
rm -vf "$OBSERVATORY_DIR/"*.db

# Create Observatory
mkdir -vp "$OBSERVATORY_DIR/Regions"

# Copy Regions
cp -v "$OPENSIM_DIR/Regions/Regions.ini.example" "$OBSERVATORY_DIR/Regions/Regions.ini"
```
