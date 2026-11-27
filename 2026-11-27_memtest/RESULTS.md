# memtest86+ result: 2026-11-27 (FAIL, root cause confirmed)

**Setup:** Memtest86+ v9.00 (EFI, booted from GRUB), all 4 DIMMs installed, XMP on.
- Board: MSI PRO B660M-P DDR4 (MS-7D24). CPU: i5-12400, 12 threads in parallel (SMP PAR).
- IMC: 1596 MHz (DDR4-3192), CAS 16-20-20-38.
- SPD: slots 0/2 Kingston KF3200C16D4/8GX (2022-W08); slots 1/3 Corsair CMK8GX4M1E3200C16. All DDR4-3200 XMP.
- CPU temperature 43–50 °C throughout.
- The run was stopped by the user at 0:27:19, during pass 2 (pass 1 complete), after 3 errors.

## Errors
| # | Time | Pass | Test | Failing address | Expected | Found | Flipped bit |
|---|---|---|---|---|---|---|---|
| 1 | ≈ 0:04:51 | 0 | #6 moving inversions, 8-bit pattern | `0x00038d79ccc0` (14.2 GB) | `1010101010101010` | `0010101010101010` | **bit 60**, 1→0 |
| 2 | ≤ 0:16:07 | 0 | #9 moving inversions, 64-bit pattern | `0x00017e879978` (5.97 GB) | `2000000000000000` | `3000000000000000` | **bit 60**, 0→1 |
| 3 | ≤ 0:27:19 | 1 | #3 bus stress, R/W turnaround, random | `0x00081a9f4228` (32.4 GB) | `b6b8720a9d8b97e8` | `a6b8720a9d8b97e8` | **bit 60**, 1→0 |

## What this proves
- **All 3 errors are on bit 60 of the 64-bit word.** That is the same bit flipped in the crash pointers
  (Dota cores 00:44, 14:07, 14:23: `0x1000…` added to a valid pointer). The two bit-62 crashes (14:26 Dota,
  Discord 14:14) did not reproduce in this short run, but they sit in the same byte lane (byte 7, DQ56–63).
- The errors are spread over very different addresses (5.97 GB, 14.2 GB, 32.4 GB) and different test types.
  This is one data line (DQ60) that is marginal at XMP 3200 with 4 mixed DIMMs, not a single bad cell.
- The test ran with no OS, no NVIDIA driver and no gpu-unlock module, so **the GPU, the driver, Dota and the
  gpu-unlock module are ruled out as the cause.**

## Photos
`IMG_5477.jpg` to `IMG_5483.jpg` in this folder: SPD info, first FAIL, all three errors.
EXIF metadata (including GPS) was stripped before committing; the originals stay on the phone / LocalSend folder.
