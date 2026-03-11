#!/usr/bin/env bash
# 🍎 KIRA INSTALLER — The Scythe (Disk Validation, Partitioning, Mounting)

# ======================================================================
# DISK VALIDATION
# ======================================================================

disk_validate() {

    DISK="$1"

    [[ -b "$DISK" ]] || error "Invalid disk device: $DISK"

    if mount | grep -q "$DISK"; then
        error "Disk already mounted: $DISK"
    fi

    log "INFO" "Disk validated: $DISK"
    export DISK
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

    log "INFO" "Mounting root: $ROOT_PART -> /mnt"

    retry mount "$ROOT_PART" /mnt

    mkdir -p /mnt/boot

    log "INFO" "Mounting boot: $BOOT_PART -> /mnt/boot"

    retry mount "$BOOT_PART" /mnt/boot

    log "INFO" "Mount successful"
}
