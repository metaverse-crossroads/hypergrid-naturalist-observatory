```bash
# # Cleanup
# NOTE: moved to run_encounter.sh -- otherwise encounter..director.log would get nuked
# rm -vf "$VIVARIUM_ROOT/encounter.${SCENARIO_NAME}".*.log

rm -vf "$OBSERVATORY_DIR/opensim.log"
rm -vf "$OBSERVATORY_DIR/opensim_console.log"
rm -vf "$OBSERVATORY_DIR/"*.db

# Create Observatory
mkdir -vp "$OBSERVATORY_DIR/Regions"

# Copy Regions
cp -v "$OPENSIM_DIR/Regions/Regions.ini.example" "$OBSERVATORY_DIR/Regions/Regions.ini"

# Prepare Estate Config
if [ ! -f "$OBSERVATORY_DIR/encounter.ini" ]; then
    cat <<EOF > "$OBSERVATORY_DIR/encounter.ini"
[Estates]
DefaultEstateName = My Estate
DefaultEstateOwnerName = Test User
DefaultEstateOwnerUUID = 00000000-0000-0000-0000-000000000123
DefaultEstateOwnerEMail = test@example.com
DefaultEstateOwnerPassword = password
EOF
fi
```
