# Dota 2 – VK_ERROR_DEVICE_LOST investigation · Session 1 (2026-11-27)

## System
- CachyOS, kernel 7.3.5-2-cachyos, niri 26.04 (Wayland) + xwayland-satellite 0.8.3
- i5-12400, RTX 3090, nvidia-open 620.73.04
- Kernel cmdline has `gpu_unlock.targets=0000:01:00.0` (unusual, needs a check)
- Dota launched natively (linuxsteamrt64), args: `+@panorama_min_comp_layer_dimension 0 -prewarm_panorama -dx11`
- Shader pre-cache was **skipped** at 10% before this run

## Live capture (started 13:59)
| File | What it holds |
|---|---|
| journal-follow.log | full system journal incl. kernel (NVRM Xid) from 13:29 onward |
| nvidia-smi-1s.csv | GPU temp/power/clocks/throttle reasons/PCIe link, every 1 s |
| process-watch.log | timestamps of dota2 start/exit (= crash time) |
| cpu-sensors-5s.log | CPU package temperature |
| steam-logs-follow.log | game stdout (console-linux.txt), gameprocess, shader logs |
| system-snapshot.txt | driver, packages, Vulkan, module params |
| dumps/ | copies of /tmp/dumps minidumps |

## Pre-session findings
- No `NVRM: Xid` lines in the kernel log over the last 30 days (5 boots), so either
  the device-lost happens without a kernel-visible GPU fault, or the crashes are older than the journal.
- /tmp/dumps had only a 13:45 Steam webhelper assert dump (not Dota).

## Crash #1 — 14:07:33 (in match, ~8 min after launch)
- User saw: game froze, then closed. **No device-lost dialog this time.**
- `dota.sh: line 118: 42432 Segmentation fault (core dumped)` at 14:07:53. The crash itself was at 14:07:33;
  the 20 s gap is breakpad writing `crash_20261127140733_17.dmp` and the kernel writing the core.
- Faulting thread: `GlobPool/4` (engine job-pool worker), SIGSEGV `si_code=SI_KERNEL`
  (= general-protection fault, usually a garbage/non-canonical pointer, not a plain NULL).
- Top of stack: `libscenesystem.so +0x2de53b` ← +0x2e014c ← +0x2e1168 ← +0x2e144e ← libtier0 thread pool.
  Faulting module is Valve's scene system, **not** the NVIDIA driver (`libnvidia-*`).
- **No NVRM Xid** in the kernel log. The GPU did not fault.
- GPU at crash: 66 °C, 261 W of 390 W, 1980 MHz core / 9501 MHz mem, PCIe gen4 x16. No thermal or power problem.
  Utilization dropped 43 % → 2 % at 14:07:34, so rendering stopped at the moment of the crash.
- Last game console lines: `Too many non-culled draws (alloc 768, need 928), resizing!` (468 s), then panorama noise,
  then `Engine2PreBreakpadDumpFunction` (489.87 s).
- Artifacts: `coredump-42432-info.txt`, `dumps/crash_20261127140733_17.dmp`, `crash1-game-console-tail.txt`,
  `hang-snapshot-140759.txt` (taken after the exit, so it only shows the idle GPU).
  Full core: `/var/lib/systemd/coredump/core.dota2.1000.66c93c8444d446369c458fa376f362fb.42432.1795766853000000.zst` (1.1 GB).
- Relaunched 14:08:18 (pid 68792).

