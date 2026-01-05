---
Title: DNA Verification
ID: dna_verification
---

# DNA Verification Scenario

Verifies that Visitants "shout" their DNA source URL upon login, and that Hippolyzer and LibreMetaverse auto-reply to "dna" inquiries.

## 1. Environment Setup

[#include](templates/prepare_habitat.md)

## 2. Territory Initialization

[#include](templates/territory.initialize-simulation.md)

## 3. Opening Credits (Cast)

```cast
[
    {
        "First": "Benthic",
        "Last": "Visitant",
        "Password": "password",
        "UUID": "11111111-1111-1111-1111-111111111111",
        "Species": "benthic"
    },
    {
        "First": "Hippo",
        "Last": "Visitant",
        "Password": "password",
        "UUID": "22222222-2222-2222-2222-222222222222",
        "Species": "hippolyzer-client"
    },
    {
        "First": "Libre",
        "Last": "Visitant",
        "Password": "password",
        "UUID": "33333333-3333-3333-3333-333333333333",
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

### Part A: Benthic Shout
Benthic logs in. We expect a shout.

```actor Benthic Visitant
LOGIN Benthic Visitant password
```

```await
Title: Benthic Login
Subject: Benthic Visitant
Contains: "sys": "MIGRATION", "sig": "ENTRY"
```

```await
Title: Benthic Shout (Observed by Territory)
Subject: Territory
Contains: My DNA is here: https://github.com/metaverse-crossroads/hypergrid-naturalist-observatory/blob/main/species/benthic/0.1.0/deepsea_client.rs
Timeout: 60000
```

```actor Benthic Visitant
LOGOUT
EXIT
```

### Part B: Hippolyzer Shout & Reply
Hippolyzer logs in. We expect a shout. Then Libre logs in to ask it for DNA.

```actor Hippo Visitant
LOGIN Hippo Visitant password
```

```await
Title: Hippo Login
Subject: Hippo Visitant
Contains: "sys": "MIGRATION", "sig": "ENTRY"
```

```await
Title: Hippo Shout (Observed by Territory)
Subject: Territory
Contains: My DNA is here: https://github.com/metaverse-crossroads/hypergrid-naturalist-observatory/blob/main/species/hippolyzer-client/0.17.0/deepsea_client.py
Timeout: 60000
```

```actor Libre Visitant
LOGIN Libre Visitant password
```

```await
Title: Libre Login
Subject: Libre Visitant
Contains: "sys": "MIGRATION", "sig": "ENTRY"
```

```await
Title: Libre Shout (Observed by Territory)
Subject: Territory
Contains: My DNA is here: https://github.com/metaverse-crossroads/hypergrid-naturalist-observatory/blob/main/species/libremetaverse/src/DeepSeaClient.cs
Timeout: 60000
```

### Part C: Cross-Species Interrogation (IM)

**1. Libre asks Hippo**

Libre is Mimic (DeepSeaClient.cs). Hippo is Hippolyzer.
Libre sends IM to Hippo: "source code?"
Libre uses `IM_UUID` because directory search is broken/complex.
Hippo UUID: `22222222-2222-2222-2222-222222222222`.

```actor Libre Visitant
IM_UUID 22222222-2222-2222-2222-222222222222 Show me your source code please?
```

```await
Title: IM Sent (Libre -> Hippo)
Subject: Libre Visitant
Contains: To: 22222222-2222-2222-2222-222222222222, Msg: Show me your source code please?
Timeout: 10000
```

```await
Title: IM Received (Hippo <- Libre)
Subject: Hippo Visitant
Contains: Msg: Show me your source code please?
Timeout: 10000
```

```await
Title: DNA Reply Sent (Hippo -> Libre)
Subject: Hippo Visitant
Contains: My DNA is here: https://github.com/metaverse-crossroads/hypergrid-naturalist-observatory/blob/main/species/hippolyzer-client/0.17.0/deepsea_client.py
Timeout: 10000
```

**2. Hippo checks statement (Negative Test)**

Hippo sends a statement to Libre: "I like your dna" (no question mark).
Libre should NOT reply.

```actor Hippo Visitant
IM_UUID 33333333-3333-3333-3333-333333333333 I like your dna.
```

```await
Title: IM Sent (Hippo -> Libre) Statement
Subject: Hippo Visitant
Contains: Msg: I like your dna.
Timeout: 10000
```

```await
Title: No Reply Received (Libre -> Hippo)
Subject: Hippo Visitant
Contains: My DNA is here:
Timeout: 5000
Expected: False
```

**3. Hippo asks Libre (Positive Test)**

Hippo sends question to Libre: "What is your dna?"

```actor Hippo Visitant
IM_UUID 33333333-3333-3333-3333-333333333333 What is your dna?
```

```await
Title: IM Sent (Hippo -> Libre) Question
Subject: Hippo Visitant
Contains: Msg: What is your dna?
Timeout: 10000
```

```await
Title: IM Received (Libre <- Hippo)
Subject: Libre Visitant
Contains: Msg: What is your dna?
Timeout: 10000
```

```await
Title: DNA Reply Sent (Libre -> Hippo)
Subject: Libre Visitant
Contains: My DNA is here: https://github.com/metaverse-crossroads/hypergrid-naturalist-observatory/blob/main/species/libremetaverse/src/DeepSeaClient.cs
Timeout: 10000
```

```await
Title: DNA Reply Received (Hippo <- Libre)
Subject: Hippo Visitant
Contains: My DNA is here: https://github.com/metaverse-crossroads/hypergrid-naturalist-observatory/blob/main/species/libremetaverse/src/DeepSeaClient.cs
Timeout: 10000
```

### Curtain Call

```actor Libre Visitant
LOGOUT
EXIT
```

```actor Hippo Visitant
LOGOUT
EXIT
```

```wait
2000
```

```
