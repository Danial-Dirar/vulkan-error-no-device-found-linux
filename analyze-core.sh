#!/usr/bin/env bash
# Inspect a systemd-coredump for the bit-flip signature found in session 1.
# Usage: ./analyze-core.sh <pid> [output-dir]
# Writes coredump-<pid>-info.txt and gdb-core-<pid>.txt, then prints registers that hold
# a pointer with one stray high bit set (pattern 0x?000xxxxxxxxxxxx, e.g. 0x100002a7e7cf3820).
set -uo pipefail

[ $# -ge 1 ] || { echo "usage: $0 <pid> [output-dir]" >&2; exit 1; }
P=$1
OUT=${2:-.}

coredumpctl info "$P" --no-pager | grep -v -E '^\s*(Machine ID|Boot ID):' > "$OUT/coredump-$P-info.txt" 2>&1
grep -E 'TID|Signal|Timestamp' "$OUT/coredump-$P-info.txt"
grep -m1 -A5 'Stack trace of thread' "$OUT/coredump-$P-info.txt"

coredumpctl debug "$P" --debugger-arguments="-batch -nx -ex 'set pagination off' -ex 'info registers' -ex 'x/3i \$pc'" 2>&1 \
  | grep -v -E '^\[New LWP|warning:|debuginfod' | tail -40 > "$OUT/gdb-core-$P.txt"

echo "--- faulting instruction"
grep -m1 '=>' "$OUT/gdb-core-$P.txt"
echo "--- registers with a stray high bit (bit-flip candidates)"
grep -E '^r[a-z0-9]+ +0x[1-9a-f]000[0-9a-f]{12} ' "$OUT/gdb-core-$P.txt" || echo "(none)"
