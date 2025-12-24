# Naturalist Observatory: Interspecies Encounters

## The Interop Scenario

This scenario observes the interaction between two distinct species of Visitants: the .NET-based Mimic and the Rust-based Benthic Deep Sea Variant.

## 1. Environment Setup
Prepare the directories and cleanup previous artifacts.

[#include](templates/setup_environment.md)
[#include](templates/default_estate.md)

## 2. Territory Initialization
Initialize OpenSim to create databases, then stop it.

[#include](templates/init_territory.md)

## 3. Preparation (Casting)

We introduce two Visitants to the range.

```cast
[
  {
    "First": "Mimic",
    "Last": "Observer",
    "Password": "secret",
    "UUID": "11111111-1111-1111-1111-111111111111",
    "Species": "Mimic"
  },
  {
    "First": "Benthic",
    "Last": "Explorer",
    "Password": "secret",
    "UUID": "22222222-2222-2222-2222-222222222222",
    "Species": "Benthic"
  }
]
```

## 4. The Encounter

Start the world and the visitants.

### Territory Live

```opensim
# Start Live
```
[#include](templates/await_default_region.md)
[#include](templates/await_logins_enabled.md)

### 5. Interaction

Mimic enters first.

```mimic Mimic Observer
LOGIN Mimic Observer secret
```

```await
title: Mimic Login
file: vivarium/encounter.interop.visitant.MimicObserver.log
contains: "sig": "Success"
timeout: 30000
```

Benthic enters next.

```mimic Benthic Explorer
# Benthic arguments are handled via startup CLI injection by Director
# But we can verify its log
```

```await
title: Benthic Login
file: vivarium/encounter.interop.visitant.BenthicExplorer.log
contains: "sig": "Success"
timeout: 30000
```

### 6. Communication

Mimic speaks.

```mimic Mimic Observer
CHAT Hello Benthic, can you hear me?
```

Benthic should see Mimic (Presence).

```await
title: Benthic Sees Mimic
file: vivarium/encounter.interop.visitant.BenthicExplorer.log
contains: object update received: Avatar
timeout: 10000
```

(Note: Benthic currently does not support sending chat via CLI/stdin, so we only verify one-way or presence)

### 7. Departure

```mimic Mimic Observer
LOGOUT
EXIT
```

```opensim
QUIT
WAIT_FOR_EXIT
```
