#!/usr/bin/env bash
# 🍎 KIRA INSTALLER — The Scythe (Disk Validation, Partitioning, Mounting)
# "Erasing target drives and carving out the partitions to support our new world."

# ======================================================================
# DISK CHECKER (Ensure the target is real and not currently active)
# ======================================================================
disk_validate() {
    local disk="$1"

    if [[ ! -b "$disk" ]]; then
        log "ERROR" "Disk device doesn't exist: $disk. Did you write it down wrong, Master? 🥺"
        whiptail --msgbox "Error: Disk $disk does not exist! Please check the spelling, Master!" 8 60
        return 1
    fi

    if mount | grep -q "$disk"; then
        log "ERROR" "Disk is currently in use: $disk. Please unmount it so I can format it, Master!"
        whiptail --msgbox "Error: Disk $disk is active and mounted! Please unmount it first, Master!" 8 60
        return 1
    fi

    log "INFO" "Target disk validated: $disk. Ready to write our files here, Master! 🌸"
    export DISK="$disk"
    return 0
}

# ======================================================================
# DISK PARTITIONER (Writing partition segments)
# ======================================================================
disk_partition() {
    log "INFO" "Wiping all existing signatures on $DISK... clearing the slate! 🧹"
    retry wipefs -af "$DISK"

    local boot_mode="bios"
    if [ -d /sys/firmware/efi ]; then
        boot_mode="uefi"
    fi
    log "INFO" "Detected boot environment: $boot_mode"

    if [ "$boot_mode" = "uefi" ]; then
        log "INFO" "Writing a clean GPT label onto $DISK..."
        retry parted -s "$DISK" mklabel gpt
        log "INFO" "Creating 512MiB EFI Boot partition..."
        retry parted -s "$DISK" mkpart ESP fat32 1MiB 513MiB
        retry parted -s "$DISK" set 1 esp on
        log "INFO" "Allocating remaining disk space for the Root partition..."
        retry parted -s "$DISK" mkpart primary ext4 513MiB 100%
    else
        log "INFO" "Writing an MBR (msdos) label onto legacy drive $DISK..."
        retry parted -s "$DISK" mklabel msdos
        log "INFO" "Creating 512MiB active Boot partition..."
        retry parted -s "$DISK" mkpart primary fat32 1MiB 513MiB
        retry parted -s "$DISK" set 1 boot on
        log "INFO" "Allocating remaining disk space for the Root partition..."
        retry parted -s "$DISK" mkpart primary ext4 513MiB 100%
    fi

    log "INFO" "Informing the kernel of partition updates..."
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

    [[ -b "$BOOT_PART" ]] || error "Oops! I couldn't locate the boot partition: $BOOT_PART! 🥺"
    [[ -b "$ROOT_PART" ]] || error "Oops! I couldn't locate the root partition: $ROOT_PART! 🥺"

    export BOOT_PART ROOT_PART
    log "INFO" "Found boot path: $BOOT_PART"
    log "INFO" "Found root path: $ROOT_PART"
}

# ======================================================================
# FILE SYSTEM FORMATTER (Wiping the slate clean)
# ======================================================================
disk_format() {
    [ -z "${BOOT_PART:-}" ] && error "The boot partition is missing! Did you run partitioning first, Master?"
    [ -z "${ROOT_PART:-}" ] && error "The root partition is gone! Run partitioning first, Master."

    log "INFO" "Formatting boot partition $BOOT_PART as FAT32..."
    retry mkfs.fat -F32 "$BOOT_PART"

    log "INFO" "Formatting root partition $ROOT_PART as EXT4..."
    retry mkfs.ext4 -F "$ROOT_PART"
}

# ======================================================================
# DRIVE MOUNTER (Preparing target directory structures)
# ======================================================================
disk_mount() {
    [ -z "${ROOT_PART:-}" ] && error "Root partition is missing! Run partitioning first."
    [ -z "${BOOT_PART:-}" ] && error "Boot partition is missing! Run partitioning first."

    local root_to_mount="${ROOT_MAPPER:-$ROOT_PART}"
    log "INFO" "Mounting root workspace: $root_to_mount -> /mnt"
    retry mount "$root_to_mount" /mnt

    log "INFO" "Creating mount directory: /mnt/boot..."
    execute mkdir -p /mnt/boot

    log "INFO" "Mounting boot volume: $BOOT_PART -> /mnt/boot"
    retry mount "$BOOT_PART" /mnt/boot

    if [ -n "${HOME_MAPPER:-}" ]; then
        log "INFO" "Creating mount directory: /mnt/home..."
        execute mkdir -p /mnt/home
        log "INFO" "Mounting home volume: $HOME_MAPPER -> /mnt/home"
        retry mount "$HOME_MAPPER" /mnt/home
    fi

    log "INFO" "Mounting complete! Our directory folders are all set up, Master! 🌸"
}
# partition refresh
# swap skip
# lvm fix
# partition refresh
# swap skip
# lvm fix
