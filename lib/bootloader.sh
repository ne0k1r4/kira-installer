#!/usr/bin/env bash
# 🍎 KIRA INSTALLER — The Crown (Bootloader & Microcode)

# ======================================================================
# DETECT CPU MICROCODE
# ======================================================================
bootloader_detect_microcode() {
    if grep -q "GenuineIntel" /proc/cpuinfo; then
        MICROCODE="intel-ucode"; MICROCODE_FILE="intel-ucode.img"
    elif grep -q "AuthenticAMD" /proc/cpuinfo; then
        MICROCODE="amd-ucode"; MICROCODE_FILE="amd-ucode.img"
    else
        MICROCODE=""; MICROCODE_FILE=""
    fi
    export MICROCODE MICROCODE_FILE
}

# ======================================================================
# DETECT TARGET BOOT MODE
# ======================================================================
bootloader_target_mode() {
    arch-chroot "$1" test -d /sys/firmware/efi 2>/dev/null && echo "uefi" || echo "bios"
}

# ======================================================================
# INSTALL MAIN BOOTLOADER
# ======================================================================
bootloader_install() {
    local uuid=""

    if [ "${ENCRYPTION:-none}" != "none" ]; then
        local encrypted_part
        encrypted_part=$(cat "$STATE_DIR/encrypted-part" 2>/dev/null)
        [ -z "$encrypted_part" ] && [ -n "${ENCRYPTED_PART:-}" ] && encrypted_part="$ENCRYPTED_PART"
        [ -z "$encrypted_part" ] && log "ERROR" "Cannot determine encrypted partition" && return 1
        uuid=$(blkid -s UUID -o value "$encrypted_part" 2>/dev/null)
        [ -z "$uuid" ] && log "ERROR" "Failed to get UUID for $encrypted_part" && return 1
    else
        uuid=$(blkid -s UUID -o value "$ROOT_PART" 2>/dev/null)
        [ -z "$uuid" ] && log "ERROR" "Failed to get UUID for $ROOT_PART" && return 1
    fi
    
    local target_mode
    target_mode=$(bootloader_target_mode "/mnt")
    log "INFO" "Target boot mode: $target_mode"
    
    if [ "$target_mode" = "uefi" ]; then
        _bootloader_install_systemd "$uuid"
    else
        _bootloader_install_grub "$uuid"
    fi
}

# ======================================================================
# INSTALL SYSTEMD-BOOT (UEFI)
# ======================================================================
_bootloader_install_systemd() {
    local uuid="$1"
    execute arch-chroot /mnt bootctl install
    
    local cmdline=""
    if [ "$ENCRYPTION" = "luks2+lvm" ]; then
        cmdline="cryptdevice=UUID=$uuid:cryptlvm root=/dev/vg0/root rw quiet"
    elif [ "$ENCRYPTION" = "luks2" ]; then
        cmdline="cryptdevice=UUID=$uuid:cryptroot root=/dev/mapper/cryptroot rw quiet"
    else
        cmdline="root=UUID=$uuid rw quiet"
    fi
    
    cat > /mnt/boot/loader/entries/arch.conf << EOF
title Arch Linux (KIRA)
linux /vmlinuz-linux
EOF
    [ -n "$MICROCODE_FILE" ] && echo "initrd /$MICROCODE_FILE" >> /mnt/boot/loader/entries/arch.conf
    cat >> /mnt/boot/loader/entries/arch.conf << EOF
initrd /initramfs-linux.img
options $cmdline
EOF

    cat > /mnt/boot/loader/entries/arch-fallback.conf << EOF
title Arch Linux (KIRA - Recovery)
linux /vmlinuz-linux
EOF
    [ -n "$MICROCODE_FILE" ] && echo "initrd /$MICROCODE_FILE" >> /mnt/boot/loader/entries/arch-fallback.conf
    cat >> /mnt/boot/loader/entries/arch-fallback.conf << EOF
initrd /initramfs-linux-fallback.img
options $cmdline
EOF

    cat > /mnt/boot/loader/loader.conf << 'EOF'
default arch.conf
timeout 4
EOF
}

# ======================================================================
# INSTALL GRUB (BIOS / DUAL LVM SUPPORT)
# ======================================================================
_bootloader_install_grub() {
    local uuid="$1"
    execute arch-chroot /mnt grub-install "$SELECTED_DISK"
    
    local grub_cmdline=""
    if [ "$ENCRYPTION" = "luks2+lvm" ]; then
        grub_cmdline="cryptdevice=UUID=$uuid:cryptlvm root=/dev/vg0/root"
    elif [ "$ENCRYPTION" = "luks2" ]; then
        grub_cmdline="cryptdevice=UUID=$uuid:cryptroot root=/dev/mapper/cryptroot"
    fi
    
    [ -n "$grub_cmdline" ] && chroot_exec "/mnt" "sed -i 's|GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"$grub_cmdline\"|' /etc/default/grub"
    
    if [ "$INSTALL_MODE" = "dual" ]; then
        log "INFO" "Dual boot mode detected, enabling os-prober"
        chroot_exec "/mnt" "
            echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub
        "
    fi
    
    execute arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
}
