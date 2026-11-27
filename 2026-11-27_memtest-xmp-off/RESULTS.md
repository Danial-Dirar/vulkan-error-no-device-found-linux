# memtest86+ run 2: "XMP off" attempt, 2026-11-27 ~16:18 (FAIL, setting did not take effect)

**What the user did:** set A-XMP to Off in the MSI BIOS, then ran memtest86+ v9.00 with all 4 DIMMs.

**What memtest shows:** `IMC: 1596MHz (DDR4-3192) CAS 16-20-20-38`. The memory was **still at 3200**, the same as run 1.
The user also noticed the RAM stayed at 3200 after XMP off.
Most likely cause: DRAM Frequency is set manually to 3200 in the BIOS OC menu, so turning XMP off only dropped DRAM
voltage to the JEDEC 1.20 V (from the XMP 1.35 V) while the speed stayed at 3200. This is unverified and
needs a look at the BIOS OC page.

**Result:** stopped at 0:06:26 (pass 0, 38 %) with **36 errors**, against 3 errors in 27 min in run 1.

## Visible errors (12 of 36). All are bit 60
| Test | Address | Expected | Found |
|---|---|---|---|
| 5 | `0x000762cae800` (29.5 GB) | `b0a0afc699d8471f` | `a0a0afc699d8471f` |
| 5 | `0x0007a1b46d08` (30.5 GB) | `40eef23b4ecb6b80` | `50eef23b4ecb6b80` |
| 5 | `0x0007ad71c1d0` (30.7 GB) | `2e20917f211a40a8` | `3e20917f211a40a8` |
| 5 | `0x0007e7a64700` (31.6 GB) | `3b50be235d36d6de` | `2b50be235d36d6de` |
| 5 | `0x00082e78a668` (32.7 GB) | `98f362c644ad989f` | `88f362c644ad989f` |
| 6 | `0x000030e148c0` (782 MB) | `bfbfbfbfbfbfbfbf` | `afbfbfbfbfbfbfbf` |
| 6 | `0x0001981e7170` (6.37 GB) | `dfdfdfdfdfdfdfdf` | `cfdfdfdfdfdfdfdf` |
| 6 | `0x0002f048d580` (11.7 GB) | `bfbfbfbfbfbfbfbf` | `afbfbfbfbfbfbfbf` |
| 6 | `0x00035f258e98` (13.4 GB) | `f7f7f7f7f7f7f7f7` | `e7f7f7f7f7f7f7f7` |
| 6 | `0x000397b52dc0` (14.3 GB) | `4040404040404040` | `5040404040404040` |
| 6 | `0x000495caf780` (18.3 GB) | `bfbfbfbfbfbfbfbf` | `afbfbfbfbfbfbfbf` |
| 6 | `0x00082cebe7d0` (32.7 GB) | `4040404040404040` | `5040404040404040` |

In every row the expected and found values differ by exactly `0x1000000000000000` (**bit 60**), in both
directions (0→1 and 1→0). The errors cover the whole range from 782 MB to 32.7 GB.

## Conclusions
- The bit-60 / DQ60 diagnosis is reinforced: 15 of 15 errors seen across both runs are on that one bit.
- At the same 3200 speed, more errors appeared than in run 1, which fits lower DRAM voltage (XMP off → 1.20 V).
  This was not measured.
- XMP off by itself is **not** a valid fix test until the IMC line actually shows DDR4-2133/2400.

## Next
BIOS → OC → DRAM Frequency = DDR4-2133 (or Auto with A-XMP off), DRAM Voltage Auto, timings Auto.
Confirm `IMC ... (DDR4-2133)` on the memtest screen, then run at least 1 full pass.
- 0 errors: the speed was the problem; step up 2666 → 2933 at 1.35 V, running memtest at each step.
- Still bit-60 errors at 2133: a real hardware fault. Test each DIMM alone and each slot; if every DIMM fails on
  one channel, reseat the CPU and check the socket pins (a single failing DQ line across all addresses fits a contact/trace fault).

Photo: `IMG_5485.jpg` (EXIF/GPS stripped).
