#!/usr/bin/env bash
# 🍎 KIRA INSTALLER — The Pulse (System Configuration, Packages, Users)

# ======================================================================
# DETECT GPU & MICROCODE
# ======================================================================
system_detect_gpu() {
    GPU_DRIVERS=()
    local devices
    devices=$(lspci 2>/dev/null | grep -E "VGA|3D" | tr '[:upper:]' '[:lower:]' || true)
    
    if echo "$devices" | grep -q "nvidia"; then
        GPU_DRIVERS+=("nvidia" "nvidia-utils")
        log "INFO" "Detected NVIDIA GPU drivers"
    fi
    if echo "$devices" | grep -q "amd"; then
        GPU_DRIVERS+=("xf86-video-amdgpu" "vulkan-radeon")
        log "INFO" "Detected AMD GPU drivers"
    fi
    if echo "$devices" | grep -q "intel"; then
        GPU_DRIVERS+=("xf86-video-intel" "vulkan-intel")
        log "INFO" "Detected Intel GPU drivers"
    fi
    
    if [ ${#GPU_DRIVERS[@]} -eq 0 ]; then
        GPU_DRIVERS=("mesa")
        log "INFO" "No specific GPU vendor detected, using mesa"
    fi
    export GPU_DRIVERS
}

# ======================================================================
# INSTALL BASE PACKAGES (Pacstrap)
# ======================================================================
system_install_base() {
    local packages=("base" "base-devel" "linux" "linux-firmware")
    
    if [ -n "${MICROCODE:-}" ]; then
        packages+=("${MICROCODE}")
    fi
    
    packages+=("${GPU_DRIVERS[@]:-mesa}")
    
    if [ "${ENCRYPTION:-none}" = "luks2+lvm" ]; then
        packages+=("lvm2")
    fi
    
    if [ ! -d /sys/firmware/efi ]; then
        packages+=("grub")
        log "INFO" "Adding GRUB package for BIOS boot"
    fi
    
    if [ "${INSTALL_MODE:-single}" = "dual" ]; then
        packages+=("os-prober")
        log "INFO" "Adding os-prober for dual boot detection"
    fi
    
    packages+=("networkmanager")
    
    log "INFO" "Installing packages: ${packages[*]}"
    execute pacstrap /mnt "${packages[@]}"
}

# ======================================================================
# CONFIGURE MKINITCPIO (Initramfs)
# ======================================================================
system_configure_mkinitcpio() {
    local hooks="base udev autodetect modconf keyboard keymap consolefont block"

    if [ "${ENCRYPTION:-none}" != "none" ]; then
        hooks="$hooks encrypt"
    fi

    if [ "${ENCRYPTION:-none}" = "luks2+lvm" ]; then
        hooks="$hooks lvm2"
    fi

    hooks="$hooks filesystems fsck"

    # Write mkinitcpio.conf directly to avoid heredoc quoting issues
    sed -i "s|^HOOKS=.*|HOOKS=($hooks)|" /mnt/etc/mkinitcpio.conf
    arch-chroot /mnt mkinitcpio -P
}

# ======================================================================
# CONFIGURE SYSTEM IDENTITIES & PASSWORDS
# ======================================================================
system_configure() {
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log "INFO" "[DRY RUN] Would configure system identities, users, passwords, and mkinitcpio"
        return 0
    fi

    # Write hostname and hosts
    echo "$HOSTNAME" > /mnt/etc/hostname
    cat > /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

    # Dynamically detect timezone from host
    local timezone="UTC"
    if [ -L /etc/localtime ]; then
        timezone=$(readlink /etc/localtime | sed 's|.*/zoneinfo/||' || echo "UTC")
    elif [ -f /etc/timezone ]; then
        timezone=$(cat /etc/timezone || echo "UTC")
    fi
    log "INFO" "Auto-detected host timezone: $timezone"

    chroot_exec "/mnt" "
        ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
        hwclock --systohc
        echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
        locale-gen
        echo 'LANG=en_US.UTF-8' > /etc/locale.conf
        systemctl enable NetworkManager
    "

    # Set passwords and create user outside heredoc to expand correctly
    echo "root:${USERPASS}" | arch-chroot /mnt chpasswd
    arch-chroot /mnt useradd -m -G wheel -s /bin/bash "${USERNAME}"
    echo "${USERNAME}:${USERPASS}" | arch-chroot /mnt chpasswd
    echo '%wheel ALL=(ALL:ALL) ALL' > /mnt/etc/sudoers.d/10-wheel
    chmod 440 /mnt/etc/sudoers.d/10-wheel

    # Enable ParallelDownloads, Color, and ILoveCandy in pacman.conf
    if [ -f /mnt/etc/pacman.conf ]; then
        sed -i 's/^#Color/Color/' /mnt/etc/pacman.conf
        if ! grep -q "ILoveCandy" /mnt/etc/pacman.conf; then
            sed -i '/^Color/a ILoveCandy' /mnt/etc/pacman.conf
        fi
        sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' /mnt/etc/pacman.conf
        log "INFO" "Optimized pacman.conf (Color, ParallelDownloads = 5, ILoveCandy)"
    fi

    system_configure_mkinitcpio
}
