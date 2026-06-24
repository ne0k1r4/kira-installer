# 🌸 Waifu Arch Installer

A simple, devoted, and cute Arch Linux installation script. It automates partitioning, sets up secure LUKS2 volume encryption (the Sakura Vault), and installs a clean Hyprland Wayland environment with a gorgeous hot-pink look.

## 🎀 Quick Start

Just run this on the Arch Live ISO:

```bash
# 1. Grab the script
git clone https://github.com/ne0k1r4/kira-installer.git
cd kira-installer
chmod +x kira.sh

# 2. Run the assistant!
sudo ./kira.sh
```

## 🛠️ Options
- **Preseed Mode:** Run silently using a preseed config: `sudo ./kira.sh --preseed preseed/production.conf` (remember to set `AUTO=true` to skip prompts!).
- **Dry Run:** Simulate a run safely without touching your disk: `sudo ./kira.sh --dry-run`

## 🧩 Structure
- `kira.sh` — The brain.
- `lib/ui.sh` — The cute Whiptail TUI.
- `lib/common.sh` — Colored console logs (`[🌸 WAIFU]`, `[⚠️ BAKA]`, `[💔 GOMEN]`).
- `lib/disk.sh` & `lib/encryption.sh` — Partitioning, mounts, and LUKS configurations.
- `lib/system.sh` & `lib/bootloader.sh` — Package installation, timezone syncing, and boot manager.
