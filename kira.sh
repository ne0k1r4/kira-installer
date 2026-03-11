#!/usr/bin/env bash
# 🍎 KIRA INSTALLER — The Mastermind (Main Entry Point)
# Version: 15.0.0-KIRA-FINAL
# "I'll take a potato chip... and INSTALL ARCH LINUX!" - Light Yagami

# ======================================================================
# STRICT MODE WITH SUBSHELL TRACING
# ======================================================================
set -euo pipefail
set -o errtrace
IFS=$'\n\t'

# ======================================================================
# COMMAND VALIDATION (with fallbacks)
# ======================================================================
REQUIRED_COMMANDS=(
    "parted" "cryptsetup" "reflector" "pacstrap" "arch-chroot"
    "genfstab" "mkfs.fat" "mkfs.ext4" "blkid" "lsblk" "curl"
    "swapoff" "vgchange" "partprobe" "lspci"
)

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: Required command not found: $cmd"
        echo "Please install: $cmd"
        exit 1
    fi
done

# ======================================================================
# SOURCE MODULES
# ======================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for module in common ui disk encryption system bootloader; do
    if [ ! -f "$SCRIPT_DIR/lib/${module}.sh" ]; then
        echo "ERROR: Module not found: lib/${module}.sh"
        exit 1
    fi
    source "$SCRIPT_DIR/lib/${module}.sh"
done

# ======================================================================
# CONFIGURATION
# ======================================================================
VERSION="15.0.0-KIRA-FINAL"
LOG_FILE="/var/log/kira-installer-$(date +%Y%m%d-%H%M%S).log"
CONFIG_DIR="/etc/kira-installer"
STATE_DIR="/tmp/kira-state"
PRESEED_FILE="/etc/kira-installer/preseed.conf"
DRY_RUN=${DRY_RUN:-false}

mkdir -p "$CONFIG_DIR" "$STATE_DIR"

# ======================================================================
# INITIALIZATION
# ======================================================================
exec > >(tee -a "$LOG_FILE") 2>&1

cleanup_on_exit() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log "ERROR" "Installation failed with code $exit_code! Cleaning up..."
        umount -R /mnt 2>/dev/null || true
    else
        log "INFO" "Installation completed successfully"
    fi
}
trap cleanup_on_exit EXIT

export VERSION LOG_FILE STATE_DIR DRY_RUN

# ======================================================================
# PRESEED LOADING
# ======================================================================
load_preseed() {
    if [ -f "$PRESEED_FILE" ]; then
        log "INFO" "Loading preseed from $PRESEED_FILE"
        source "$PRESEED_FILE"
        
        INSTALL_MODE="${INSTALL_MODE:-single}"
        ENCRYPTION="${ENCRYPTION:-none}"
        HOSTNAME="${HOSTNAME:-kira-arch}"
        
        export INSTALL_MODE ENCRYPTION HOSTNAME USERNAME
        [ -n "${SELECTED_DISK:-}" ] && export SELECTED_DISK
        [ -n "${CRYPT_PASS:-}" ] && export CRYPT_PASS
        [ -n "${USERPASS:-}" ] && export USERPASS
        [ -n "${MIRROR_COUNTRY:-}" ] && export MIRROR_COUNTRY
        [ -n "${SWAP_SIZE:-}" ] && export SWAP_SIZE
        [ -n "${ROOT_SIZE:-}" ] && export ROOT_SIZE
        
        log "INFO" "Preseed loaded: Mode=$INSTALL_MODE, Disk=${SELECTED_DISK:-auto}, Encryption=$ENCRYPTION"
        return 0
    fi
    return 1
}

# ======================================================================
# VALIDATION FUNCTIONS
# ======================================================================
validate_encryption_value() {
    case "$1" in none|luks2|luks2+lvm) return 0 ;; *)
        log "ERROR" "Invalid ENCRYPTION: $1 (must be none, luks2, or luks2+lvm)"
        return 1 ;;
    esac
}

validate_required_vars() {
    local missing=0
    [ -z "${USERNAME:-}" ] && log "ERROR" "USERNAME required" && missing=1
    [ -z "${HOSTNAME:-}" ] && log "ERROR" "HOSTNAME required" && missing=1
    [ -z "${INSTALL_MODE:-}" ] && log "ERROR" "INSTALL_MODE required" && missing=1
    
    ENCRYPTION="${ENCRYPTION:-none}"
    validate_encryption_value "$ENCRYPTION" || missing=1
    
    if [ "$ENCRYPTION" != "none" ] && [ -z "${CRYPT_PASS:-}" ] && [ "${AUTO:-false}" = "true" ]; then
        log "ERROR" "Encryption enabled but CRYPT_PASS not set in preseed (AUTO mode)"
        missing=1
    fi
    
    if [ -z "${USERPASS:-}" ] && [ "${AUTO:-false}" = "true" ]; then
        log "ERROR" "USERPASS not set in preseed (AUTO mode)"
        missing=1
    fi
    return $missing
}

