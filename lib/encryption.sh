#!/usr/bin/env bash
# 🍎 KIRA INSTALLER — The Vault (LUKS2 Encryption & LVM Setup)
# "Gaurding your privacy with deep crypto wrapping. If you don't have the key, you don't exist."

# ======================================================================
# CRYPTO SELECTION MENU (Enabling the lock screen)
# ======================================================================
encryption_setup() {
    if [ -n "${ENCRYPTION:-}" ]; then
        log "INFO" "Encryption mode already set to: $ENCRYPTION"
        return 0
    fi
    
    if ui_yesno "Hide your data from L's eyes? Enable LUKS2 encryption? (Highly recommended)"; then
        ENCRYPTION="luks2"
        
        if [ -z "${CRYPT_PASS:-}" ]; then
            get_password_confirm "Enter Encryption Passphrase" CRYPT_PASS
        fi
        
        if ui_yesno "Should we construct LVM logical folders inside the vault? (LUKS+LVM)"; then
            ENCRYPTION="luks2+lvm"
        fi
        
        log "INFO" "The Vault is prepared! Enabled $ENCRYPTION protection. L won't find anything here."
    else
        ENCRYPTION="none"
        log "INFO" "No encryption selected! Your files will remain exposed in the open world."
    fi
    
    export ENCRYPTION
    [ -n "${CRYPT_PASS:-}" ] && export CRYPT_PASS
}

# ======================================================================
# CRYPTO FORMATTER (Locking up the directories)
# ======================================================================
encryption_format() {
    local LVM_PART="${LVM_PART:-$ROOT_PART}"

    if [ "$ENCRYPTION" = "none" ]; then
        ENCRYPTED_PART="$ROOT_PART"
        ROOT_MAPPER="$ROOT_PART"
        export ENCRYPTED_PART ROOT_MAPPER
        echo "$ENCRYPTED_PART" > "$STATE_DIR/encrypted-part"
    else
        if [ -z "${CRYPT_PASS:-}" ]; then
            log "ERROR" "Passphrase missing! Misa cannot seal the vault without a key."
            return 1
        fi
    fi
    
    case $ENCRYPTION in
        luks2)
            if [ -z "$ROOT_PART" ]; then
                log "ERROR" "Root partition path is missing!"
                return 1
            fi
            log "INFO" "Sealing root partition $ROOT_PART inside a LUKS2 vault (using argon2id)..."
            printf "%s" "$CRYPT_PASS" | execute cryptsetup luksFormat --type luks2 --pbkdf argon2id "$ROOT_PART" -
            log "INFO" "Unlocking LUKS vault as /dev/mapper/cryptroot..."
            printf "%s" "$CRYPT_PASS" | execute cryptsetup open "$ROOT_PART" cryptroot -
            ROOT_MAPPER="/dev/mapper/cryptroot"
            ENCRYPTED_PART="$ROOT_PART"
            ;;
            
        luks2+lvm)
            if [ -z "$LVM_PART" ]; then
                log "ERROR" "LVM target partition path is missing!"
                return 1
            fi
            log "INFO" "Sealing LVM partition $LVM_PART inside a LUKS2 vault..."
            printf "%s" "$CRYPT_PASS" | execute cryptsetup luksFormat --type luks2 --pbkdf argon2id "$LVM_PART" -
            log "INFO" "Unlocking LVM vault container as /dev/mapper/cryptlvm..."
            printf "%s" "$CRYPT_PASS" | execute cryptsetup open "$LVM_PART" cryptlvm -
            
            log "INFO" "Initializing LVM groups: building the vg0 volume group..."
            execute pvcreate /dev/mapper/cryptlvm
            execute vgcreate vg0 /dev/mapper/cryptlvm
            
            local swap_size="${SWAP_SIZE:-2G}"
            local root_size="${ROOT_SIZE:-30G}"
            
            # Squeeze volume sizes if we are dealing with tight virtual disk space
            local vg_size
            vg_size=$(vgdisplay vg0 2>/dev/null | grep "Total PE" | awk '{print $3}' 2>/dev/null || echo "0")
            if [[ "$vg_size" =~ ^[0-9]+$ ]] && [ "$vg_size" -gt 0 ]; then
                local vg_size_bytes=$((vg_size * 4 * 1024 * 1024))
                local vg_size_gb=$((vg_size_bytes / 1024 / 1024 / 1024))
                
                local swap_mb=${swap_size%G}
                local root_mb=${root_size%G}
                local total_needed=$((swap_mb + root_mb + 5))
                
                if [ "$vg_size_gb" -lt "$total_needed" ]; then
                    log "WARNING" "Wait, this disk is tiny! Squeezing LVM logical volumes to fit..."
                    root_size="15G"
                    swap_size="1G"
                fi
            fi
            
            log "INFO" "Carving LVM sectors (swap=$swap_size, root=$root_size, home=remaining)..."
            execute lvcreate -L "$swap_size" vg0 -n swap
            execute lvcreate -L "$root_size" vg0 -n root
            execute lvcreate -l 100%FREE vg0 -n home
            
            log "INFO" "Initializing swap space (Misa's scratchpad)..."
            execute mkswap /dev/vg0/swap
            execute swapon /dev/vg0/swap
            
            ROOT_MAPPER="/dev/vg0/root"
            SWAP_MAPPER="/dev/vg0/swap"
            HOME_MAPPER="/dev/vg0/home"
            ENCRYPTED_PART="$LVM_PART"
            ;;
    esac
    
    # Run formatting across mapped directories
    if [ -n "${BOOT_PART:-}" ]; then
        log "INFO" "Formatting EFI Boot partition ($BOOT_PART) as FAT32..."
        execute mkfs.fat -F32 "$BOOT_PART"
    fi
    if [ -n "${ROOT_MAPPER:-}" ]; then
        log "INFO" "Formatting Root partition ($ROOT_MAPPER) as EXT4..."
        execute mkfs.ext4 -F "$ROOT_MAPPER"
    fi
    if [ -n "${HOME_MAPPER:-}" ]; then
        log "INFO" "Formatting Home partition ($HOME_MAPPER) as EXT4..."
        execute mkfs.ext4 -F "$HOME_MAPPER"
    fi
    
    echo "$ENCRYPTED_PART" > "$STATE_DIR/encrypted-part"
    export ROOT_MAPPER SWAP_MAPPER HOME_MAPPER ENCRYPTED_PART
    log "INFO" "The vaults are locked and formatted successfully, Lord Kira."
}
