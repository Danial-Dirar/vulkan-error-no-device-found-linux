# Handout: Dota 2 VK_ERROR_DEVICE_LOST investigation

Handoff for whoever picks this up next, whether a future me or a new Claude session.
Findings and evidence: [README.md](README.md). Crash-by-crash log: [2026-11-27_session1/NOTES.md](2026-11-27_session1/NOTES.md).

## Status (2026-11-27, 15:10)
- **Root cause, very likely:** hardware memory bit flips. Corrupted pointers cause segfaults; a corrupted Vulkan
  command stream causes NVIDIA Xid 11 and then VK_ERROR_DEVICE_LOST.
- **Prime suspect:** 4 mixed DIMMs (2× Kingston KF3200C16D4/8GX + 2× Corsair CMK8GX4M1E3200C16, mixed in each channel)
  running XMP 3200 on an i5-12400.
- **CONFIRMED by memtest86+ (2026-11-27):** 3 errors in 27 min with XMP on, all on **bit 60**, the same bit as in the
  crash pointers. See [2026-11-27_memtest/RESULTS.md](2026-11-27_memtest/RESULTS.md).
  The GPU, the driver, Dota and gpu-unlock are ruled out (memtest runs without any of them).
- **Fix: not applied yet.** Next: XMP off → memtest (must be 0 errors) → Dota with `capture.sh`.

## What was done (session 1, 2026-11-27)
1. 13:59: started live capture (journal incl. kernel, nvidia-smi every 1 s, Dota process watch, CPU temps, Steam game logs).
   The commands are now saved as [`capture.sh`](capture.sh).
2. Played Dota. 4 crashes captured: 14:07, 14:23 and 14:26 were segfaults; 14:48 was the DEVICE_LOST dialog + `NVRM: Xid 11`.
3. Read the cores with gdb ([`analyze-core.sh`](analyze-core.sh) does this now). Every general-protection crash
   dereferenced a valid pointer with **one high bit flipped (bit 60 or 62)**, in 4 different libraries and threads.
4. Found two older Dota cores (11-27 00:44 with the same bit flip, and 00:46 with DEVICE_LOST via
   `vkQueueSubmit` → `Plat_FatalError`).
5. GPU/CPU telemetry at every crash: normal temperatures and power, no throttling, PCIe gen4 x16. Thermal and power ruled out.
6. Pulled the RAM inventory with `dmidecode`: 4 mixed DIMMs on XMP.
7. Found that Discord's GPU process crashed with the same bit-flip signature, so the problem is not Dota-specific.
8. Found the user's `gpu-unlock` DKMS module (installed 2026-10-27). Steam logs show Dota crash dumps from
   2026-10-02 onward, so it is not the original cause. It stays a secondary suspect only.
9. Installed memtest86+-efi 9.00 and added a GRUB entry ([`setup-memtest-grub.sh`](setup-memtest-grub.sh),
   snapper snapshots 252/253 before and after).

## Next steps, in order
1. ~~memtest86+ with XMP on~~ **Done: FAIL, bit 60** ([RESULTS.md](2026-11-27_memtest/RESULTS.md)).
   ~~XMP off~~ **Did not lower the speed** (still DDR4-3192, 36 errors in 6.5 min, all bit 60): [run 2](2026-11-27_memtest-xmp-off/RESULTS.md).
2. **BIOS (MSI PRO B660M-P): OC → DRAM Frequency = DDR4-2133** (XMP off alone left it at 3200), DRAM Voltage Auto, timings Auto. Check that memtest shows `DDR4-2133`. Re-run memtest ≥ 1 full pass; it must be 0 errors.
3. Play Dota ≥ 1 h while running `./capture.sh <date>_session2`. No crash = fixed.
4. Optional, to get the speed back: test each kit alone at XMP (2× Kingston in A2+B2, then 2× Corsair) with memtest
   to find the weak side, or run all 4 at 3000/2933, or 3200 with Command Rate 2T / DRAM ~1.38–1.40 V.
   Anything you keep must pass memtest with 0 errors.
5. If errors persist even at JEDEC: test one stick at a time to find a bad module.
4. After any crash during verification: `./analyze-core.sh <pid> <session-dir>` and check for the stray-high-bit registers.
5. Record the outcome in README.md (tick the fix-plan boxes) and in the session's NOTES.md.

## Tools in this repo
| File | Purpose |
|---|---|
| `capture.sh <session-dir>` | Start all live captures; Ctrl+C stops them and copies `/tmp/dumps` crash files |
| `analyze-core.sh <pid> [dir]` | coredump info + gdb registers + bit-flip check for one crashed process |
| `setup-memtest-grub.sh` | (already run) installs memtest86+-efi and adds the GRUB entry |

## What is NOT in git (privacy)
The raw captures contain the Steam ID, LAN IPs and MAC addresses, emails from the system journal, and process memory
(minidumps). `.gitignore` keeps these local only:
`dumps/`, `journal-follow.log`, `steam-logs-follow.log`, `hang*-snapshot-*.txt`, `historical-steam-devicelost.txt`.
Everything they proved is quoted in NOTES.md / README.md. Machine/Boot IDs were removed from the committed
coredump summaries. The full cores remain in `/var/lib/systemd/coredump/` until systemd rotates them.

## Side issues (not the cause)
- Steam's zenity fatal-error dialog fails (`pango_font_family_get_face` undefined), so the game hangs on the in-game dialog.
- `-dx11` launch option does nothing on Linux.
