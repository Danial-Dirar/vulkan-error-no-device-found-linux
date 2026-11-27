# Dota 2 crashes on Linux: VK_ERROR_DEVICE_LOST + random segfaults

**Status (2026-11-27):** root cause **confirmed by memtest86+**: RAM errors on **bit 60** (the same bit flipped in the
crash pointers) with 4 mixed DIMMs on XMP 3200. See [2026-11-27_memtest/RESULTS.md](2026-11-27_memtest/RESULTS.md).
Fix (XMP off / DIMM change) not yet applied or verified.

Picking this up? Start with [handout.md](handout.md): what was done, next steps, and the capture/analysis scripts.

## Machine
CachyOS · kernel 7.3.5-2-cachyos · niri 26.04 (Wayland) + xwayland-satellite ·
i5-12400 (Alder Lake) · 32 GB RAM · RTX 3090 · nvidia-open 620.73.04 · Dota 2 native Vulkan.

## Symptoms
- In-game freeze, then either `FATAL ERROR: Vulkan encountered unrecoverable error VK_ERROR_DEVICE_LOST.`
  or a silent close (`Segmentation fault (core dumped)` in Steam's console-linux.txt).
- 8 Dota crashes recorded between 11-25 and 11-27 (11-25 23:21; 11-27 00:13, 00:44, 00:46, 14:07, 14:23, 14:26, 14:48).
  The crashes came faster as the session went on.

## Evidence (details in `2026-11-27_session1/NOTES.md`)
1. **Segfaults always dereference a valid pointer with exactly one high bit flipped (bit 60 or bit 62).**
   This held in all 4 cores examined, across 4 different modules (libclient, libscenesystem, libpanorama,
   librendersystemvulkan/libc) and 4 different threads. Example: `0x2a7e7cf3820` → `0x100002a7e7cf3820`.
2. **The device-lost crash came with `NVRM: Xid 11` (invalid or corrupted push buffer stream)** on the 3D class (`c797`).
   The GPU received a corrupted command stream. NVIDIA lists system memory corruption as a cause.
3. Ruled out:
   - GPU thermal or power (65 °C, ~230 W of 390 W, no throttle at the Xid).
   - CPU thermal (≤ 66 °C).
   - PCIe link degradation (gen4 x16 throughout).
   - A GPU fault as the origin (only one Xid, and it is the "bad input" type, not a GPU-internal fault).
   - Missing shaders (crashes happen with and without the pre-cache).
4. The pattern (identical bit flips across unrelated code) is not what a game or driver bug looks like.
   Dota does not crash like this for the general Linux player base.

5. **Not Dota-specific.** Discord's GPU process (`VizCompositorThread`, 11-27 14:14) crashed with the same
   signature: `rbx = 0x40002944048b36c0`, a valid heap pointer (`0x2944048b36c0`) with bit 62 flipped.
   Saved in `2026-11-27_session1/coredump-discord-4182-info.txt`.
6. **Not caused by gpu-unlock.** The user's `gpu-unlock` DKMS module (Ampere FP16/BF16 unlock: FLR plus GSP
   firmware 610.43.03 before the NVIDIA driver binds; cmdline `gpu_unlock.targets=0000:01:00.0`) was installed on
   2026-10-27. Steam logs show Dota breakpad crash dumps **before** that: 10-02, 10-06, 10-07 (×6+), 10-19, 10-20.
   It stays a secondary suspect only if memtest comes back clean.
7. Crash history from Steam logs: crashes on almost every play day from 10-02 to 11-27, often several per evening.

**Conclusion:** one root cause, two symptoms. Random bit flips in RAM:
- in a pointer → SIGSEGV (SI_KERNEL / general protection);
- in a Vulkan command buffer → Xid 11 → VK_ERROR_DEVICE_LOST.

Likely sources, in order: XMP/memory overclock not stable on this memory controller
(especially with 4 DIMMs or DDR5 on 12th gen), a weak DIMM, or a CPU/SA voltage undervolt.

## RAM configuration (from `dmidecode`, 2026-11-27)
| Slot | Module | Size | Running at |
|---|---|---|---|
| Controller0-DIMMA1 | Kingston FURY Beast `KF3200C16D4/8GX` | 8 GB | 3200 MT/s |
| Controller0-DIMMA2 | Corsair Vengeance LPX `CMK8GX4M1E3200C16` | 8 GB | 3200 MT/s |
| Controller1-DIMMB1 | Kingston FURY Beast `KF3200C16D4/8GX` | 8 GB | 3200 MT/s |
| Controller1-DIMMB2 | Corsair Vengeance LPX `CMK8GX4M1E3200C16` | 8 GB | 3200 MT/s |

DDR4 JEDEC default is 2133/2400, so **3200 means XMP is on**. The setup has 4 DIMMs (2 per channel) and
**two different kits from two vendors in every channel** (different DRAM chips and sub-timings) on XMP.
This is the classic recipe for marginal memory stability, and it is the prime suspect.

## Fix plan
- [x] Record RAM config (see table above).
- [ ] BIOS: confirm XMP profile, and check for any CPU undervolt / voltage tweaks.
- [x] memtest86+-efi 9.00 installed and GRUB entry added (2026-11-27 15:06, snapper snapshots 252/253).
      grub-mkconfig also auto-detected `/boot/memtest86+/memtest86x64.efi`, so there may be two Memtest entries; either works.
- [x] **Confirmed (2026-11-27, ~15:22–15:50)**: memtest86+ with XMP on → **FAIL, 3 errors in 27 min, all on bit 60**
      (5.97 GB, 14.2 GB, 32.4 GB). Details and photos: [2026-11-27_memtest/RESULTS.md](2026-11-27_memtest/RESULTS.md).
      Original plan for this step: reboot, pick "Memtest86+ (RAM test)" in GRUB, and run
      at least 2 full passes **with the current XMP settings**. Errors (especially in high bits) = confirmed.
- [ ] **Fix A (quick A/B test)**: BIOS → XMP off (2133/2400 JEDEC). Play Dota ≥ 1 h. No crash = fixed.
- [ ] **Fix B (keep the speed)**: XMP on, but Command Rate 2T, DRAM voltage 1.35 → ~1.38–1.40 V,
      or drop to 3000/2933 MT/s. Re-run memtest; it must give 0 errors before trusting it.
- [ ] **Fix C (most stable)**: run only one matched pair (2× Kingston or 2× Corsair, in A2+B2) at XMP 3200, 16 GB.
      Optionally replace them with a matched 2×16 GB kit later.
- [ ] If memtest errors appear even at JEDEC: test sticks one at a time to find a bad module.
- [ ] **If memtest is clean after several passes**: A/B the gpu-unlock module. At the GRUB menu press `e` and delete
      `gpu_unlock.targets=0000:01:00.0` (this boot only, nothing changes permanently), then play Dota ≥ 1 h.
- [ ] After the fix: run Dota for a session with the same capture (see session1 NOTES) and log the result here.

## Side issues found (not the cause)
- Steam's zenity error dialog fails (`libgtk-3.so.0: undefined symbol: pango_font_family_get_face`),
  so the game hangs on the in-game fatal dialog and has to be killed.
- Launch option `-dx11` is ignored on Linux (Dota is Vulkan-only there) and can be removed.
- Kernel cmdline contains `gpu_unlock.targets=0000:01:00.0`. Its origin is unknown; check it.
