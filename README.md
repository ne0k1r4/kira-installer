# 🌸 WAIFU ARCH INSTALLER

Waifu Arch Installer is an automated, themed Arch Linux setup helper. Acting as your devoted desktop assistant, it guides you through partitioning, locks down volumes with argon2id Sakura Vault encryption, and configures a beautiful, glassmorphic Hyprland Wayland workspace under your Master direction.

## ⚡ Features

- **Pure Devotion (Zero Bloat):** Wipes target disks completely and installs only what you authorize.
- **Sakura Vaults (LUKS2 + LVM):** Implements physical volume encryption via `argon2id`.
- **Sakura Whiptail TUI:** Sleek, pink-accented dialog menus for disk selection and credentials.
- **Hardware Configured:** Auto-detects system CPU microcode and multi-GPU configurations.
- **Sweet Pacman Feeds:** Parallel downloads and Candy progress bars because she loves sweets! 🍬

## 🚀 Execution Guide

### 1. Network Prep
Ensure you have active internet connectivity:
```bash
ping archlinux.org -c 3
```

### 2. Retrieve the Assistant
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

- **`kira.sh`** — Master orchestrator and deployment coordinator.
- **`lib/common.sh`** — **The Ledger** (Waifu logs, retry helper, and password wipes).
- **`lib/ui.sh`** — **The Face** (Sakura pink Whiptail interface and progress pipes).
- **`lib/disk.sh`** — **The Architect** (Carving partition slots and mounting workspaces).
- **`lib/encryption.sh`** — **The Sakura Vault** (LUKS2 containerization and LVM setups).
- **`lib/system.sh`** — **The Heart** (Timezone, user credentials, package sets, and Hyprland styling).
- **`lib/bootloader.sh`** — **The Gateway** (UEFI Systemd-boot and BIOS GRUB setup).

---

⚠️ **WARNING:** Running this script **WILL PERMANENTLY ERASE ALL DATA** on the selected disk. Proceed with absolute caution.
