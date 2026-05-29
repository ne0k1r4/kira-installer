#!/usr/bin/env bash
# 🍎 KIRA INSTALLER — The Scythe (Disk Validation, Partitioning, Mounting)

# ======================================================================
# DISK VALIDATION
# ======================================================================

disk_validate() {
    local disk="$1"

    if [[ ! -b "$disk" ]]; then
        log "ERROR" "Invalid disk device: $disk"
        whiptail --msgbox "Error: Invalid disk device: $disk" 8 60
        return 1
    fi

    if mount | grep -q "$disk"; then
        log "ERROR" "Disk already mounted: $disk"
        whiptail --msgbox "Error: Disk is already mounted: $disk" 8 60
        return 1
    fi

    log "INFO" "Disk validated: $disk"
    export DISK="$disk"
    return 0
}

# ======================================================================
# PARTITION DISK
# ======================================================================

disk_partition() {

    log "INFO" "Wiping disk"

    retry wipefs -af "$DISK"

    retry parted -s "$DISK" mklabel gpt

    log "INFO" "Creating boot partition"

    retry parted -s "$DISK" mkpart ESP fat32 1MiB 513MiB
    retry parted -s "$DISK" set 1 esp on

    log "INFO" "Creating root partition"

    retry parted -s "$DISK" mkpart primary ext4 513MiB 100%

    sleep 2
    partprobe "$DISK"
    udevadm settle

    detect_partitions
}

# ======================================================================
# DETECT PARTITIONS SAFELY
# ======================================================================

detect_partitions() {

    BOOT_PART=""
    ROOT_PART=""

    if [[ "$DISK" == *"nvme"* ]] || [[ "$DISK" == *"mmcblk"* ]]; then
        BOOT_PART="${DISK}p1"
        ROOT_PART="${DISK}p2"
    else
        BOOT_PART="${DISK}1"
        ROOT_PART="${DISK}2"
    fi

    if [ "${DRY_RUN:-false}" = "true" ]; then
        log "INFO" "[DRY RUN] Simulating partitions: $BOOT_PART, $ROOT_PART"
        export BOOT_PART ROOT_PART
        return 0
    fi

    [[ -b "$BOOT_PART" ]] || error "Boot partition not found: $BOOT_PART"
    [[ -b "$ROOT_PART" ]] || error "Root partition not found: $ROOT_PART"

    export BOOT_PART ROOT_PART

    log "INFO" "Boot partition: $BOOT_PART"
    log "INFO" "Root partition: $ROOT_PART"
}

# ======================================================================
# FORMAT PARTITIONS
# ======================================================================

disk_format() {

    [ -z "${BOOT_PART:-}" ] && error "BOOT_PART not set — run disk_partition first"
    [ -z "${ROOT_PART:-}" ] && error "ROOT_PART not set — run disk_partition first"

    log "INFO" "Formatting boot partition: $BOOT_PART"

    retry mkfs.fat -F32 "$BOOT_PART"

    log "INFO" "Formatting root partition: $ROOT_PART"

    retry mkfs.ext4 -F "$ROOT_PART"
}

# ======================================================================
# MOUNT PARTITIONS
# ======================================================================

disk_mount() {

    [ -z "${ROOT_PART:-}" ] && error "ROOT_PART not set — run disk_partition first"
    [ -z "${BOOT_PART:-}" ] && error "BOOT_PART not set — run disk_partition first"

    local root_to_mount="${ROOT_MAPPER:-$ROOT_PART}"
    log "INFO" "Mounting root: $root_to_mount -> /mnt"

    retry mount "$root_to_mount" /mnt

    execute mkdir -p /mnt/boot

    log "INFO" "Mounting boot: $BOOT_PART -> /mnt/boot"

    retry mount "$BOOT_PART" /mnt/boot

    if [ -n "${HOME_MAPPER:-}" ]; then
        execute mkdir -p /mnt/home
        log "INFO" "Mounting home: $HOME_MAPPER -> /mnt/home"
        retry mount "$HOME_MAPPER" /mnt/home
    fi

    log "INFO" "Mount successful"
}
