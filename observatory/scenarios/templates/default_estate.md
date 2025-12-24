if [ ! -f "$OBSERVATORY_DIR/encounter.ini" ]; then
    echo "[Estates]" > "$OBSERVATORY_DIR/encounter.ini"
    echo "DefaultEstateName = My Estate" >> "$OBSERVATORY_DIR/encounter.ini"
    echo "DefaultEstateOwnerName = Test User" >> "$OBSERVATORY_DIR/encounter.ini"
    echo "DefaultEstateOwnerUUID = 00000000-0000-0000-0000-000000000123" >> "$OBSERVATORY_DIR/encounter.ini"
    echo "DefaultEstateOwnerEMail = test@example.com" >> "$OBSERVATORY_DIR/encounter.ini"
    echo "DefaultEstateOwnerPassword = password" >> "$OBSERVATORY_DIR/encounter.ini"
fi