## Crash #2 — 14:23:19 (in match, ~15 min after relaunch)
- Freeze then exit. The "stuck" period is breakpad + systemd-coredump writing a 1.1 GB core (~20 s).
- Thread `GlobPool/3`, SIGSEGV `SI_KERNEL`, top frame `libpanorama.so +0x30ad98` (UI library, different from crash #1).
- Faulting instruction: `lock subl $0x1,0x8(%rdi)` (refcount decrement), with `rdi = 0x100002a7e7cf3820`.
- No Xid, no MCE. Files: `coredump-68792-info.txt`, `gdb-core-68792.txt`, `dumps/crash_20261127142319_2.dmp`, `crash2-game-console-tail.txt`.

## KEY FINDING: the same bit (bit 60) is flipped in the bad pointer every time
gdb on the cores (`gdb-core-*.txt`) shows that each SI_KERNEL (general-protection) crash dereferences a pointer
that is a valid pointer **plus bit 60 (0x1000000000000000)**, which makes it non-canonical:

| Crash | Thread | Module | Instruction | Bad value | Valid value under it |
|---|---|---|---|---|---|
| 11-27 00:44:37 | main | libclient.so | `call *%r9` | `0x10007f34ff60d1e0` | `0x7f34ff60d1e0` (code address inside libclient) |
| 11-27 14:07:33 | GlobPool/4 | libscenesystem.so | `movzwl 0x14(%r9)` | `0x100002869afbe000` | `0x2869afbe000` (game heap, matches other regs `0x286…`) |
| 11-27 14:23:19 | GlobPool/3 | libpanorama.so | `lock subl $1,0x8(%rdi)` | `0x100002a7e7cf3820` | `0x2a7e7cf3820` (game heap, matches other regs `0x2a7…`) |

Three different libraries and three different threads, but the same single bit at the same position.
That is the signature of a hardware single-bit error (RAM / memory controller / CPU), not of a game bug.
A game bug would not corrupt a function pointer, a heap object pointer and a refcount array in the same way,
and Dota does not crash like this for other Linux players. Alder Lake has no Intel LAM, so pointer-tagging hardware is ruled out.

## Crash 11-27 00:46:32: the VK_ERROR_DEVICE_LOST crash (from the previous boot's core)
- Thread `VKRenderThread`, stack: librendersystemvulkan → `Plat_FatalError` (deliberate abort).
- Game log in the core:
  - `ERROR! VK call failed! result = VK_ERROR_DEVICE_LOST ( vkQueueWaitIdle( VulkanQueue() ) )`
  - `ERROR! VK call failed! result = VK_ERROR_DEVICE_LOST ( vkQueueSubmit( pQueue, 1, &submitInfo, pFence->Get() ) )`
  - `FATAL ERROR: Vulkan encountered unrecoverable error VK_ERROR_DEVICE_LOST.` (73 s after launch)
- Happened 2 minutes after the 00:44 bit-60 crash. No Xid in the kernel log.
- Working theory: the same memory corruption hits data the game hands to the NVIDIA driver (command buffers,
  descriptors, GPU addresses). The driver or GPU rejects the result and reports DEVICE_LOST.
  So "device lost" and the segfaults look like **one root cause with two symptoms**.

## Next steps (planned)
1. Check BIOS: is XMP enabled? What RAM kit and speed? Is there any CPU undervolt or load-line tweak?
2. Run memtest86+ (several passes) and/or `memtester` under load.
3. Disable XMP (run at JEDEC speed) or loosen it, then replay Dota and see whether the bit-60 crashes stop.

## Crash #3 — 14:26:26 (only ~50 s after the 14:25:37 relaunch)
- Thread `VKRenderThread`, SIGSEGV `SI_KERNEL`, in libc (memcpy-like) called from `librendersystemvulkan.so +0x551dbd`.
- Five registers hold the same corrupted heap pointer: `rbx = rdi = r13 = 0x400002efb0abf290`, `r9 = 0x400002efb0abf158`, `r12 = 0x400002efb0abf140`.
  Valid value: `0x2efb0abf290` (heap; `rsi = 0x2ef5e309620` is a clean neighbour). This time **bit 62** is flipped, not bit 60.
- Updated pattern: 4 of 4 GPF crashes have exactly **one extra high bit set (bit 60 or bit 62, both in the top byte)** in an otherwise valid pointer.
  Only flips in the top bits make a pointer non-canonical and crash at once. A flip in a low bit gives silent corruption or another symptom
  (e.g. bad GPU commands → DEVICE_LOST). So the bits we see are biased by which flips crash, which fits random hardware bit flips.
- This crash was in the **Vulkan render thread**: corrupted render data is exactly the route by which the same fault ends in VK_ERROR_DEVICE_LOST.
- Crash rate is rising during the session: 14:07 → 14:23 → 14:26. Possibly heat-related (RAM/CPU warming up).
- Files: `coredump-106827-info.txt`, `gdb-core-106827.txt`, `dumps/crash_20261127142626_2.dmp`.
- Relaunched 14:27:09 (pid 116325).

## Crash #4 — 14:48:21: VK_ERROR_DEVICE_LOST caught live (with a kernel Xid this time)
- User screenshot: `FATAL ERROR: Vulkan encountered unrecoverable error VK_ERROR_DEVICE_LOST.` dialog, in a match.
  The game hung on the dialog; the user killed it from btop at 14:50:10, so there is no core/minidump.
- Kernel at the same second:
  ```
  NVRM: Xid (PCI:0000:01:00): 11, pid=116325, name=dota2, channel 0x00000027 Cl 0000c797 Off 0000072c Data 200201cd
  ```
  - **Xid 11 = "Invalid or corrupted push buffer stream"**: the GPU front-end read a command it could not decode.
    Class `c797` = AMPERE_A (3D engine), so the bad command was in Dota's graphics command stream.
    NVIDIA's documented causes for Xid 11: driver bug, **system memory corruption**, bus error, thermal issue.
  - GPU at that second: 65 °C, 227 W of 390 W, PCIe gen4 x16, no throttling. CPU package 49 °C. Thermal and power are ruled out.
- This links the segfaults and the device-lost errors: the CPU builds the GPU command buffer in RAM.
  A flipped bit there makes the GPU see garbage (Xid 11) and the driver reports DEVICE_LOST.
  A flipped bit in a pointer gives the SI_KERNEL segfaults. **One root cause, two symptoms.**
- Side note: Steam's zenity error dialog fails (`libgtk-3.so.0: undefined symbol: pango_font_family_get_face`).
  That is cosmetic, but it is why the game sits on the in-game dialog instead of exiting cleanly.
- Relaunched 14:50:30 (pid 169540).

## Session end
- Last run (pid 169540, 14:50:30 → 15:01:29) closed normally by the user. No crash.
- All captures stopped at ~15:02. Summary and fix plan: `../README.md`.
