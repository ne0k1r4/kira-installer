# 🍎 KIRA INSTALLER — The Ledger (Logging, Execution, Passwords)
# "Every name written in these logs represents an executed partition, system configuration, or file."

# ======================================================================
# LOGGING UTILITIES (Keep track of our system reforms)
# ======================================================================
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Hide sensitive passphrases from the notebook
    message=$(echo "$message" | sed -E 's/(passphrase|password|CRYPT_PASS)=[^ ]*/\1=***REDACTED***/g')
    
    local sym
    case "$level" in
        ERROR)   sym="[💔 GOMEN]" ;;
        WARNING) sym="[⚠️ BAKA]" ;;
        INFO)    sym="[🌸 WAIFU]" ;;
        *)       sym="[$level]" ;;
    esac

    echo "[$timestamp] $sym $message" >> "${LOG_FILE:-/tmp/kira-installer.log}"
    
    if [ "${TERM:-}" != "dumb" ] && [ "${UI_ACTIVE:-false}" != "true" ]; then
        case "$level" in
            ERROR)   echo -e "\033[0;31m$sym\033[0m $message" ;;
            WARNING) echo -e "\033[1;33m$sym\033[0m $message" ;;
            INFO)    echo -e "\033[0;35m$sym\033[0m $message" ;; # Sakura pink console output
            *)       echo "$sym $message" ;;
        esac
    fi
}

error() {
    log "ERROR" "Fatal: $*"
    exit 1
}

# ======================================================================
# RETRY MECHANISM (If at first you don't succeed, try again...)
# ======================================================================
retry() {
    if [ "${DRY_RUN:-false}" = "true" ]; then
        log "INFO" "[DRY RUN] Simulating success for: $*"
        return 0
    fi
    local attempts=5
    local count=0

    until "$@"; do
        ((count++))
        if ((count >= attempts)); then
            error "Gomen! I tried my best, but this command keeps failing after $attempts attempts: $*"
        fi
        log "WARNING" "Oops! That didn't work. Retrying, please wait (attempt $count/$attempts): $*"
        sleep 2
    done
}

# ======================================================================
# SHELL COMMAND RUNNER (The Scythe)
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
        echo "[DRY RUN] Would execute inside chroot: $script" >> "$LOG_FILE"
        return 0
    fi
    
    arch-chroot "$chroot_path" /bin/bash <<EOF
$script
EOF
}

# ======================================================================
# SECURE PASSWORD HANDLING (Locked desk drawer)
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
        get_password "Confirm $prompt (Write it again, Master!)" pass2
        
        if [ "$pass1" = "$pass2" ] && [ -n "$pass1" ]; then
            set_var "$var_name" "$pass1"
            break
        else
            whiptail --msgbox "Baka! The passwords don't match or are empty. Please write them carefully, Master!" 8 60
        fi
    done
    unset pass1 pass2
}

clear_passwords() {
    unset CRYPT_PASS USERPASS
    log "INFO" "Secrets successfully wiped from memory! No trace left."
}
