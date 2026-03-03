#!/usr/bin/env bash
# 🍎 KIRA INSTALLER — The Face (UI & User Interaction)

# Custom Whiptail Theme (Gothic Dark/Crimson Red Death Note styling!)
export NEWT_COLORS='
  root=,black
  window=black,red
  border=red,black
  shadow=black,black
  title=red,black
  button=black,red
  actbutton=red,black
  compactbutton=black,red
  checkbox=red,black
  actcheckbox=black,red
  entry=red,black
  disentry=gray,black
  label=red,black
  listbox=red,black
  actlistbox=black,red
  scrollbar=red,black
  navbutton=black,red
  actnavbutton=red,black
'

# ======================================================================
# SHOW MAIN BANNER
# ======================================================================
ui_show_banner() {
    whiptail --title "📓 DEATH NOTE: ARCH LINUX EDEN 📓" --msgbox "
    🖤 Misa Amane welcomes you to your new world, Lord Kira! 🖤
    
    \"I'll do anything for you, Lord Kira... 
     I'll write their names and build your new empire!\"
     
    - Assistant: Misa Amane (Shinigami Eyes Active 👁️)
    - Version: $VERSION
    - Environment: $([ "$DRY_RUN" = "true" ] && echo "📚 DRY RUN (Misa's Sandbox)" || echo "💀 LIVE TARGET EXECUTING")
    
    Shall we proceed to clean the world of bloatware?" 20 72
}

# ======================================================================
# SHOW LIST MENU
# ======================================================================
ui_menu() {
    local title="$1"
    shift
    whiptail --title "$title" --menu "Misa awaits your command, Lord Kira:" 18 60 6 "$@" 3>&1 1>&2 2>&3
}

# ======================================================================
# PROMPT FOR INPUT
# ======================================================================
ui_input() {
    local prompt="$1"
    local default="$2"
    whiptail --inputbox "$prompt" 8 60 "$default" 3>&1 1>&2 2>&3
}

# ======================================================================
# PROMPT YES / NO
# ======================================================================
ui_yesno() {
    whiptail --yesno "$1" 12 60
}

# ======================================================================
# SHOW PROGRESS BAR
# ======================================================================
ui_progress() {
    local pct="$1"
    local msg="$2"
    log "INFO" "Progress $pct%: $msg"
    echo "$pct" >&3
    echo "XXX" >&3
    echo "$msg" >&3
    echo "XXX" >&3
}

# ======================================================================
# SHOW PROGRESS BAR (PIPE FLOW)
# ======================================================================
ui_progress_pipe() {
    whiptail --title "$1" --gauge "Preparing notebook pages..." 6 60 0
}

# ======================================================================
# OPTIMIZE PACMAN MIRRORS
# ======================================================================
ui_optimize_mirrors() {
    log "INFO" "Optimizing mirrors... finding the fastest route to our repository."
    ui_progress 5 "Sniffing out the sweetest/fastest pacman mirrors... 🍬" || true
    
    if ! command -v reflector &>/dev/null; then
        log "WARNING" "reflector is missing! Misa will stick to the default list."
        return 0
    fi

    if ! execute reflector \
        --latest 10 \
        --protocol https \
        --sort rate \
        --download-timeout 20 \
        --save /etc/pacman.d/mirrorlist; then
        log "WARNING" "Mirror sweep failed. Defaulting to pre-arranged lists."
    fi

    ui_progress 10 "Mirrors optimized! Downloads will be sweet and fast! ⚡" || true
}

# ======================================================================
# CONFIRM FINAL INSTALLATION SETTINGS
# ======================================================================
ui_confirm_installation() {
    local summary="📓 THE EXECUTION LIST 📓\n\n"
    summary+="  • System Realm Mode: $INSTALL_MODE\n"
    summary+="  • Target Sacrifice Disk: $SELECTED_DISK\n"
    summary+="  • Vault Lock Type: $ENCRYPTION\n"
    summary+="  • Microcode Core: ${MICROCODE:-none}\n"
    summary+="  • Graphics Engine: ${GPU_DRIVERS[*]:-mesa}\n"
    summary+="  • Hostname Identity: $HOSTNAME\n"
    summary+="  • Master User: $USERNAME\n\n"
    
    if [ "$DRY_RUN" = "true" ]; then
        summary+="🍎 DRY RUN ACTIVE: No names will be written permanently.\n\n"
    else
        summary+="⚠️ DEATH NOTE WARNING: Wiping the disk cannot be undone!\n\n"
    fi
    
    ui_yesno "$summary  Write these changes to the system?"
}

# ======================================================================
# SHOW DRY RUN NOTIFICATION
# ======================================================================
ui_dry_run_message() {
    whiptail --msgbox "DRY RUN - Commands would execute now.\nCheck the log: $LOG_FILE" 10 60
}

# ======================================================================
# SHOW COMPLETION DIALOG
# ======================================================================
ui_finish() {
    if [ "${DRY_RUN:-false}" = "true" ]; then
        whiptail --title "🕊️ SANDBOX RUN COMPLETE" --msgbox \
            "Simulation success, Lord Kira!\n\nAll logs stored in: $LOG_FILE\n\nNot a single block was harmed in this run." 15 60
    else
        whiptail --title "👑 NEW WORLD CONSTRUCTED" --msgbox \
            "Congratulations, Lord Kira! Your new system is fully constructed and optimized.\n\nLog of execution: $LOG_FILE\n\nRemove the boot media and step into your new world." 15 60
        
        if ui_yesno "Shall we reboot and assume control immediately?"; then
            reboot
        fi
    fi
}

# ======================================================================
# SHOW CLI HELP TEXT
# ======================================================================
ui_show_help() {
    cat << EOF
Kira Arch Installer v$VERSION

Usage: $0 [OPTIONS]

Options:
    --dry-run           Simulate installation
    --preseed FILE      Load preseed configuration
    --help              Show this help

Preseed variables:
    INSTALL_MODE        single|dual|usb
    SELECTED_DISK       /dev/sda
    ENCRYPTION          none|luks2|luks2+lvm
    HOSTNAME            system name
    USERNAME            username
    CRYPT_PASS          encryption password (AUTO mode)
    USERPASS            user password (AUTO mode)
    MIRROR_COUNTRY      US, DE, FR, etc.
    SWAP_SIZE           8G, 16G, etc.
    ROOT_SIZE           30G, 15G, etc.
    AUTO                true (skip all prompts)
    NO_BANNER           true (skip banner)
    NO_CONFIRM          true (skip disk confirmation)
EOF
}
# whiptail fix
