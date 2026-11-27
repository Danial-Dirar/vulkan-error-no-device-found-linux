# memtest86+ run 3: DDR4-2400, 2026-11-27 ~16:33–16:59 (PASS, 0 errors)

**Setting:** BIOS → DRAM Frequency set manually to **2400** (the user chose 2400 rather than 2133). All 4 DIMMs installed.
Memtest shows `IMC: 1196MHz (DDR4-2393) CAS 16-20-20-38`, so the new speed **did take effect** this time,
unlike [run 2](../2026-11-27_memtest-xmp-off/RESULTS.md).

**Result:** **Pass 1 complete at 0:23:50 with 0 errors.** Pass 2 had started and was still at 0 errors at 0:24:01.
CPU temperature 41–49 °C. Memory bandwidth reported by memtest: 32 GB/s (36.1 GB/s at 3200).

## Comparison of all three runs
| Run | Speed (memtest IMC line) | Time run | Errors | Bits |
|---|---|---|---|---|
| 1 | DDR4-3192, XMP on | 27:19 | 3 (first at ≈ 4:51) | all bit 60 |
| 2 | DDR4-3192, "XMP off" (voltage most likely dropped to 1.20 V) | 6:26 | 36 | all visible = bit 60 |
| **3** | **DDR4-2393** | **24:01 (1 full pass)** | **0** | none |

At 3200 errors appeared within about 5 minutes. At 2400 a full pass, covering every test (#0–#10, including
bus stress, moving inversions and bit fade), found none. **The DQ60 errors depend on speed:** the memory
subsystem (4 mixed DIMMs, 2 per channel) is not stable at 3200 but is stable at 2400.

## Status / next
- Memtest: stable at 2400 (1 pass). More passes, e.g. overnight, would add confidence but are optional.
- **Real-world verification still pending:** play Dota for at least 1 h at 2400 while running `./capture.sh <date>_session2`.
  If there are no segfaults, no DEVICE_LOST and no `NVRM: Xid`, the fix is verified.
- Optional later: try 2666 / 2933 (DRAM 1.35 V) with a memtest pass at each step and keep the highest speed that gives 0 errors.

Photos: `IMG_5487.jpg`–`IMG_5491.jpg` (EXIF/GPS stripped). 5487/5488/5489 show pass 1 ending (test #10 bit fade,
0 errors). 5490/5491 show the PASS banner (Pass: 1, Errors: 0).
