# LudvigOS 🚀

![LudvigOS](https://img.shields.io/badge/Version-1.0-blue)
![Arch Linux](https://img.shields.io/badge/Built%20on-Arch%20Linux-1793D1)
![License](https://img.shields.io/badge/License-MIT-green)

**A modern operating system from Ludvig2457 company**

## ✨ Features

- ✅ **Full-featured kernel** in C++ with Multiboot support
- ✅ **VGA driver** with text output and screen scrolling
- ✅ **Command shell** with innovative auto-demo mode
- ✅ **System commands**: help, version, clear, reboot
- ✅ **Bootloader** via GRUB2
- ✅ **Automatic demonstration** (3 seconds per command)

## 🛠 Building

```bash
# Requirements:
# - NASM
# - i686-elf-gcc
# - GRUB
# - xorriso

git clone https://github.com/Ludvig2457/LudvigOS.git
cd LudvigOS
chmod +x build_ludvigos.sh
./build_ludvigos.sh
