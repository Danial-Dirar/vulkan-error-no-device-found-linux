# Session 2: verification at DDR4-2400 (2026-11-27, 18:09–20:03)

**Result: PASS. No segfault, no `NVRM: Xid`, no `VK_ERROR_DEVICE_LOST`, no coredump.**

Setup: same machine and software as session 1. The only change: BIOS DRAM Frequency set manually to DDR4-2400,
which passed memtest86+ with 0 errors ([run 3](../2026-11-27_memtest-2400/RESULTS.md)).
`gpu_unlock` is still loaded (see `system-snapshot.txt`), so it is not needed to explain the crashes either.

## Timeline
| Time | Event |
|---|---|
| 18:09 | `./capture.sh 2026-11-27_session2` started. Steam begins "Processing Vulkan shaders" for patch 7.42a |
| 18:09–18:50 | 12 `fossilize_replay` workers, all CPU threads at 85–100 %, ~1.1 GB RSS each (~11 GB total). Clean, no crashes |
| 18:50:15 | Dota starts (PID 542571) |
| 18:56–18:58 | Internet drops: Steam logs `LogonFailure No Connection`; NetworkManager is back to `CONNECTED_GLOBAL` at 18:58:23 |
| 18:58:18 | Dota exits via `CSteam3Client::Shutdown` and is relaunched at 18:58:20 (PID 624744). No coredump, no fault |
| 18:59:37 | Dota exits again (`CSteam3Client::Shutdown`) right after Steam logs back on. Relaunched at 19:00:00 (PID 641351) |
| 19:00–20:03 | One full match plus menus. Dota still running when the capture stopped at 20:03 (63 min of one process) |

The two exits at 18:58 and 18:59 are clean shutdowns during the network outage, not crashes: no SIGSEGV in the
journal, nothing in `coredumpctl`, no `crash_*.dmp`.

## Checks
| Check | Result |
|---|---|
| `segfault` / `general protection` in the journal | 0 |
| `NVRM` / `Xid` in the journal | 0 |
| `DEVICE_LOST` in the Steam / game logs | 0 |
| `coredumpctl list --since 18:00` | No coredumps found |
| `/tmp/dumps` | 2 `assert_*.dmp` files, both from the **Steam client**, not Dota: 18:08 steamwebhelper `html_chrome.cpp:622 CefCrashReportingEnabled()` (before the capture started), 18:32 `job.cpp:1964` (a Store/Community preferences reply mix-up). Not crashes |

## Load reached (higher than session 1, still stable)
| | Session 1 (DDR4-3200) | Session 2 (DDR4-2400) |
|---|---|---|
| GPU max temperature | 71 °C | 74.5 °C (19:23:37) |
| GPU max power | 302 W | 378 W of 390 W (19:23:34) |
| GPU average during Dota (19:00–20:03) | n/a | 58.8 °C, 164 W |
| CPU package max | 69 °C | 69 °C |
| PCIe | gen4 x16 | gen4 x16 under load (gen1/2 when idle) |
| Crashes | 4 in ~50 min | 0 in ~40 min shader stress + ~70 min Dota |

No thermal or hardware slowdown reason bits were set (`clocks_event_reasons` never had 0x08 / 0x20 / 0x40).
A software power cap bit (0x04) showed for a few seconds at the 378 W peak.

## Side observations
- The user reports **higher FPS** than before. Most likely because the shader cache was built completely this
  time (session 1 skipped it); lowering RAM to 2400 does not raise FPS.
- Shader pre-processing took ~40 min after patch 7.42a and sat at 99 % for a long time. That is normal: the last
  pipelines are the heaviest.

## Files
Committed: `NOTES.md`, `nvidia-smi-1s.csv`, `cpu-sensors-5s.log`, `process-watch.log`, `system-snapshot.txt`.
Local only (privacy, git-ignored): `journal-follow.log`, `steam-logs-follow.log`.
