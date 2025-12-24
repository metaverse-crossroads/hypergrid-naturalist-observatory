# Cleanup
rm -f "$VIVARIUM_ROOT/encounter.${SCENARIO_NAME}".*.log
rm -f "$OBSERVATORY_DIR/opensim.log"
rm -f "$OBSERVATORY_DIR/opensim_console.log"
rm -f "$OBSERVATORY_DIR/"*.db

# Create Observatory
mkdir -p "$OBSERVATORY_DIR/Regions"

# Copy Regions
cp "$OPENSIM_DIR/Regions/Regions.ini.example" "$OBSERVATORY_DIR/Regions/Regions.ini"
