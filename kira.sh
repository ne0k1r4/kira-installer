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
exec 3>&1

# ======================================================================
# INITIALIZATION
# ======================================================================
exec > >(tee -a "$LOG_FILE") 2>&1

cleanup_on_exit() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log "ERROR" "An interruption occurred (exit code $exit_code)! Unwinding structures and closing vaults..."
        if [ "${DRY_RUN:-false}" != "true" ]; then
            umount -R /mnt 2>/dev/null || true
            vgchange -an vg0 2>/dev/null || true
            cryptsetup close cryptroot 2>/dev/null || true
            cryptsetup close cryptlvm 2>/dev/null || true
        fi
    else
        log "INFO" "All operations successfully completed. Clean exit."
    fi
}
trap cleanup_on_exit EXIT

export VERSION LOG_FILE STATE_DIR DRY_RUN

# ======================================================================
# PRESEED LOADING
# ======================================================================
load_preseed() {
    if [ -f "$PRESEED_FILE" ]; then
        log "INFO" "Discovered preseed configuration page at $PRESEED_FILE"
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
        
        log "INFO" "Loaded settings: Mode=$INSTALL_MODE, Disk=${SELECTED_DISK:-auto}, Vault=$ENCRYPTION"
        return 0
    fi
    return 1
}

# ======================================================================
# VALIDATION FUNCTIONS
# ======================================================================
validate_encryption_value() {
    case "$1" in none|luks2|luks2+lvm) return 0 ;; *)
        log "ERROR" "Invalid ENCRYPTION mode: $1 (Misa only understands: none, luks2, or luks2+lvm)"
        return 1 ;;
    esac
}

validate_required_vars() {
    local missing=0
    [ -z "${USERNAME:-}" ] && log "ERROR" "Master Username is missing!" && missing=1
    [ -z "${HOSTNAME:-}" ] && log "ERROR" "Realm Hostname is missing!" && missing=1
    [ -z "${INSTALL_MODE:-}" ] && log "ERROR" "Installation Mode is missing!" && missing=1
    
    ENCRYPTION="${ENCRYPTION:-none}"
    validate_encryption_value "$ENCRYPTION" || missing=1
    
    if [ "$ENCRYPTION" != "none" ] && [ -z "${CRYPT_PASS:-}" ] && [ "${AUTO:-false}" = "true" ]; then
        log "ERROR" "Encryption enabled but CRYPT_PASS is missing in preseed (AUTO mode)"
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
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log "INFO" "[DRY RUN] Skipping network probe inside sandbox."
        return 0
    fi
    while true; do
        log "INFO" "Misa is probing the internet gateway..."

        if command -v ping &>/dev/null; then
            if ping -c 1 archlinux.org &>/dev/null; then
                log "INFO" "Network connection confirmed! Reaching archlinux.org."
                return 0
            fi
        fi

        if curl -s --max-time 5 https://archlinux.org >/dev/null; then
            log "INFO" "Network connection confirmed via curl."
            return 0
        fi

        log "WARNING" "Oh no! No internet connection detected."

        if whiptail --yesno "Lord Kira, I can't reach the network servers! Did Ryuk chew on the ethernet line?\n\nWould you like me to try probing again?" 10 60; then
            log "INFO" "Probing connection again..."
        else
            log "ERROR" "Cannot proceed without a network connection. Task aborted."
            return 1
        fi
    done
}

