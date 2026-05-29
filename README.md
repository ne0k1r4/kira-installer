# 📓 KIRA INSTALLER

Kira Installer is an automated, themed Arch Linux installation script. Working as your loyal system assistant (Misa Amane), it partitions drives, configures encryption vaults, and deploys a clean Hyprland Wayland desktop environment under your absolute command.

## ⚡ Features

- **Pure Devotion (Zero Bloat):** Wipes target disks completely and installs only what you authorize.
- **Stealth Vaults (LUKS2 + LVM):** Implements physical volume encryption via `argon2id`.
- **Gothic Whiptail TUI:** Sleek, unified dialog menus for disk selection and credentials.
- **Hardware Configured:** Auto-detects system CPU microcode and multi-GPU configurations.
- **Candy-enabled Package Feeds:** Custom-sweetened Pacman downloads with speed optimizations.

## 🚀 Execution Guide

### 1. Network Prep
Ensure you have active internet connectivity:
```bash
ping archlinux.org -c 3
```

### 2. Retrieve the Notebook
Clone the script repository and set permissions:
```bash
git clone https://github.com/ne0k1r4/kira-installer.git
cd kira-installer
chmod +x kira.sh
```

### 3. Deploy
Execute the installer with root privileges:
```bash
sudo ./kira.sh
```

## 🧠 Automated Deployment (Preseed)

Bypass TUI dialogs and execute silent installations using `.conf` files:
```bash
sudo ./kira.sh --preseed preseed/production.conf
```
*Set `AUTO=true` in your preseed configuration to skip all confirmation prompts.*

## 🧩 Architecture

- **`kira.sh`** — Master orchestrator and state coordinator.
- **`lib/common.sh`** — Ledger logs, retry helper, and password wipes.
- **`lib/ui.sh`** — TUI menus, welcome dialogs, and progress gauges.
- **`lib/disk.sh`** — Wipefs, parted partition segments, and mounting.
- **`lib/encryption.sh`** — LUKS2 containerization and LVM setups.
- **`lib/system.sh`** — Timezone, user credentials, package sets, and Hyprland styling.
- **`lib/bootloader.sh`** — UEFI Systemd-boot and BIOS GRUB setup.

---

⚠️ **WARNING:** Running this script **WILL PERMANENTLY ERASE ALL DATA** on the selected disk. Proceed with absolute caution.
