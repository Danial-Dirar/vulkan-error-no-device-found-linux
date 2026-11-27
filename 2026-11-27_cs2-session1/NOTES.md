# CS2 session 1: at DDR4-2400 (2026-11-27, 20:07–20:53)

**Result: no crash.** No segfault, no `NVRM: Xid`, no `VK_ERROR_DEVICE_LOST`, no coredump.
CS2 uses the same Source 2 / Vulkan engine as Dota 2, so this is a second, shorter check of the same fix.

## Timeline
| Time | Event |
|---|---|
| 20:07 | `./capture.sh 2026-11-27_cs2-session1` started (process watch now matches `cs2` as well as `dota2`) |
| 20:09–20:28 | Steam "Processing Vulkan shaders" for CS2 (`fossilize_replay`, all CPU threads). Ran to completion |
| 20:29:38 | `fossilize_replay completed` |
| 20:29:40 | CS2 starts (PID 1544812) |
| 20:37:06 | CS2 closed **by the user** (`AppID 730 exited`). No coredump, no fault |

## Checks
| Check | Result |
|---|---|
| `segfault` / `general protection` / `NVRM` / `Xid` in the journal | 0 |
| `DEVICE_LOST` / fatal error in the Steam / game logs | 0 |
| `coredumpctl list --since 20:05` | No coredumps found |
| New files in `/tmp/dumps` | None |
| GPU max | 62 °C, 273 W (both at 20:36:58, just before the exit) |
| CPU package max | 59 °C |

One `clocks_event_reasons` sample (20:09:34, 52 °C, during shader compiling) had 0x424; all others were idle
(0x1) or 0x400. Not a concern at that temperature.

## Caveat
Only ~7.5 min in game, so on its own this is weak evidence. The ~20 min of all-core shader compiling before it
is the stronger part. The main verification is the Dota session: [../2026-11-27_session2/NOTES.md](../2026-11-27_session2/NOTES.md).

## Files
Committed: `NOTES.md`, `nvidia-smi-1s.csv`, `cpu-sensors-5s.log`, `process-watch.log`, `system-snapshot.txt`.
Local only (privacy, git-ignored): `journal-follow.log`, `steam-logs-follow.log`.
