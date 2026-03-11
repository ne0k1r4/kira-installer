# KIRA Arch Installer - Installation Guide

This guide provides detailed instructions on how to use KIRA to install Arch Linux.

## 1. Prerequisites

Before running the installer, you must:
1. Boot into the official **Arch Linux Installation Medium** (USB/ISO).
2. Ensure you have an active internet connection (`ping archlinux.org`).
3. Identify your target installation disk using `lsblk` (e.g., `/dev/sda` or `/dev/nvme0n1`).

## 2. Acquiring KIRA

In the live environment, acquire the installer:
```bash
git clone https://github.com/yourusername/kira-installer.git
cd kira-installer
chmod +x kira.sh
```

## 3. Interactive Installation

The easiest way to install Arch is using the interactive TUI (Text User Interface):
```bash
sudo ./kira.sh
```
Follow the on-screen prompts:
- Select your **Installation Mode** (Single Boot).
- Select your **Target Disk**.
- Choose your **Encryption** preferences (None, LUKS2, LUKS2+LVM).
- Enter your **Hostname**, **Username**, and **Passwords**.

KIRA will take over from there and fully orchestrate the installation!

## 4. Automated Installation (Preseed)

If you are deploying multiple systems or want a completely silent installation, utilize a preseed configuration block:
```bash
sudo ./kira.sh --preseed preseed/production.conf
```
*For detailed information on configuring preseeds, refer to `PRESEED.md`.*

## 5. Post-Installation

Once KIRA finishes:
1. Remove the installation media.
2. Select **Reboot**.
3. Log into your fresh, flawlessly configured Arch Linux system.

> *"I will become the god of this new system!"*
