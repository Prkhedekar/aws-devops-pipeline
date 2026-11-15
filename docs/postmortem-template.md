# Post-incident report: <short title>

<!-- Blameless format: focus on systems and process, not people. -->

| | |
|---|---|
| **Date** | YYYY-MM-DD |
| **Duration** | e.g. 14 minutes |
| **Impact** | e.g. 100% of API requests returned 503 |
| **Detected by** | e.g. Grafana alert / manual check |

## Summary

Two or three sentences: what broke, why, and how it was fixed.

## Timeline

| Time | Event |
|---|---|
| 10:02 | Change deployed |
| 10:04 | Alert fired |
| 10:09 | Root cause identified |
| 10:16 | Fix deployed, service recovered |

## Root cause

What actually caused it, and why the system allowed it to happen.

## What went well

## What went poorly

## Action items

| Action | Type (prevent / detect / mitigate) | Status |
|---|---|---|
| | | |

<!-- Ideas for a deliberate test incident: delete the Postgres pod, deploy an image tag that
     doesn't exist, set the CPU limit too low, fill the database volume. -->
