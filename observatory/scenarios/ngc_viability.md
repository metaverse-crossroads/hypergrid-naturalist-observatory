---
Title: NGC Viability Check
ID: ngc-viability
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
# Create user via console (providing all args to avoid prompts)
# create user <first> <last> <pass> <email> <uuid> <model>
create user Verifiable User password test@example.com 11111111-1111-1111-1111-111111111111 default
```

```wait
2000
```

```opensim
# Verify user creation
show account Verifiable User
```

```await
Title: User Verification
File: $OBSERVATORY_DIR/opensim_console.log
Contains: Name:    Verifiable User
Timeout: 10000
```

```opensim
shutdown
```
