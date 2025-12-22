# Field Marks: Instrumentation Instructions

To convert a standard OpenSim specimen into a Naturalist Observatory, we apply the following non-destructive logging probes. These "Field Marks" allow us to observe the "Encounter" between Visitants and the Server without altering the simulation logic.

## 1. The Logger (New Component)
**Action:** Create a new file at `OpenSim/Framework/EncounterLogger.cs`.
**Purpose:** Standardizes all observational output to `[ENCOUNTER] [SIDE] [COMPONENT] MSG`.

**Code:**
```csharp
using System;
using System.IO;
using System.Reflection;
using log4net;

namespace OpenSim.Framework
{
    public static class EncounterLogger
    {
        private static readonly ILog m_log = LogManager.GetLogger(MethodBase.GetCurrentMethod().DeclaringType);
        private static string LogPath = "encounter.log";

        public static void Log(string side, string component, string signal, string payload = "")
        {
            string message = $"[ENCOUNTER] [{side}] [{component}] {signal}";
            if (!string.IsNullOrEmpty(payload))
            {
                message += $" | {payload}";
            }

            // 1. Emit to Console (for stdout capture/Docker logs)
            m_log.Info(message);

            // 2. Emit to File (for forensic redundancy)
            try
            {
                File.AppendAllText(LogPath, $"{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff} {message}{Environment.NewLine}");
            }
            catch (Exception) { /* Best effort only */ }
        }
    }
}
```

## 2. Field Mark: Login Rituals
**Target:** `OpenSim/Services/LLLoginService/LLLoginService.cs`

### A. The Approach (Start of Login)
**Context:** Inside `Login(...)` method, first lines.
**Probe:**
```csharp
EncounterLogger.Log("SERVER", "LOGIN", "RECV XML-RPC login_to_simulator", $"User: {firstName} {lastName}, Viewer: {clientVersion}, Channel: {channel}, IP: {clientIP}");
```

### B. The Challenge (Authentication)
**Context:** Inside the `if (string.IsNullOrWhiteSpace(token) ...)` failure block.
**Probe:**
```csharp
EncounterLogger.Log("SERVER", "LOGIN", "AUTH FAIL", $"User: {firstName} {lastName}");
```
**Context:** After successful authentication (look for `m_GridUserService.GetGridUserInfo`).
**Probe:**
```csharp
EncounterLogger.Log("SERVER", "LOGIN", "AUTH SUCCESS", $"User: {firstName} {lastName}");
```

### C. The Circuit (Provisioning)
**Context:** Inside `if (aCircuit == null)` failure block.
**Probe:**
```csharp
EncounterLogger.Log("SERVER", "LOGIN", "CIRCUIT FAIL", $"Reason: {reason}");
```
**Context:** Immediately after `m_GridUserService.LoggedIn` call.
**Probe:**
```csharp
EncounterLogger.Log("SERVER", "LOGIN", "CIRCUIT PROVISION", $"Circuit: {aCircuit.circuitcode}, Region: {destination.RegionName}");
```

### D. The Acceptance (Response)
**Context:** End of `Login(...)`, before `return response`.
**Probe:**
```csharp
EncounterLogger.Log("SERVER", "LOGIN", "SEND XML-RPC Response", "Success");
```

## 3. Field Mark: UDP Connection Rituals
**Target:** `OpenSim/Region/ClientStack/Linden/UDP/LLUDPServer.cs`

### A. The Handshake (Authorized)
**Context:** Inside `OnNewSource` -> `UseCircuitCode` -> `if (IsClientAuthorized(...))`.
**Probe:**
```csharp
EncounterLogger.Log("SERVER", "UDP", "RECV UseCircuitCode", $"CircuitCode: {uccp.CircuitCode.Code}, Session: {uccp.CircuitCode.SessionID}");
```

### B. The Rejection (Unauthorized)
**Context:** Inside `else` block of `IsClientAuthorized`.
**Probe:**
```csharp
EncounterLogger.Log("SERVER", "UDP", "REJECT UseCircuitCode", $"Unauthorized Circuit: {uccp.CircuitCode.Code}");
```

### C. The Departure (Timeout)
**Context:** Inside `DeactivateClientDueToTimeout`.
**Probe:**
```csharp
EncounterLogger.Log("SERVER", "UDP", "TIMEOUT", $"Agent: {client.Name}, LastActive: {timeoutTicks}ms ago");
```

## 4. Field Mark: Environment & Senses
**Target:** `OpenSim/Region/ClientStack/Linden/UDP/LLClientView.cs`

### A. Region Handshake (The "Where")
**Context:** Inside `SendRegionHandshake`.
**Probe:**
```csharp
EncounterLogger.Log("SERVER", "UDP", "SEND RegionHandshake", $"Region: {m_scene.RegionInfo.RegionName}");
```

### B. Movement (The "Body")
**Context:** Inside `MoveAgentIntoRegion`.
**Probe:**
```csharp
EncounterLogger.Log("SERVER", "UDP", "SEND AgentMovementComplete", $"Pos: {pos}, Look: {look}");
```

### C. Terrain (The "Ground")
**Context:** Inside `SendLayerData`.
**Probe:**
```csharp
EncounterLogger.Log("SERVER", "UDP", "SEND LayerData", "Terrain Patches");
```

### D. Chatter (The "Voice")
**Context:** Inside `ChatFromViewer` or `OnChatFromClient`.
**Probe:**
```csharp
EncounterLogger.Log("Ranger", "Chat", "FromVisitant", args.Message);
```
