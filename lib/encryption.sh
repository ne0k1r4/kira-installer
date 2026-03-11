#!/usr/bin/env bash
# 🍎 KIRA INSTALLER — The Vault (LUKS2 Encryption & LVM Setup)

# ======================================================================
# ENCRYPTION SETUP
# ======================================================================
encryption_setup() {
    if [ -n "${ENCRYPTION:-}" ]; then
        log "INFO" "Encryption already set to $ENCRYPTION"
        return 0
    fi
    
    if ui_yesno "Enable LUKS2 encryption?"; then
        ENCRYPTION="luks2"
        
        if [ -z "${CRYPT_PASS:-}" ]; then
            get_password_confirm "Encryption passphrase" CRYPT_PASS
        fi
        
        if ui_yesno "Use LVM on top of LUKS?"; then
            ENCRYPTION="luks2+lvm"
        fi
        
        log "INFO" "Enabled $ENCRYPTION encryption"
    else
        ENCRYPTION="none"
        log "INFO" "No encryption selected"
    fi
    
    export ENCRYPTION
    [ -n "${CRYPT_PASS:-}" ] && export CRYPT_PASS
}

encryption_format() {
    if [ "$ENCRYPTION" = "none" ]; then
        ENCRYPTED_PART="$ROOT_PART"
        ROOT_MAPPER="$ROOT_PART"
        export ENCRYPTED_PART ROOT_MAPPER
        echo "$ENCRYPTED_PART" > "$STATE_DIR/encrypted-part"
        return 0
    fi
    
    if [ -z "${CRYPT_PASS:-}" ]; then
        log "ERROR" "Encryption password not set!"
        return 1
    fi
    
    case $ENCRYPTION in
        luks2)
            if [ -z "$ROOT_PART" ]; then
                log "ERROR" "ROOT_PART not set"
                return 1
            fi
            printf "%s" "$CRYPT_PASS" | execute cryptsetup luksFormat --type luks2 --pbkdf argon2id "$ROOT_PART" -
            printf "%s" "$CRYPT_PASS" | execute cryptsetup open "$ROOT_PART" cryptroot -
            ROOT_MAPPER="/dev/mapper/cryptroot"
            ENCRYPTED_PART="$ROOT_PART"
            ;;
            
        luks2+lvm)
            if [ -z "$LVM_PART" ]; then
                log "ERROR" "LVM_PART not set"
                return 1
            fi
            printf "%s" "$CRYPT_PASS" | execute cryptsetup luksFormat --type luks2 --pbkdf argon2id "$LVM_PART" -
            printf "%s" "$CRYPT_PASS" | execute cryptsetup open "$LVM_PART" cryptlvm -
            
            execute pvcreate /dev/mapper/cryptlvm
            execute vgcreate vg0 /dev/mapper/cryptlvm
            
            local swap_size="${SWAP_SIZE:-2G}"
            local root_size="${ROOT_SIZE:-30G}"
            
            local vg_size
            vg_size=$(vgdisplay vg0 2>/dev/null | grep "Total PE" | awk '{print $3}' 2>/dev/null || echo "0")
            if [ "$vg_size" -gt 0 ]; then
                local vg_size_bytes=$((vg_size * 4 * 1024 * 1024))
                local vg_size_gb=$((vg_size_bytes / 1024 / 1024 / 1024))
                
                local swap_mb=${swap_size%G}
                local root_mb=${root_size%G}
                local total_needed=$((swap_mb + root_mb + 5))
                
                if [ "$vg_size_gb" -lt "$total_needed" ]; then
                    log "WARNING" "Small disk detected. Adjusting LVM sizes."
                    root_size="15G"
                    swap_size="1G"
                fi
            fi
            
            execute lvcreate -L "$swap_size" vg0 -n swap
            execute lvcreate -L "$root_size" vg0 -n root
            execute lvcreate -l 100%FREE vg0 -n home
            
            execute mkswap /dev/vg0/swap
            execute swapon /dev/vg0/swap
            
            ROOT_MAPPER="/dev/vg0/root"
            SWAP_MAPPER="/dev/vg0/swap"
            HOME_MAPPER="/dev/vg0/home"
            ENCRYPTED_PART="$LVM_PART"
            ;;
    esac
    
    if [ -n "${BOOT_PART:-}" ]; then
        execute mkfs.fat -F32 "$BOOT_PART"
    fi
    if [ -n "${ROOT_MAPPER:-}" ]; then
        execute mkfs.ext4 -F "$ROOT_MAPPER"
    fi
    if [ -n "${HOME_MAPPER:-}" ]; then
        execute mkfs.ext4 -F "$HOME_MAPPER"
    fi
    
    echo "$ENCRYPTED_PART" > "$STATE_DIR/encrypted-part"
    export ROOT_MAPPER SWAP_MAPPER HOME_MAPPER ENCRYPTED_PART
    log "INFO" "Encryption setup complete"
}
