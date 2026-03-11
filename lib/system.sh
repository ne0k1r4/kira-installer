#!/usr/bin/env bash
# 🍎 KIRA INSTALLER — The Pulse (System Configuration, Packages, Users)

# ======================================================================
# DETECT GPU & MICROCODE
# ======================================================================
system_detect_gpu() {
    local vendor
    vendor=$(lspci 2>/dev/null | grep -E "VGA|3D" | grep -i -o -E "nvidia|amd|intel" | head -1 | tr '[:upper:]' '[:lower:]' || true)
    case $vendor in
        nvidia) GPU_DRIVERS=("nvidia" "nvidia-utils") ;;
        amd)    GPU_DRIVERS=("xf86-video-amdgpu" "vulkan-radeon") ;;
        intel)  GPU_DRIVERS=("xf86-video-intel" "vulkan-intel") ;;
        *)      GPU_DRIVERS=("mesa") ;;
    esac
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
    # Write hostname and hosts
    echo "$HOSTNAME" > /mnt/etc/hostname
    cat > /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

    chroot_exec "/mnt" "
        ln -sf /usr/share/zoneinfo/UTC /etc/localtime
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

    system_configure_mkinitcpio
}
