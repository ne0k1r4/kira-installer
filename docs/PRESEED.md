# KIRA Arch Installer - Preseed Configuration Guide

A **Preseed** configuration allows you to completely automate the KIRA Arch Installer. 

By setting explicit variables and passing them to KIRA via `--preseed`, the installer bypassing all interactive prompt elements (`whiptail` TUIs) and instead relies purely on your configuration.

## Basic Structure
Preseeds are essentially loaded as standard Bash variables. Example structure:

```bash
#!/bin/bash
# Minimal preseed for Kira Arch Installer
INSTALL_MODE="single"
SELECTED_DISK="/dev/sda"
HOSTNAME="kira"
USERNAME="user"
ENCRYPTION="none"
AUTO=true
NO_BANNER=true
NO_CONFIRM=true
```

## Available Variables

### Required
- `INSTALL_MODE`: Determines the installation layout (`single`, `dual`, `usb`).
- `SELECTED_DISK`: The target block device (e.g., `/dev/sda`, `/dev/nvme0n1`).
- `HOSTNAME`: Name of the system.
- `USERNAME`: Username for the newly generated user account.
- `ENCRYPTION`: Security format. Options: `none`, `luks2`, `luks2+lvm`.

### Optional Overrides
- `SWAP_SIZE`: Defines the swap partition size when using LVM (default: `8G`).
- `MIRROR_COUNTRY`: For pacman mirrorlist optimization (e.g., `US`, `DE`).

### Automation Flags
To skip interactive prompts:
- `AUTO`: Set to `true` to skip summary prompts and run blindly.
- `NO_BANNER`: Set to `true` to skip the startup Light Yagami TUI banner.
- `NO_CONFIRM`: Set to `true` to skip the warning that all disk data will be wiped.

### Password Injection (High Danger)
If you wish to fully automate without having to type passwords during the run:
- `USERPASS`: Password for user account.
- `CRYPT_PASS`: Drive encryption password (only used if `ENCRYPTION` is set).
*Warning: Running preseed with plaintext passwords is highly risky. Only do this via secured USB deployments.*

## Execution
Run KIRA by pointing to your specific `.conf` file:
```bash
sudo ./kira.sh --preseed /etc/kira-installer/preseed.conf
```
*Note: KIRA looks at `/etc/kira-installer/preseed.conf` by default. Using the `--preseed` argument temporarily overrides this path.*

> *"Excellent, it's all going perfectly according to plan..."*
