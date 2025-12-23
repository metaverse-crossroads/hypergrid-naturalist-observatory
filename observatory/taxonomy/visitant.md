# Taxonomy: The Standard Visitant

**Identity:** A generic grid-connected agent.
**Role:** To connect, exist, and communicate.

## Automated Criteria (The Critic's Spec)

The following block is ingested by `critic.py`. Do not break the JSON syntax.

```json
{
  "species": "Standard Visitant",
  "rules": [
    {
      "id": "VITAL_SIGNS",
      "description": "Must successfully log in",
      "type": "existence",
      "query": { "system": "Login", "signal": "Success" },
      "critical": true
    },
    {
      "id": "MOTOR_FUNCTION",
      "description": "Must establish UDP before Login Success",
      "type": "topology",
      "before": { "system": "UDP", "signal": "Connected" },
      "after":  { "system": "Login", "signal": "Success" }
    },
    {
      "id": "SOCIAL_HEARING",
      "description": "Must hear chat from another Visitant",
      "type": "existence",
      "query": { "system": "Chat", "signal": "Heard" },
      "critical": false
    }
  ]
}
```