---
Title: NGC Mimic Encounter
ID: ngc-mimic
---

[#include](./templates/prepare_habitat.md)

[#include](./templates/territory.initialize-simulation.opensim-ngc-0.9.3.md)

```opensim
# Start Live Session
```

```await
Title: Startup Complete
File: $OBSERVATORY_DIR/opensim_console.log
Contains: LOGINS ENABLED
Timeout: 60000
```

```opensim
# Create user "Mimic User" via console
create user Mimic User password test@example.com
```

```wait
2000
```

```cast
[
  {
    "First": "Mimic",
    "Last": "User",
    "Password": "password",
    "UUID": "00000000-0000-0000-0000-000000000000",
    "Species": "Mimic"
  }
]
```

```actor Mimic User
LOGIN Mimic User password
```

```await
Title: Mimic Login
File: $VIVARIUM_ROOT/encounter.ngc-mimic.visitant.MimicUser.log
Contains: "MIGRATION", "ENTRY"
Timeout: 30000
```

```opensim
shutdown
```
