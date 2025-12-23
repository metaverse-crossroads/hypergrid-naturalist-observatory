# Field Marks: Instrumentation Instructions

To convert a standard OpenSim specimen into a Naturalist Observatory, we apply the following non-destructive logging probes. These "Field Marks" allow us to observe the "Encounter" between Visitants and the Server without altering the simulation logic.

## 0. Clean Room Protocol (Patch Recovery)

**If a patch fails to apply:**
1.  **Do NOT** edit the `.patch` file directly. Context lines are fragile.
2.  **Create** a temporary workspace (`/tmp/recovery`).
3.  **Clone** a clean version of the upstream repository into `a/` (e.g., `git clone ... opensim a`).
4.  **Copy** `a/` to `b/`.
5.  **Surgically Apply** the change to the file in `b/` using standard tools (text editor, `sed`, etc.).
6.  **Generate** a new patch: `diff -uNr a b > MyPatch.patch`.
7.  **Replace** the broken patch file in the `species/` directory with `MyPatch.patch`.

## 1. The Logger (New Component)
**Action:** Create a new file at `OpenSim/Framework/EncounterLogger.cs`.
**Purpose:** Standardizes all observational output to the "JSON Fragment Ritual".

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

        // The Ritual of the fragment
        public static void Log(string side, string system, string signal, string payload = "")
        {
            // 1. Time: Millisecond precision, strictly ISO.
            string at = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ");

            // 2. Sanitation: Prevent the payload from breaking the fragment.
            // We only fear the double quote.
            if (!string.IsNullOrEmpty(payload))
                payload = payload.Replace("\"", "\\\"");

            // 3. The Injection (Manual formatting for zero-dependency)
            // Keys are short to keep it scannable. Order is chronological/hierarchical.
            string fragment = $"{{ \"at\": \"{at}\", \"via\": \"{side}\", \"sys\": \"{system}\", \"sig\": \"{signal}\", \"val\": \"{payload}\" }}";

            // 4. Emission
            // Log to console/standard log for visibility
            m_log.Info(fragment);

            // Also append to a specific file for the report
            try
            {
                File.AppendAllText(LogPath, fragment + Environment.NewLine);
            }
            catch (Exception) { /* Best effort only */ }
        }
    }
}
```

## 2. Field Mark: Login Rituals
**Target:** `OpenSim/Services/LLLoginService/LLLoginService.cs`

### A. The Acceptance (Response)
**Context:** End of `Login(...)` method, before `return response`.
**Probe:**
```csharp
EncounterLogger.Log("Ranger", "Login", "VisitantLogin", $"{firstName} {lastName}");
```

## 3. Field Mark: UDP Connection Rituals
**Target:** `OpenSim/Region/ClientStack/Linden/UDP/LLUDPServer.cs`

### A. The Handshake (Authorized)
**Context:** Inside `UseCircuitCode` -> `if (IsClientAuthorized(...))`.
**Probe:**
```csharp
EncounterLogger.Log("Ranger", "UDP", "UseCircuitCode", $"{uccp.CircuitCode.Code} from {endPoint}");
```

## 4. Field Mark: Environment & Senses
**Target:** `OpenSim/Region/ClientStack/Linden/UDP/LLClientView.cs`

### A. Chatter (The "Voice")
**Context:** Inside `HandleChatFromViewer`, before invoking `OnChatFromClient`.
**Probe:**
```csharp
EncounterLogger.Log("Ranger", "Chat", "FromVisitant", args.Message);
```
