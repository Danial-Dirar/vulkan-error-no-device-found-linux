#!/usr/bin/env bash
# Live log capture while playing Dota 2 (same setup as session 1).
# Usage: ./capture.sh <session-dir-name>     e.g. ./capture.sh 2026-11-28_session2
# Stop with Ctrl+C. Everything is written into ./<session-dir-name>/.
set -uo pipefail

[ $# -eq 1 ] || { echo "usage: $0 <session-dir-name>" >&2; exit 1; }
D="$(cd "$(dirname "$0")" && pwd)/$1"
mkdir -p "$D/dumps"
cd "$D"
STEAM_LOGS=~/.local/share/Steam/logs

# One-time system snapshot
{
  echo "## date"; date
  echo "## uname"; uname -a
  echo "## cmdline"; cat /proc/cmdline
  echo "## nvidia driver"; cat /proc/driver/nvidia/version
  echo "## memory"; grep MemTotal /proc/meminfo
  echo "## packages"; pacman -Q 2>/dev/null | grep -Ei 'nvidia|vulkan|mesa|niri|xwayland|linux-cachyos|steam|gpu-unlock'
  echo "## vulkan"; vulkaninfo --summary 2>&1 | head -40
} > system-snapshot.txt 2>&1

pids=()
# Full journal incl. kernel (NVRM Xid lines, segfault traps)
journalctl -f -o short-iso-precise --since "-5min" > journal-follow.log 2>&1 & pids+=($!)

# GPU telemetry every second
F="timestamp,temperature.gpu,power.draw,power.limit,clocks.gr,clocks.mem,utilization.gpu,memory.used,pstate,clocks_event_reasons.active,pcie.link.gen.current,pcie.link.width.current,fan.speed"
nvidia-smi --query-gpu=$F --format=csv -i 0 >/dev/null 2>&1 || F="${F/clocks_event_reasons/clocks_throttle_reasons}"
nvidia-smi --query-gpu=$F --format=csv -l 1 > nvidia-smi-1s.csv 2>&1 & pids+=($!)

# Game stdout / Steam process + shader logs
tail -n 0 -F "$STEAM_LOGS/console-linux.txt" "$STEAM_LOGS/gameprocess_log.txt" \
  "$STEAM_LOGS/console_log.txt" "$STEAM_LOGS/shader_log.txt" > steam-logs-follow.log 2>&1 & pids+=($!)

# Dota process start/exit timestamps + CPU temperature every 5 s
(
  prev=""
  while true; do
    cur=$(pgrep -a -f 'linuxsteamrt64/dota2' | sort)
    if [ "$cur" != "$prev" ]; then
      { echo "=== $(date '+%F %T.%3N') process change ==="; echo "${cur:-<no dota2 process>}"; } >> process-watch.log
      prev="$cur"
    fi
    if [ $((SECONDS % 5)) -eq 0 ]; then
      echo "$(date '+%T') $(sensors 2>/dev/null | grep -E 'Package id 0|Composite' | tr -s ' ' | tr '\n' ' ')" >> cpu-sensors-5s.log
    fi
    sleep 1
  done
) & pids+=($!)

cleanup() {
  kill "${pids[@]}" 2>/dev/null
  cp -a /tmp/dumps/crash_* dumps/ 2>/dev/null
  echo "Capture stopped. Files in $D"
}
trap cleanup INT TERM EXIT

echo "Capturing into $D  (Ctrl+C to stop)"
wait
