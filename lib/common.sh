#!/usr/bin/env bash
# 🍎 KIRA INSTALLER — Common Utilities (Logging, Execution, Passwords)

# ======================================================================
# LOGGING
# ======================================================================
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    message=$(echo "$message" | sed -E 's/(passphrase|password|CRYPT_PASS)=[^ ]*/\1=***REDACTED***/g')
    echo "[$timestamp] [$level] $message" >> "${LOG_FILE:-/tmp/kira-installer.log}"
    
    if [ "${TERM:-}" != "dumb" ]; then
        case "$level" in
            ERROR)   echo -e "\033[0;31m[$level]\033[0m $message" ;;
            WARNING) echo -e "\033[1;33m[$level]\033[0m $message" ;;
            INFO)    echo -e "\033[0;32m[$level]\033[0m $message" ;;
            *)       echo "[$level] $message" ;;
        esac
    fi
}

error() {
    log "ERROR" "$*"
    exit 1
}

# ======================================================================
# RETRY HELPER
# ======================================================================
retry() {
    local attempts=5
    local count=0

    until "$@"; do
        ((count++))
        if ((count >= attempts)); then
            error "Command failed after $attempts attempts: $*"
        fi
        log "WARNING" "Retrying (attempt $count/$attempts): $*"
        sleep 2
    done
}

# ======================================================================
# SAFE EXECUTION
# ======================================================================
execute() {
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would execute: $*" >> "$LOG_FILE"
        return 0
    else
        "$@"
    fi
}

chroot_exec() {
    local chroot_path="$1"
    shift
    local script="$1"
    shift
    
    if [ "$DRY_RUN" = "true" ]; then
        echo "[DRY RUN] Would execute in chroot: $script" >> "$LOG_FILE"
        return 0
    fi
    
    arch-chroot "$chroot_path" /bin/bash <<EOF
$script
EOF
}

# ======================================================================
# PASSWORD HANDLING - NO EVAL, CONSISTENT API
# ======================================================================
set_var() {
    local var_name="$1"
    local value="$2"
    printf -v "$var_name" '%s' "$value"
}

get_password() {
    local prompt="$1"
    local var_name="$2"
    local password=""
    
    password=$(whiptail --passwordbox "$prompt" 8 60 3>&1 1>&2 2>&3)
    set_var "$var_name" "$password"
    unset password
}

get_password_confirm() {
    local prompt="$1"
    local var_name="$2"
    local pass1="" pass2=""
    
    while true; do
        get_password "$prompt" pass1
        get_password "Confirm $prompt" pass2
        
        if [ "$pass1" = "$pass2" ] && [ -n "$pass1" ]; then
            set_var "$var_name" "$pass1"
            break
        else
            whiptail --msgbox "Passwords do not match or are empty!" 8 60
        fi
    done
    unset pass1 pass2
}

clear_passwords() {
    unset CRYPT_PASS USERPASS
    log "INFO" "Passwords cleared from memory"
}
