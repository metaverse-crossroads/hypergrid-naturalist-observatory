---
territory: opensim-core-0.9.3
---

# WebRTC Interop Encounter

A mixed-species encounter with two libremetaverse-2.5.7.90 visitants utilizing voice.

## 1. Environment Setup

[#include](templates/prepare_habitat.md)

## 2. Territory Initialization

[#include](templates/territory.initialize-simulation.md)

## 3. Opening Credits (Cast)

```cast
[
    {
        "First": "Visitant",
        "Last": "One",
        "Password": "password",
        "UUID": "11111111-1111-1111-1111-111111111111",
        "Species": "libremetaverse-2.5.7.90"
    },
    {
        "First": "Visitant",
        "Last": "Two",
        "Password": "password",
        "UUID": "22222222-2222-2222-2222-222222222222",
        "Species": "libremetaverse-2.5.7.90"
    }
]
```

## 4. The Encounter

### Territory Live

```opensim
# Start Live
```
[#include](templates/territory.await-region.md)

### Visitant One

```mimic Visitant One
LOGIN Visitant One password
```

```await
Title: Visitant One Presence (Self)
Subject: Visitant One
Contains: "sys": "MIGRATION", "sig": "ENTRY"
Timeout: 14000
```

```mimic Visitant One
CHAT Connecting to voice...
VOICE_CONNECT
```

### Visitant Two

```mimic Visitant Two
LOGIN Visitant Two password
```

```await
Title: Visitant Two Presence (Self)
Subject: Visitant Two
Contains: "sys": "MIGRATION", "sig": "ENTRY"
Timeout: 4000
```

```await
Title: Visitant Two Presence (Territory)
Subject: Territory
Contains: "sys": "MIGRATION", "sig": "ARRIVAL", "val": "Visitant Two"
Timeout: 4000
```

```await
Title: Visitant Two Presence (Peer)
Subject: Visitant One
Contains: "sys": "SENSORY", "sig": "VISION"
Timeout: 4000
```

```mimic Visitant Two
CHAT Connecting to voice...
VOICE_CONNECT
```

```await
Title: Server Provisioned Voice Capability
Subject: Territory
Contains: "sys": "VOICE", "sig": "PROVISION_CAP"
Timeout: 8000
```

```await
Title: Server Provisioned Voice Session
Subject: Territory
Contains: "sys": "VOICE", "sig": "PROVISION_REQUEST"
Timeout: 8000
```

```await
Title: Visitant One Voice Connected
Subject: Visitant One
Contains: "sys": "VOICE", "sig": "PROVISION_SUCCESS"
Timeout: 4000
```

```await
Title: Visitant Two Voice Connected
Subject: Visitant Two
Contains: "sys": "VOICE", "sig": "PROVISION_SUCCESS"
Timeout: 4000
```


```await
Title: Visitant Two Voice Complete
Subject: Visitant Two
Contains: Voice signaling complete
Timeout: 10000
```

```await
Title: Server Processed SDP
Subject: Territory
Contains: "sys": "VOICE", "sig": "SDP_COMPLETE"
Timeout: 4000
```

```opensim
sorcery
```

```mimic Visitant Two
WAIT 2000
VOICE_PLAY vivarium/opensim-core-0.9.3/OpenSim/Region/CoreModules/World/Archiver/Tests/Resources/test-sound.wav
```

```await
Title: Visitant Two Voice Played
Subject: Visitant Two
Contains: "sys": "VOICE", "sig": "PLAY_WAV"
Timeout: 4000
```

```wait
3000
```

```opensim
sorcery observatory
```

```wait
3000
```

```opensim
sorcery observatory
```

