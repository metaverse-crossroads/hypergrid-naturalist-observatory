[#include](templates/prepare_habitat.md)

```opensim
create user Verifiable User password test@example.com 11111111-1111-1111-1111-111111111111 default
```

[#include](templates/territory.await-region.md)
<!-- [#include](templates/territory.await-login-service.md) -->

```mimic Verifiable User
LOGIN Verifiable User password
```
```await
Title: Verifiable User Present (Territory)
Subject: Territory
Contains: "val": "Verifiable User"
Timeout: 4000
```

```opensim
show users
```

```await
Title: Console Response (Show Users)
Subject: Simulant
Contains: agents in region
Timeout: 2000
```

```opensim
shutdown
WAIT_FOR_EXIT
```
