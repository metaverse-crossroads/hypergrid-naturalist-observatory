---
Title: Test Visitant REPL Queue
---

# Test Visitant REPL Queue

**Purpose:** Verify that the Visitant REPL processes commands sequentially and respects WAIT commands.

## 1. Setup
```territory
```

```cast
[
    {
        "First": "Test",
        "Last": "Visitant",
        "Password": "password",
        "UUID": "11111111-1111-1111-1111-111111111111",
        "Species": "benthic"
    }
]
```

## 2. The Test

### Sequence

We send a sequence of commands rapidly.
Expected behavior:
1. Login
2. Wait 2000 ms (during which nothing else happens)
3. Chat "After Wait" (should happen after 2s)
4. Logout

```actor Test Visitant
LOGIN Test Visitant password
WAIT 2000
CHAT After Wait
WAIT 2000
LOGOUT
```

```wait
5000
```