# ======================================================================
# MAIN INSTALLATION FLOW
# ======================================================================
main() {
    [ "${HOSTNAME:-}" = "archiso" ] && unset HOSTNAME
    load_preseed || true
    
    if [ "${NO_BANNER:-false}" != "true" ]; then
        ui_show_banner || exit 1
    fi
    
    test_network || exit 1
    
    if [ -z "${INSTALL_MODE:-}" ]; then
        INSTALL_MODE="single"
        export INSTALL_MODE
    fi
    log "INFO" "Realm deployment mode: $INSTALL_MODE"
    
    if [ -n "${SELECTED_DISK:-}" ]; then
        if ! disk_validate "$SELECTED_DISK"; then
            log "WARNING" "Preseeded target validation failed. Resetting target selection."
            unset SELECTED_DISK
        fi
    fi
    
    bootloader_detect_microcode
    system_detect_gpu
    
    # Preseed override — ensure ENCRYPTION has a safe default
    ENCRYPTION="${ENCRYPTION:-none}"
    if [ "$ENCRYPTION" != "none" ] && [ -z "${CRYPT_PASS:-}" ]; then
        log "INFO" "Using preseeded encryption profile: $ENCRYPTION"
        get_password_confirm "Enter Encryption Passphrase" CRYPT_PASS
        export CRYPT_PASS
    fi
    export ENCRYPTION

    if [ "${AUTO:-false}" = "true" ] && [ -n "${SELECTED_DISK:-}" ]; then
        log "INFO" "AUTO mode enabled. Bypassing interactive menus."
    else
        while true; do
            local choice
            choice=$(whiptail --title "📓 Misa's Devotion: Main Menu 📓" --menu "Select your next action, Lord Kira:" 15 60 4 \
                "1" "Build Kira's New World (Install Arch)" \
                "2" "Choose Target Disk (Select Device)" \
                "3" "Configure Shinigami Vault (Encryption)" \
                "4" "Abandon the Notebook (Exit)" 3>&1 1>&2 2>&3) || choice="4"
            
            case "$choice" in
                "1")
                    if [ -z "${SELECTED_DISK:-}" ]; then
                        whiptail --msgbox "Error: You must assign a Target Disk before building the world!" 8 60
                        continue
                    fi
                    break
                    ;;
                "2")
                    local valid_disks
                    valid_disks=$(lsblk -d -n -o NAME | grep -v -E "loop|sr|rom" | tr '\n' ' ')
                    local target
                    target=$(ui_input "Available disks: $valid_disks\nEnter target disk (e.g. /dev/sda):" "")
                    if [ -n "$target" ]; then
                        if disk_validate "$target"; then
                            if [ "${NO_CONFIRM:-false}" != "true" ]; then
                                if ui_yesno "⚠️ WARNING: This will WIPE ALL DATA on $target. Purge this disk?"; then
                                    SELECTED_DISK="$target"
                                    export SELECTED_DISK
                                fi
                            else
                                SELECTED_DISK="$target"
                                export SELECTED_DISK
                            fi
                        fi
                    fi
                    ;;
                "3")
                    encryption_setup
                    ;;
                "4"|*)
                    echo "Exiting..."
                    exit 0
                    ;;
            esac
        done
    fi
    
    [ -z "${HOSTNAME:-}" ] && HOSTNAME=$(ui_input "What name shall we give this new realm? (Hostname)" "kira-arch") && export HOSTNAME
    [ -z "${USERNAME:-}" ] && USERNAME=$(ui_input "Under what master identity shall you rule? (Username)" "") && export USERNAME
    
    if [ -z "${USERPASS:-}" ]; then
        get_password_confirm "Enter password for root/user" USERPASS
        export USERPASS
    fi
    
    validate_required_vars || exit 1
    
    if [ "${AUTO:-false}" != "true" ]; then
        ui_confirm_installation || { clear_passwords; exit 0; }
    fi
    
    export UI_ACTIVE=true
    (
        ui_progress 10 "Misa is carving partition spaces... 👁️"
        disk_partition >> "$LOG_FILE" 2>&1
        
        ui_progress 20 "Mirror sweep: locating sweet and fast mirrors... 🍬"
        ui_optimize_mirrors >> "$LOG_FILE" 2>&1
        
        ui_progress 30 "LUKS encryption: forging the vaults... 🔐"
        encryption_format >> "$LOG_FILE" 2>&1
        
        ui_progress 45 "Mounting workspaces: attaching layout directories..."
        disk_mount >> "$LOG_FILE" 2>&1
        
        ui_progress 55 "Installing packages... Grab a potato chip! 🥔 (this might take a few minutes)"
        system_install_base >> "$LOG_FILE" 2>&1
        
        ui_progress 75 "Constructing layout configurations (writing fstab indexes)..."
        if [ "${DRY_RUN:-false}" = "true" ]; then
            log "INFO" "[DRY RUN] Would execute: genfstab -U /mnt >> /mnt/etc/fstab"
        else
            execute genfstab -U /mnt >> /mnt/etc/fstab 2>> "$LOG_FILE"
        fi
        
        ui_progress 85 "Reforming environment details (locales, hostname, users)..."
        system_configure >> "$LOG_FILE" 2>&1
        
        ui_progress 95 "Installing bootloader: summoning systemd-boot/GRUB... 👑"
        bootloader_install >> "$LOG_FILE" 2>&1
        
        ui_progress 98 "Polishing directories and clearing temporary secrets..."
        clear_passwords >> "$LOG_FILE" 2>&1
        
        ui_progress 100 "Kira's world is constructed! Complete! 🎉"
    ) 3>&1 | ui_progress_pipe "Installation Progress"
    export UI_ACTIVE=false
    
    ui_finish
}

# ======================================================================
# START
# ======================================================================
if [ "$EUID" -ne 0 ]; then
    echo "Even Kira needs root privileges to build a new world. Run with sudo."
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
