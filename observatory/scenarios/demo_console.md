# Demo Console Encounter

Verifies the OpenSim console interaction via `director.py`.

## 1. Environment Setup

[#include](templates/prepare_habitat.md)

## 2. Territory Initialization

[#include](templates/territory.initialize-simulation.md)

## 3. Console Interaction

```opensim
# Start Live
```
[#include](templates/territory.await-region.md)

```opensim
show users
```

```await
Title: Console Response (Show Users)
Subject: Territory
Contains: No users found
```

```opensim
shutdown
WAIT_FOR_EXIT
```
