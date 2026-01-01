---
Title: Human Visitant Teleplay
---

# Human Visitant Teleplay

**Purpose:** An interactively-explorable encounter for a Human Visitant (Test User). Features async sensors that react to the human's presence and chat commands.

## 1. Environment Setup

[#include](templates/prepare_habitat.md)

## 2. Territory Initialization

[#include](templates/territory.initialize-simulation.md)

## 3. Opening Credits (Cast)

```cast
[
    {
        "First": "Actor",
        "Last": "Visitant",
        "Password": "password",
        "UUID": "11111111-1111-1111-1111-111111111111",
        "Species": "mimic"
    }
]
```

## 4. The Encounter

### Territory Live
Start OpenSim.

```territory
# Start Live
```
[#include](templates/territory.await-region.md)
[#include](templates/territory.await-login-service.md)

### Sensors

**1. Abort Sensor**
Detects "goodbye!" from the Territory (Human Chat) and aborts the simulation.

```async-sensor
Title: Abort Trigger (Human)
Subject: Territory
Contains: goodbye!
director#abort: Human initiated shutdown.
```

**2. Pong Sensor**
Detects "ping" from the Territory (Human Chat) and replies with an Alert "pong!".

```async-sensor
Title: Pong Trigger (Human)
Subject: Territory
Contains: ping
director#alert: pong!
```

**3. Welcome Sensor**
Detects "Test User" logging in and welcomes them.
Matches the territory log signature for user login (captured as "val": "Test User").

```async-sensor
Title: Welcome Trigger
Subject: Territory
Contains: "val": "Test User"
director#alert: Welcome to the Simulation, Test User!
```

### Slow Burn Idling Loop

We unroll the loop 10 times to provide ~2-3 minutes of activity.
Each iteration: Login -> Wait -> Chat -> Wait -> Logout -> Wait -> Alert Segment.

#### Iteration 1
```actor Actor Visitant
LOGIN Actor Visitant password
WAIT 5000
CHAT brb
WAIT 5000
LOGOUT
```
```wait
11000
```
```territory
alert Segment 1 Complete
```

#### Iteration 2
```actor Actor Visitant
LOGIN Actor Visitant password
WAIT 5000
CHAT just checking in
WAIT 5000
LOGOUT
```
```wait
11000
```
```territory
alert Segment 2 Complete
```

#### Iteration 3
```actor Actor Visitant
LOGIN Actor Visitant password
WAIT 5000
CHAT systems nominal
WAIT 5000
LOGOUT
```
```wait
11000
```
```territory
alert Segment 3 Complete
```

#### Iteration 4
```actor Actor Visitant
LOGIN Actor Visitant password
WAIT 5000
CHAT anyone here?
WAIT 5000
LOGOUT
```
```wait
11000
```
```territory
alert Segment 4 Complete
```

#### Iteration 5
```actor Actor Visitant
LOGIN Actor Visitant password
WAIT 5000
CHAT logging trace data
WAIT 5000
LOGOUT
```
```wait
11000
```
```territory
alert Segment 5 Complete
```

#### Iteration 6
```actor Actor Visitant
LOGIN Actor Visitant password
WAIT 5000
CHAT calibrating sensors
WAIT 5000
LOGOUT
```
```wait
11000
```
```territory
alert Segment 6 Complete
```

#### Iteration 7
```actor Actor Visitant
LOGIN Actor Visitant password
WAIT 5000
CHAT upload complete
WAIT 5000
LOGOUT
```
```wait
11000
```
```territory
alert Segment 7 Complete
```

#### Iteration 8
```actor Actor Visitant
LOGIN Actor Visitant password
WAIT 5000
CHAT maintenance cycle
WAIT 5000
LOGOUT
```
```wait
11000
```
```territory
alert Segment 8 Complete
```

#### Iteration 9
```actor Actor Visitant
LOGIN Actor Visitant password
WAIT 5000
CHAT almost done
WAIT 5000
LOGOUT
```
```wait
11000
```
```territory
alert Segment 9 Complete
```

#### Iteration 10
```actor Actor Visitant
LOGIN Actor Visitant password
WAIT 5000
CHAT shutting down soon
WAIT 5000
LOGOUT
```
```wait
11000
```
```territory
alert Segment 10 Complete
```

### Curtain Call

```actor Actor Visitant
EXIT
```

```wait
2000
```
