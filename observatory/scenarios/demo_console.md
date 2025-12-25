# Console Command Demo

Demonstrates controlling OpenSim via the Director's stdio-REPL capability, including user provisioning and sending alerts.

## 1. Environment Setup
Prepare the directories and cleanup previous artifacts.

[#include](templates/setup_environment.md)
[#include](templates/default_estate.md)

## 2. Encounter

Start the territory.

[#include](templates/await_default_region.md)

### Provisioning
Create a user via the console.
We provide all arguments to avoid interactive prompts which can be tricky to synchronize.
Syntax: create user <first> <last> <pass> <email> <uuid> <model>

```opensim
create user Console Test password test@example.com 00000000-0000-0000-0000-111111111111 Default
```

```opensim
create user Console Test2 password test@example.com 00000000-0000-0000-0000-111111111112 Default
```

### Visitant Login
Login with the new user.

```mimic Console Test
LOGIN Console Test password
```

```await
Title: Visitant Login Success
File: vivarium/encounter.demo_console.visitant.ConsoleTest.log
Contains: "sig": "Success"
Frame: Visitant
```

```await
Title: Visitant Presence (Territory)
File: vivarium/encounter.demo_console.territory.log
Contains: "sig": "VisitantLogin", "val": "Console Test" 
Frame: Territory
```

### Alert Test
Send an alert from the console.
```wait
1000
```

```opensim
alert This is a console alert
```

```await
Title: Alert Received
File: vivarium/encounter.demo_console.visitant.ConsoleTest.log
Contains: "val": "This is a console alert
Frame: Visitant
```

### Shutdown

```mimic Console Test
LOGOUT
EXIT
```

```opensim
shutdown
```
