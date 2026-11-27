#!/usr/bin/env bash
# Install memtest86+ (EFI) and add a GRUB menu entry for it.
# Run with: sudo bash setup-memtest-grub.sh
# Layout this was written for: GRUB 2.16, ESP = /boot/efi (vfat, UUID ED6E-D6A0), Secure Boot disabled.
set -euo pipefail

ESP=/boot/efi
ESP_UUID=$(findmnt -no UUID "$ESP")

pacman -S --needed --noconfirm memtest86+-efi

SRC=$(pacman -Ql memtest86+-efi | awk '/\.efi$/ {print $2; exit}')
[ -n "$SRC" ] || { echo "memtest .efi not found in package" >&2; exit 1; }

# Copy onto the FAT ESP so GRUB can chainload it without touching btrfs.
install -Dm644 "$SRC" "$ESP/memtest86+/memtest.efi"

if ! grep -q 'Memtest86+' /etc/grub.d/40_custom; then
  cp /etc/grub.d/40_custom /etc/grub.d/40_custom.bak-before-memtest
  cat >> /etc/grub.d/40_custom <<EOF

menuentry "Memtest86+ (RAM test)" {
    insmod part_gpt
    insmod fat
    insmod chain
    search --no-floppy --fs-uuid --set=root $ESP_UUID
    chainloader /memtest86+/memtest.efi
}
EOF
fi

grub-mkconfig -o /boot/grub/grub.cfg
grep -n 'Memtest86+' /boot/grub/grub.cfg && echo "OK: reboot and pick 'Memtest86+ (RAM test)' in the GRUB menu."
