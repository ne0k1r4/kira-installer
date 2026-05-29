<p align="center">
    <img src="https://media.giphy.com/media/YmZOBDYBcmWK4/giphy.gif" width="100%" alt="Misa Amane Hero">
</p>

# <div align="center">💀 𝕶IRA 𝕴NSTALLER 💀</div>
### <div align="center">𝕿he 𝕬bsolute 𝕬rch 𝕷inux 𝕰xecution</div>

<p align="center">
    <a href="#"><img src="https://img.shields.io/badge/STATUS-EXECUTING_JUDGMENT-darkred?style=for-the-badge&logo=arch-linux" alt="Status" /></a>
    <a href="#"><img src="https://img.shields.io/badge/ENCRYPTION-SHINIGAMI_VAULT-black?style=for-the-badge&logo=gnupg" alt="Security" /></a>
    <a href="#"><img src="https://img.shields.io/badge/LICENSE-DEATH_NOTE-black?style=for-the-badge" alt="License" /></a>
</p>

<div align="center">
<b>KIRA INSTALLER is your automated Arch Linux setup script. The installer is themed around Misa Amane, your loyal gothic-lolita waifu assistant. Devoted entirely to you (Kira), she uses her Shinigami Eyes to read partition layouts, sweep away bloatware, and build a flawless, secure operating system under your absolute command.</b>
</div>

---

<table width="100%" style="border: none;">
    <tr>
        <td width="50%" align="center">
            <h2>📓 The Shinigami Eye Deal</h2>
            <img src="https://media.giphy.com/media/o2KLYPem407CM/giphy.gif" width="100%" style="border-radius: 8px;" alt="Writing Names">
        </td>
        <td width="50%" align="left">
            <h3>"I'll do anything for you, Lord Kira!"</h3>
            <p>Misa Amane has traded half her life for the Shinigami Eyes. She sees all your block devices, mounts, and UUIDs instantly. She writes system bloatware and partitions in her Death Note to format them precisely for you.</p>
            <ul>
                <li>💀 <b>Pure Devotion (Zero Bloat):</b> Wipes target disks completely and installs only what you authorize.</li>
                <li>🔐 <b>Security Vaults (LUKS2 + LVM):</b> Locks down your directories using argon2id encryption.</li>
                <li>📺 <b>Whiptail Face:</b> Interactive user interface menus for disk setup and configurations.</li>
                <li>🏎️ <b>Hardware Aware:</b> Installs Intel/AMD microcode and multi-GPU drivers (AMD, Intel, NVIDIA) automatically.</li>
                <li>🍬 <b>Sweet Pacman:</b> Configures parallel downloads, colored console outputs, and the ILoveCandy progress bar because Misa loves sweets!</li>
            </ul>
        </td>
    </tr>
</table>

---

## 📜 Rules of Execution (Quick Start)

### 1. The Preparation
Boot into the official Arch Linux installation media and verify your network connection:
```bash
ping archlinux.org -c 3
```

### 2. Procure the Notebook
Clone the script repository to download the files:
```bash
git clone https://github.com/jhjmhgKGON/555.git kira-installer
cd kira-installer
chmod +x kira.sh
```

### 3. Execute Judgment
Run the installer script with root privileges:
```bash
sudo ./kira.sh
```

---

## 🧠 Preseed (Automated Mode)
Bypass interactive prompts and perform silent installations using a `.conf` configuration template:

```bash
# Execute silent automated installation
sudo ./kira.sh --preseed preseed/production.conf
```

> [!NOTE]
> Check `preseed/production.conf` for layout guidelines. Set `AUTO=true` to skip all confirmations and dialog menus.

---

## 🧩 The Notebook Pages (Architecture)

Every component is modular, working under your master commands:

* [kira.sh](file:///home/LIGHT/dev/projects/kira-installer/kira.sh) — **Kira's Will** (Master orchestration, validation, and FD 3 updates).
* [lib/ui.sh](file:///home/LIGHT/dev/projects/kira-installer/lib/ui.sh) — **Misa's Face** (ASCII menu layouts, dialogs, and progress bars).
* [lib/disk.sh](file:///home/LIGHT/dev/projects/kira-installer/lib/disk.sh) — **The Notebook** (Wiping blocks, partition table writes, and mounting).
* [lib/encryption.sh](file:///home/LIGHT/dev/projects/kira-installer/lib/encryption.sh) — **The Hidden Desk Drawer** (LUKS2 argon2id encryption & LVM logic).
* [lib/system.sh](file:///home/LIGHT/dev/projects/kira-installer/lib/system.sh) — **Misa's Diary** (Dynamic timezone matching, user setup, base packages, and pacman configurations).
* [lib/bootloader.sh](file:///home/LIGHT/dev/projects/kira-installer/lib/bootloader.sh) — **The Shinigami Deal** (Grants systemd-boot for UEFI systems or GRUB for BIOS).

---

## ⚠️ Warning
**SYSTEM DESTRUCTION:** Executing Kira's installer **WILL FORMAT AND WIPE ALL PREVIOUS DATA ON THE TARGET DISK**. Once written in Misa's notebook, your data cannot be retrieved!

<br>

### <div align="center">"I'll write their names... and build your new world, Kira!" 📓 🖤</div>
