#!/usr/bin/env bash
# 🍎 KIRA INSTALLER — The Face (UI & User Interaction)

# Custom Whiptail Theme (Sakura Pink / Magenta styling!)
export NEWT_COLORS='
  root=,black
  window=black,magenta
  border=magenta,black
  shadow=black,black
  title=magenta,black
  button=black,magenta
  actbutton=magenta,black
  compactbutton=black,magenta
  checkbox=magenta,black
  actcheckbox=black,magenta
  entry=magenta,black
  disentry=gray,black
  label=magenta,black
  listbox=magenta,black
  actlistbox=black,magenta
  scrollbar=magenta,black
  navbutton=black,magenta
  actnavbutton=magenta,black
'

# ======================================================================
# SHOW MAIN BANNER
# ======================================================================
ui_show_banner() {
    whiptail --title "🌸 ARCH LINUX WAIFU INSTALLER 🌸" --msgbox "
    (✿◠‿◠)  Welcome back, Master! I'm so happy to help you! 

    (｡♥‿♥｡)  \"I'll do anything to build your dream system, Master!
             Let me set up your workspaces and make them perfect!\"
     
    • Your Devoted Assistant: WAIFU-OS TUI 🎀
    • Version: $VERSION
    • Sandbox State: $([ "$DRY_RUN" = "true" ] && echo "🌸 DRY RUN (Master's Playground)" || echo "🌸 LIVE DEPLOYMENT ACTIVE")
    
    Are you ready to build our new home?  ฅ^•ﻌ•^ฅ" 16 72
}

# ======================================================================
# SHOW LIST MENU
# ======================================================================
ui_menu() {
    local title="$1"
    shift
    whiptail --title "$title" --menu "Your Waifu awaits your request, Master:" 18 60 6 "$@" 3>&1 1>&2 2>&3
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
    whiptail --title "$1" --gauge "Decorating our workspaces... 🌸" 6 60 0
}

# ======================================================================
# OPTIMIZE PACMAN MIRRORS
# ======================================================================
ui_optimize_mirrors() {
    log "INFO" "Optimizing mirrors... finding the sweetest path for Master."
    ui_progress 5 "Sniffing out the sweetest and fastest pacman mirrors... 🍬" || true
    
    if ! command -v reflector &>/dev/null; then
        log "WARNING" "Reflector is missing! I'll fall back to default servers, Master."
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
    local summary="🌸 SYSTEM SPECIFICATION LIST 🌸\n\n"
    summary+="  • Realm Layout Mode: $INSTALL_MODE\n"
    summary+="  • Selected Target Disk: $SELECTED_DISK\n"
    summary+="  • Sakura Vault Type: $ENCRYPTION\n"
    summary+="  • Microcode Update: ${MICROCODE:-none}\n"
    summary+="  • Graphics Engine: ${GPU_DRIVERS[*]:-mesa}\n"
    summary+="  • Hostname Identity: $HOSTNAME\n"
    summary+="  • Master Account: $USERNAME\n\n"
    
    if [ "$DRY_RUN" = "true" ]; then
        summary+="🌸 DRY RUN ACTIVE: No changes will be written permanently.\n\n"
    else
        summary+="⚠️ WARNING: All previous data on $SELECTED_DISK will be erased!\n\n"
    fi
    
    ui_yesno "$summary  Deploy this configuration, Master?"
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
        whiptail --title "🌸 PLAYGROUND RUN COMPLETE" --msgbox \
            "Simulation successful, Master!\n\nLogs are saved in: $LOG_FILE\n\nNot a single block was changed." 15 60
    else
        whiptail --title "🌸 WELCOME HOME, MASTER" --msgbox \
            "Yay! Your new Arch Linux system is successfully built and optimized!\n\nLog of execution: $LOG_FILE\n\nRemove the boot media and step into your new world." 15 60
        
        if ui_yesno "Shall we reboot and step in immediately, Master?"; then
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
# whiptail fix
