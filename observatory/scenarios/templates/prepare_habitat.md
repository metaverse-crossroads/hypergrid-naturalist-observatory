```bash
# # Cleanup
# NOTE: moved to run_encounter.sh -- otherwise encounter..director.log would get nuked
# rm -vf "$VIVARIUM_ROOT/encounter.${SCENARIO_NAME}".*.log

rm -vf "$OBSERVATORY_DIR/opensim.log"
# rm -vf "$OBSERVATORY_DIR/opensim_console.log"
rm -vf "$OBSERVATORY_DIR/"*.db

# Create Observatory
mkdir -vp "$OBSERVATORY_DIR/Regions"

# Copy Regions
# cp -v "$OPENSIM_DIR/Regions/Regions.ini.example" "$OBSERVATORY_DIR/Regions/Regions.ini"

cat <<EOF > "$OBSERVATORY_DIR/Regions/Regions.ini"
[Observatory Habitat]
    RegionUUID = 11111111-2222-3333-4444-555555555568
    Location = 1000,1000
    InternalAddress = 0.0.0.0
    InternalPort = ${OPENSIM_PORT:-9000}
    AllowAlternatePorts = False
    ExternalHostName = SYSTEMIP
EOF

# Prepare Estate Config
if [ ! -f "$OBSERVATORY_DIR/encounter.ini" ]; then
    cat <<EOF > "$OBSERVATORY_DIR/encounter.ini"
[CUSTOM]
    GRIDNAME = "observatory-habitat"
    HOSTNAME = ${OPENSIM_HOSTNAME:-127.0.0.1}

[Network]
    ConsoleUser = "RestUser"
    ConsolePass = "RestPassword"

[GridService]
    Region_Observatory_Habitat = "DefaultRegion"

[Estates]
    DefaultEstateName = Observatory Habitat Estate
    DefaultEstateOwnerName = Test User
    DefaultEstateOwnerUUID = 00000000-0000-0000-0000-000000000123
    DefaultEstateOwnerEMail = test@example.com
    DefaultEstateOwnerPassword = password
EOF
fi
```
