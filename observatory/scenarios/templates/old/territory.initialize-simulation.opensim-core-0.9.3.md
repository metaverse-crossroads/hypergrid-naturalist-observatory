```async-sensor
Title: Abort Trigger Sensor
Subject: Simulant
Contains: Address already in use
director#abort: Aborting due to external trigger: Address already in use!
```

```async-sensor
Title: Region Ready Sensor
Subject: Simulant
Query: matches(line, 'Region "(.*?)" is ready')
director#log: TOOD:$1 is ready!
```

```async-sensor
Title: HTTP Ready Sensor
Subject: Simulant
Contains: Starting HTTP server on port 9000
director#log: HTTP server on port 9000
```


```opensim
# this block just ensures opensim is started
```
