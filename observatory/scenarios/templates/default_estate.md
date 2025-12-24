```bash
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
