#!/usr/bin/env bash
# 🍎 KIRA INSTALLER — The Scythe (Disk Validation, Partitioning, Mounting)
# "Erasing target drives and carving out the partitions to support our new world."

# ======================================================================
# DISK CHECKER (Ensure the target is real and not currently active)
# ======================================================================
disk_validate() {
    local disk="$1"

    if [[ ! -b "$disk" ]]; then
        log "ERROR" "Disk device doesn't exist: $disk. Is that a fake identity?"
        whiptail --msgbox "Error: Disk $disk does not exist! Did you write the name down incorrectly, Lord Kira?" 8 60
        return 1
    fi

    if mount | grep -q "$disk"; then
        log "ERROR" "Disk is currently in use: $disk. Free it from its duties before we claim it."
        whiptail --msgbox "Error: Disk $disk is active and mounted! Free it from its bindings before writing its name in the notebook." 8 60
        return 1
    fi

    log "INFO" "Target disk validated: $disk. Its fate is sealed. A clean slate for our new world."
    export DISK="$disk"
    return 0
}

# ======================================================================
# DISK PARTITIONER (Writing partition segments)
# ======================================================================
disk_partition() {
    log "INFO" "Drawing a line through all signatures... purging all memory on $DISK."
    retry wipefs -af "$DISK"

    local boot_mode="bios"
    if [ -d /sys/firmware/efi ]; then
        boot_mode="uefi"
    fi
    log "INFO" "Shinigami Eyes identified boot mode: $boot_mode"

    if [ "$boot_mode" = "uefi" ]; then
        log "INFO" "Signing a clean GPT covenant onto $DISK..."
        retry parted -s "$DISK" mklabel gpt
        log "INFO" "Carving out the 512MiB EFI Temple..."
        retry parted -s "$DISK" mkpart ESP fat32 1MiB 513MiB
        retry parted -s "$DISK" set 1 esp on
        log "INFO" "Reserving the remaining domain of the drive for the Root empire..."
        retry parted -s "$DISK" mkpart primary ext4 513MiB 100%
    else
        log "INFO" "Carving an MBR (msdos) seal onto legacy drive $DISK..."
        retry parted -s "$DISK" mklabel msdos
        log "INFO" "Erecting a 512MiB Boot gateway..."
        retry parted -s "$DISK" mkpart primary fat32 1MiB 513MiB
        retry parted -s "$DISK" set 1 boot on
        log "INFO" "Reserving the remaining domain of the drive for the Root empire..."
        retry parted -s "$DISK" mkpart primary ext4 513MiB 100%
    fi

    log "INFO" "Whispering the partition changes to the kernel..."
    sleep 2
    partprobe "$DISK"
    udevadm settle

    detect_partitions
}

# ======================================================================
# PARTITION SCANNER (Looking up the newly created paths)
# ======================================================================
detect_partitions() {
    BOOT_PART=""
    ROOT_PART=""

    # Handle nvme partition naming conventions (e.g. nvme0n1p1 vs sda1)
    if [[ "$DISK" == *"nvme"* ]] || [[ "$DISK" == *"mmcblk"* ]]; then
        BOOT_PART="${DISK}p1"
        ROOT_PART="${DISK}p2"
    else
        BOOT_PART="${DISK}1"
        ROOT_PART="${DISK}2"
    fi

    if [ "${DRY_RUN:-false}" = "true" ]; then
        log "INFO" "[DRY RUN] Mocking partition paths: Boot=$BOOT_PART, Root=$ROOT_PART"
        export BOOT_PART ROOT_PART
        return 0
    fi

    [[ -b "$BOOT_PART" ]] || error "Misa couldn't find the boot partition path: $BOOT_PART! Where did it go?"
    [[ -b "$ROOT_PART" ]] || error "Misa couldn't find the root partition path: $ROOT_PART!"

    export BOOT_PART ROOT_PART
    log "INFO" "Discovered boot path: $BOOT_PART"
    log "INFO" "Discovered root path: $ROOT_PART"
}

# ======================================================================
# FILE SYSTEM FORMATTER (Wiping the slate clean)
# ======================================================================
disk_format() {
    [ -z "${BOOT_PART:-}" ] && error "The boot partition has gone missing! Did you run partitioning first, Lord Kira?"
    [ -z "${ROOT_PART:-}" ] && error "The root partition is gone! Run partitioning first."

    log "INFO" "Washing boot partition $BOOT_PART in clean FAT32 water..."
    retry mkfs.fat -F32 "$BOOT_PART"

    log "INFO" "Establishing root partition $ROOT_PART as EXT4 ground..."
    retry mkfs.ext4 -F "$ROOT_PART"
}

# ======================================================================
# DRIVE MOUNTER (Preparing target directory structures)
# ======================================================================
disk_mount() {
    [ -z "${ROOT_PART:-}" ] && error "Root partition is missing! Run partitioning first."
    [ -z "${BOOT_PART:-}" ] && error "Boot partition is missing! Run partitioning first."

    local root_to_mount="${ROOT_MAPPER:-$ROOT_PART}"
    log "INFO" "Binding root workspace: $root_to_mount -> /mnt"
    retry mount "$root_to_mount" /mnt

    log "INFO" "Creating gate: /mnt/boot..."
    execute mkdir -p /mnt/boot

    log "INFO" "Binding boot gateway: $BOOT_PART -> /mnt/boot"
    retry mount "$BOOT_PART" /mnt/boot

    if [ -n "${HOME_MAPPER:-}" ]; then
        log "INFO" "Creating home quarters: /mnt/home..."
        execute mkdir -p /mnt/home
        log "INFO" "Binding home quarters: $HOME_MAPPER -> /mnt/home"
        retry mount "$HOME_MAPPER" /mnt/home
    fi

    log "INFO" "Mounting complete! The directory bones are in place, Lord Kira."
}
# partition refresh
# swap skip
# lvm fix
# partition refresh
