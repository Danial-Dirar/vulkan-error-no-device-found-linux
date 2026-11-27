# Handout: Dota 2 VK_ERROR_DEVICE_LOST investigation

Handoff for whoever picks this up next, whether a future me or a new Claude session.
Findings and evidence: [README.md](README.md). Crash-by-crash log: [2026-11-27_session1/NOTES.md](2026-11-27_session1/NOTES.md).

## Status (2026-11-27, 15:10)
- **Root cause, very likely:** hardware memory bit flips. Corrupted pointers cause segfaults; a corrupted Vulkan
  command stream causes NVIDIA Xid 11 and then VK_ERROR_DEVICE_LOST.
- **Prime suspect:** 4 mixed DIMMs (2× Kingston KF3200C16D4/8GX + 2× Corsair CMK8GX4M1E3200C16, mixed in each channel)
  running XMP 3200 on an i5-12400.
- **Not confirmed yet.** Next step is memtest86+, which is installed and ready in GRUB.
- **Fix: not applied yet.**

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
1. **memtest86+**: reboot → GRUB → "Memtest86+ (RAM test)" → at least 2 passes **with XMP still on**.
   Photograph the result (passes, error count, failing addresses and bits).
2. **Errors found:** BIOS → XMP off (JEDEC) → play Dota ≥ 1 h while running `./capture.sh <date>_session2`.
   If stable, optionally try XMP at 3000 or 3200 with 2T / DRAM ~1.38–1.40 V (memtest must give 0 errors),
   or keep only one matched pair of sticks.
3. **No errors:** A/B the gpu-unlock module. At GRUB press `e` and remove `gpu_unlock.targets=0000:01:00.0`
   (this boot only), then play Dota ≥ 1 h with capture running.
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