# ======================================================================
# NETWORK TEST
# ======================================================================
test_network() {
    while true; do
        log "INFO" "Testing network connectivity..."

        if command -v ping &>/dev/null; then
            if ping -c 1 archlinux.org &>/dev/null; then
                log "INFO" "Network connectivity confirmed"
                return 0
            fi
        fi

        if curl -s --max-time 5 https://archlinux.org >/dev/null; then
            log "INFO" "Network connectivity confirmed via curl"
            return 0
        fi

        log "WARNING" "No internet connection detected"

        if whiptail --yesno "Network connection not detected.\n\nRetry connection?" 10 60; then
            log "INFO" "Retrying network test..."
        else
            log "ERROR" "Installation requires internet connection."
            return 1
        fi
    done
}

# ======================================================================
# MAIN INSTALLATION FLOW
# ======================================================================
main() {
    load_preseed || true
    
    if [ "${NO_BANNER:-false}" != "true" ]; then
        ui_show_banner || exit 1
    fi
    
    test_network || exit 1
    
    if [ -z "${INSTALL_MODE:-}" ]; then
        INSTALL_MODE="single"
        export INSTALL_MODE
    fi
    log "INFO" "Installation mode: $INSTALL_MODE"
    
    ui_optimize_mirrors || log "WARNING" "Mirror optimization failed, using defaults"
    
    bootloader_detect_microcode
    system_detect_gpu
    
    # Preseed override — ensure ENCRYPTION has a safe default
    ENCRYPTION="${ENCRYPTION:-none}"
    if [ "$ENCRYPTION" != "none" ] && [ -z "${CRYPT_PASS:-}" ]; then
        log "INFO" "Using preseed encryption: $ENCRYPTION"
        get_password_confirm "Encryption passphrase" CRYPT_PASS
        export CRYPT_PASS
    fi
    export ENCRYPTION

    if [ "${AUTO:-false}" = "true" ] && [ -n "${SELECTED_DISK:-}" ]; then
        log "INFO" "AUTO mode enabled, skipping menu."
    else
        while true; do
            clear
            echo "╔══════════════════════════════╗"
            echo "║      KIRA INSTALLER          ║"
            echo "╠══════════════════════════════╣"
            echo "║ 1. Install Arch Linux        ║"
            echo "║ 2. Disk Setup                ║"
            echo "║ 3. Encryption (LUKS)         ║"
            echo "║ 4. Exit                      ║"
            echo "╚══════════════════════════════╝"
            echo ""
            read -r -p "Select option: " choice
            
            case "$choice" in
                1)
                    if [ -z "${SELECTED_DISK:-}" ]; then
                        echo "ERROR: Please complete Disk Setup prior to installation."
                        sleep 2
                        continue
                    fi
                    break
                    ;;
                2)
                    local valid_disks
                    valid_disks=$(lsblk -d -n -o NAME | grep -v -E "loop|sr|rom" | tr '\n' ' ')
                    local target
                    target=$(ui_input "Available disks: $valid_disks\nEnter target disk (/dev/sdX):" "")
                    if [ -n "$target" ]; then
                        if disk_validate "$target"; then
                            if [ "${NO_CONFIRM:-false}" != "true" ]; then
                                if ui_yesno "WARNING: This will DESTROY ALL DATA on $target. Continue?"; then
                                    SELECTED_DISK="$target"
                                    export SELECTED_DISK
                                fi
                            else
                                SELECTED_DISK="$target"
                                export SELECTED_DISK
                            fi
                        else
                            sleep 2
                        fi
                    fi
                    ;;
                3)
                    encryption_setup
                    ;;
                4)
                    echo "Exiting..."
                    exit 0
                    ;;
                *)
                    echo "Invalid option."
                    sleep 1
                    ;;
            esac
        done
    fi
    
    [ -z "${HOSTNAME:-}" ] && HOSTNAME=$(ui_input "Hostname" "kira-arch") && export HOSTNAME
    [ -z "${USERNAME:-}" ] && USERNAME=$(ui_input "Username" "") && export USERNAME
    
    if [ -z "${USERPASS:-}" ]; then
        get_password_confirm "User password" USERPASS
        export USERPASS
    fi
    
    validate_required_vars || exit 1
    
    if [ "${AUTO:-false}" != "true" ]; then
        ui_confirm_installation || { clear_passwords; exit 0; }
    fi
    
    if [ "$DRY_RUN" = "true" ]; then
        ui_dry_run_message
        clear_passwords
        exit 0
    fi
    
    (
        ui_progress 10 "Creating partitions..."
        disk_partition
        
        ui_progress 20 "Formatting partitions..."
        disk_format
        
        ui_progress 30 "Mounting partitions..."
        disk_mount
        
        ui_progress 40 "Installing base system..."
        system_install_base
        
        ui_progress 50 "Generating fstab..."
        execute genfstab -U /mnt >> /mnt/etc/fstab
        
        ui_progress 60 "Configuring system..."
        system_configure
        
        ui_progress 70 "Installing bootloader..."
        bootloader_install
        
        ui_progress 90 "Finalizing installation..."
        clear_passwords
        ui_progress 100 "Installation complete!"
    ) 2>&1 | tee -a "$LOG_FILE" | ui_progress_pipe "Installation Progress"
    
    ui_finish
}

# ======================================================================
# START
# ======================================================================
if [ "$EUID" -ne 0 ]; then
    echo "Even Kira needs root privileges. Run with sudo."
    exit 1
fi

while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run) DRY_RUN=true ;;
        --preseed) PRESEED_FILE="$2"; shift ;;
        --help) ui_show_help; exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

main
