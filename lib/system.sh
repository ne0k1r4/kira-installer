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
        log "INFO" "Shinigami Eyes spotted an NVIDIA GPU! Preparing proprietary drivers..."
    fi
    if echo "$devices" | grep -q "amd"; then
        GPU_DRIVERS+=("xf86-video-amdgpu" "vulkan-radeon")
        log "INFO" "Shinigami Eyes spotted an AMD GPU! Preparing Radeon packages..."
    fi
    if echo "$devices" | grep -q "intel"; then
        GPU_DRIVERS+=("xf86-video-intel" "vulkan-intel")
        log "INFO" "Shinigami Eyes spotted an Intel GPU! Preparing internal graphics modules..."
    fi
    
    if [ ${#GPU_DRIVERS[@]} -eq 0 ]; then
        GPU_DRIVERS=("mesa")
        log "INFO" "No specific GPU signature detected. Defaulting to standard Mesa drivers."
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
        log "INFO" "Enabling GRUB boot package for standard BIOS boot."
    fi
    
    if [ "${INSTALL_MODE:-single}" = "dual" ]; then
        packages+=("os-prober")
        log "INFO" "Os-prober included to search for other partition souls."
    fi
    
    packages+=("networkmanager" "hyprland" "kitty" "waybar" "wofi" "xdg-desktop-portal-hyprland" "sddm" "qt5-wayland" "qt6-wayland" "polkit-kde-agent")
    
    log "INFO" "Misa is pacstrapping base packages: ${packages[*]}. Grab a potato chip and eat it! 🥔"
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
        log "INFO" "[DRY RUN] Simulation mode: Skipping user registration, locale build, and mkinitcpio..."
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
    log "INFO" "Spotted host location: $timezone. Injecting it to the new realm."

    chroot_exec "/mnt" "
        ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
        hwclock --systohc
        echo 'en_US.UTF-8 UTF-8' > /etc/locale.gen
        locale-gen
        echo 'LANG=en_US.UTF-8' > /etc/locale.conf
        systemctl enable NetworkManager
        systemctl enable sddm
    "

    # Set passwords and create user outside heredoc to expand correctly
    echo "root:${USERPASS}" | arch-chroot /mnt chpasswd
    arch-chroot /mnt useradd -m -G wheel -s /bin/bash "${USERNAME}"
    echo "${USERNAME}:${USERPASS}" | arch-chroot /mnt chpasswd
    echo '%wheel ALL=(ALL:ALL) ALL' > /mnt/etc/sudoers.d/10-wheel
    chmod 440 /mnt/etc/sudoers.d/10-wheel

    # Create user home configs for Hyprland
    local user_home="/mnt/home/${USERNAME}"
    if [ -d "$user_home" ]; then
        mkdir -p "$user_home/.config/hypr"
        cat > "$user_home/.config/hypr/hyprland.conf" << 'EOF'
# Monitor configuration
monitor=,preferred,auto,1

# Execute at launch
exec-once = waybar
exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP

# Input configuration
input {
    kb_layout = us
    follow_mouse = 1
    touchpad {
        natural_scroll = false
    }
}

# Misa's hot-pink aesthetic borders! Pink borders represent our absolute bond.
general {
    gaps_in = 5
    gaps_out = 10
    border_size = 2
    col.active_border = rgba(ff69b4ee) rgba(ff1493ee) 45deg
    col.inactive_border = rgba(595959aa)
    layout = dwindle
}

decoration {
    rounding = 10
    blur {
        enabled = true
        size = 3
        passes = 1
    }
    drop_shadow = true
    shadow_range = 4
    shadow_render_power = 3
    col.shadow = rgba(1a1a1aee)
}

animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 7, myBezier
    animation = windowsOut, 1, 7, default, popin 80%
    animation = border, 1, 10, default
    animation = borderangle, 1, 8, default
    animation = fade, 1, 7, default
    animation = workspaces, 1, 6, default
}

dwindle {
    pseudotile = true
    preserve_split = true
}

misc {
    disable_hyprland_logo = true
    disable_splash_rendering = true
    background_color = 0x11111b
}

# Kira's master keybindings
$mainMod = SUPER

bind = $mainMod, Q, exec, kitty
bind = $mainMod, C, killactive,
bind = $mainMod, M, exit,
bind = $mainMod, R, exec, wofi --show drun
bind = $mainMod, V, togglefloating,
bind = $mainMod, P, pseudo,
bind = $mainMod, J, togglesplit,

# Focus
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

# Workspaces
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6
bind = $mainMod, 7, workspace, 7
bind = $mainMod, 8, workspace, 8
bind = $mainMod, 9, workspace, 9
bind = $mainMod, 0, workspace, 10

# Move active window to workspace
bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6
bind = $mainMod SHIFT, 7, movetoworkspace, 7
bind = $mainMod SHIFT, 8, movetoworkspace, 8
bind = $mainMod SHIFT, 9, movetoworkspace, 9
bind = $mainMod SHIFT, 0, movetoworkspace, 10
EOF

        # Create basic waybar config
        mkdir -p "$user_home/.config/waybar"
        cat > "$user_home/.config/waybar/config" << 'EOF'
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "modules-left": ["hyprland/workspaces", "hyprland/submap"],
    "modules-center": ["hyprland/window"],
    "modules-right": ["cpu", "memory", "clock", "tray"],
    "hyprland/workspaces": {
        "format": "{name}"
    },
    "clock": {
        "format": "{:%H:%M | %d-%m-%Y}"
    },
    "cpu": {
        "format": "CPU {usage}%"
    },
    "memory": {
        "format": "RAM {percentage}%"
    }
}
EOF

        # Create a beautiful custom stylesheet for Waybar (glassmorphism!)
        cat > "$user_home/.config/waybar/style.css" << 'EOF'
* {
    border: none;
    border-radius: 0;
    font-family: "JetBrains Mono", Roboto, Helvetica, Arial, sans-serif;
    font-size: 13px;
    min-height: 0;
}

window#waybar {
    background: rgba(17, 17, 27, 0.85);
    color: #cdd6f4;
    border-bottom: 2px solid rgba(255, 105, 180, 0.6); /* Misa Hot-Pink Border! */
}

#workspaces button {
    padding: 0 8px;
    background: transparent;
    color: #a6adc8;
}

#workspaces button.active {
    color: #ff69b4; /* Pink active text */
    font-weight: bold;
}

#workspaces button:hover {
    background: rgba(255, 105, 180, 0.15);
    color: #ff1493;
}

#clock, #cpu, #memory, #tray {
    padding: 0 12px;
    margin: 3px 2px;
    border-radius: 6px;
    background: rgba(255, 255, 255, 0.07);
}
EOF
        
        # Set ownership of the config files to the created user
        chroot_exec "/mnt" "chown -R ${USERNAME}:wheel /home/${USERNAME}/.config"
    fi

    # Enable ParallelDownloads, Color, and ILoveCandy in pacman.conf
    if [ -f /mnt/etc/pacman.conf ]; then
        sed -i 's/^#Color/Color/' /mnt/etc/pacman.conf
        if ! grep -q "ILoveCandy" /mnt/etc/pacman.conf; then
            sed -i '/^Color/a ILoveCandy' /mnt/etc/pacman.conf
        fi
        sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' /mnt/etc/pacman.conf
        log "INFO" "Sweetened target pacman.conf! Activated ParallelDownloads=5, Color, and ILoveCandy! 🍬"
    fi

    system_configure_mkinitcpio
}
# mirrorlist 2026
# mirrorlist 2026
# gpu detection
# zsh default
# hyprland
# microcode fix
# dotfiles
# neovim
