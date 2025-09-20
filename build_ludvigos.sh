#!/bin/bash
set -e

# Цвета
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
CYAN="\e[36m"
RESET="\e[0m"

# Название ОС
OS_NAME="LudvigOS"
BUILD_DIR="$PWD/build"
ISO_DIR="$PWD/iso"

# Определяем дистрибутив
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
    elif type uname >/dev/null 2>&1; then
        DISTRO=$(uname -s)
    else
        DISTRO="unknown"
    fi
}

# Установка пакетов в зависимости от дистрибутива
install_package() {
    local pkg="$1"
    case $DISTRO in
        arch|manjaro)
            if [ "$pkg" = "i686-elf-gcc" ]; then
                if ! command -v yay >/dev/null 2>&1; then
                    echo -e "${RED}[!] yay не найден. Установите yay вручную.${RESET}"
                    exit 1
                fi
                yay -S --noconfirm i686-elf-gcc i686-elf-binutils
            else
                sudo pacman -S --needed "$pkg" --noconfirm
            fi
            ;;
        ubuntu|debian|linuxmint)
            sudo apt update
            sudo apt install -y "$pkg"
            ;;
        fedora|centos|rhel)
            sudo dnf install -y "$pkg" || sudo yum install -y "$pkg"
            ;;
        opensuse|suse)
            sudo zypper install -y "$pkg"
            ;;
        *)
            echo -e "${RED}[!] Неподдерживаемый дистрибутив: $DISTRO${RESET}"
            echo -e "${YELLOW}[!] Установите следующие пакеты вручную:${RESET}"
            echo -e "    - nasm"
            echo -e "    - i686-elf-gcc (кросс-компилятор)"
            echo -e "    - grub2-common"
            echo -e "    - xorriso"
            echo -e "    - qemu-system-x86"
            exit 1
            ;;
    esac
}

# Проверка и установка инструментов
check_and_install() {
    local cmd="$1" pkg="${2:-$1}"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${RED}[!] $cmd не найден.${RESET}"
        echo -e "${YELLOW}[!] Устанавливаем $pkg...${RESET}"
        install_package "$pkg"
        echo -e "${GREEN}[+] $cmd установлен!${RESET}"
    else
        echo -e "${GREEN}[+] $cmd уже установлен.${RESET}"
    fi
}

echo -e "${CYAN}============================================================${RESET}"
echo -e "${CYAN}           Сборка ${OS_NAME}${RESET}"
echo -e "${CYAN}============================================================${RESET}"

# ========================================
# 0️⃣ Определяем дистрибутив и проверяем инструменты
# ========================================
echo -e "${YELLOW}[0️⃣] Определяем дистрибутив...${RESET}"
detect_distro
echo -e "${GREEN}[*] Дистрибутив: $DISTRO${RESET}"

echo -e "${YELLOW}[0️⃣] Проверяем инструменты...${RESET}"

case $DISTRO in
    arch|manjaro)
        check_and_install yay "yay"
        check_and_install nasm "nasm"
        check_and_install i686-elf-g++ "i686-elf-gcc"
        check_and_install grub-mkrescue "grub"
        check_and_install xorriso "xorriso"
        check_and_install qemu-system-i386 "qemu-full"
        ;;
    ubuntu|debian|linuxmint)
        check_and_install nasm "nasm"
        check_and_install i686-elf-g++ "gcc-i686-elf"
        check_and_install grub-mkrescue "grub-common"
        check_and_install xorriso "xorriso"
        check_and_install qemu-system-i386 "qemu-system-x86"
        ;;
    fedora)
        check_and_install nasm "nasm"
        check_and_install i686-elf-g++ "i686-elf-gcc"
        check_and_install grub-mkrescue "grub2-tools"
        check_and_install xorriso "xorriso"
        check_and_install qemu-system-i386 "qemu-system-x86"
        ;;
    *)
        # Для неизвестных дистрибутивов проверяем минимальный набор
        check_and_install nasm "nasm"
        check_and_install i686-elf-g++ "i686-elf-gcc"
        check_and_install grub-mkrescue "grub"
        check_and_install xorriso "xorriso"
        check_and_install qemu-system-i386 "qemu"
        ;;
esac

echo -e "${GREEN}[*] Все инструменты готовы!${RESET}"
echo -e "${CYAN}------------------------------------------------------------${RESET}"

# ========================================
# 1️⃣ Очистка
# ========================================
echo -e "${YELLOW}[1️⃣] Очищаем предыдущие сборки...${RESET}"
rm -rf "$BUILD_DIR" "$ISO_DIR"
mkdir -p "$BUILD_DIR/boot" "$BUILD_DIR/kernel" "$ISO_DIR/boot/grub"
echo -e "${GREEN}[*] Директории созданы${RESET}"
echo -e "${CYAN}------------------------------------------------------------${RESET}"

# ========================================
# 2️⃣ Bootloader
# ========================================
echo -e "${YELLOW}[2️⃣] Создаём boot.asm...${RESET}"
cat > "$BUILD_DIR/boot/boot.asm" << 'EOF'
[BITS 16]
[ORG 0x7C00]

start:
    cli
    mov ax, 0x07C0
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00
    sti
.hang:
    jmp .hang

times 510-($-$$) db 0
dw 0xAA55
EOF
echo -e "${GREEN}[*] boot.asm создан${RESET}"
echo -e "${CYAN}------------------------------------------------------------${RESET}"

# ========================================
# 3️⃣ Ядро с автоматическим вводом команд
# ========================================
echo -e "${YELLOW}[3️⃣] Создаём kernel.cpp с автоматическим вводом команд...${RESET}"
cat > "$BUILD_DIR/kernel/kernel.cpp" << 'EOF'
// Multiboot header
__attribute__((section(".multiboot")))
__attribute__((aligned(4)))
unsigned int multiboot_header[] = {
    0x1BADB002, // magic
    0x00000003, // flags
    0xE4524FFB  // checksum
};

// VGA video memory
volatile char* video = (volatile char*)0xB8000;
int cursor_pos = 0;

void clear_screen() {
    for(int i = 0; i < 80*25*2; i += 2) {
        video[i] = ' ';
        video[i+1] = 0x07;
    }
    cursor_pos = 0;
}

void print_char(char c, char color = 0x07) {
    if(c == '\n') {
        cursor_pos = (cursor_pos + 160) / 160 * 160;
    } else {
        video[cursor_pos] = c;
        video[cursor_pos + 1] = color;
        cursor_pos += 2;
    }

    // Scroll if needed
    if(cursor_pos >= 80*25*2) {
        for(int i = 0; i < 80*24*2; i++) {
            video[i] = video[i + 160];
        }
        for(int i = 80*24*2; i < 80*25*2; i += 2) {
            video[i] = ' ';
            video[i+1] = 0x07;
        }
        cursor_pos = 80*24*2;
    }
}

void print(const char* str, char color = 0x07) {
    for(int i = 0; str[i] != '\0'; i++) {
        print_char(str[i], color);
    }
}

// String comparison
int strcmp(const char* s1, const char* s2) {
    while(*s1 && (*s1 == *s2)) {
        s1++;
        s2++;
    }
    return *(unsigned char*)s1 - *(unsigned char*)s2;
}

// Execute command directly
void execute_command(const char* command) {
    print("LudvigOS> ", 0x0A);
    print(command, 0x0F);
    print("\n", 0x0A);

    if(strcmp(command, "help") == 0) {
        print("Available commands:\n", 0x0E);
        print("help    - Show this help\n", 0x0E);
        print("clear   - Clear screen\n", 0x0E);
        print("version - Show OS version\n", 0x0E);
        print("reboot  - Reboot system\n", 0x0E);
    }
    else if(strcmp(command, "clear") == 0) {
        clear_screen();
    }
    else if(strcmp(command, "version") == 0) {
        print("LudvigOS v1.0\n", 0x0C);
    }
    else if(strcmp(command, "reboot") == 0) {
        print("Rebooting...\n", 0x0C);
        // Trigger reboot through keyboard controller
        asm volatile ("outb %0, $0x64" :: "a"((char)0xFE));
    }
    else {
        print("Unknown command: ", 0x0C);
        print(command, 0x0C);
        print("\nType 'help' for available commands\n", 0x0E);
    }
}

// Simple delay function
void delay() {
    for(volatile long i = 0; i < 100000000; i++);
}

extern "C" void kmain();

extern "C" void _start() {
    kmain();
    while(1) __asm__("hlt");
}

extern "C" void kmain() {
    clear_screen();
    print("LudvigOS v1.0 - Automatic Command Demo\n", 0x0A);
    print("Commands will be executed every 3 seconds\n", 0x0B);
    print("========================================\n", 0x0B);

    // Demo commands with delays
    execute_command("help");
    delay(); delay(); delay();

    execute_command("version");
    delay(); delay(); delay();

    execute_command("clear");
    delay(); delay(); delay();

    execute_command("version");
    delay(); delay(); delay();

    execute_command("reboot");
    delay(); delay(); delay();

    // Final message
    print("Demo completed. System halted.\n", 0x0C);

    while(1) {
        asm volatile ("hlt");
    }
}
EOF
echo -e "${GREEN}[*] kernel.cpp создан${RESET}"
echo -e "${CYAN}------------------------------------------------------------${RESET}"

# ========================================
# 4️⃣ Компиляция
# ========================================
echo -e "${YELLOW}[4️⃣] Компилируем загрузчик...${RESET}"
nasm -f bin "$BUILD_DIR/boot/boot.asm" -o "$BUILD_DIR/boot/boot.bin"
echo -e "${GREEN}[*] boot.bin создан${RESET}"

echo -e "${YELLOW}[4️⃣] Компилируем ядро...${RESET}"
i686-elf-g++ -ffreestanding -O2 -Wall -Wextra -std=c++11 -nostdlib -fno-builtin -fno-exceptions -fno-rtti -c "$BUILD_DIR/kernel/kernel.cpp" -o "$BUILD_DIR/kernel/kernel.o"
i686-elf-ld -n -o "$BUILD_DIR/kernel/kernel.elf" -Ttext 0x100000 "$BUILD_DIR/kernel/kernel.o" --entry=_start
echo -e "${GREEN}[*] kernel.elf создан${RESET}"

echo -e "${YELLOW}[4️⃣] Проверяем multiboot header...${RESET}"
if i686-elf-objdump -t "$BUILD_DIR/kernel/kernel.elf" | grep -q multiboot; then
    echo -e "${GREEN}[+] Multiboot header найден!${RESET}"
else
    echo -e "${RED}[!] Multiboot header не найден!${RESET}"
    exit 1
fi
echo -e "${CYAN}------------------------------------------------------------${RESET}"

# ========================================
# 5️⃣ Создание ISO
# ========================================
echo -e "${YELLOW}[5️⃣] Создаём конфигурацию GRUB...${RESET}"
cat > "$ISO_DIR/boot/grub/grub.cfg" << 'EOF'
menuentry "LudvigOS" {
    multiboot /boot/kernel.elf
    boot
}
EOF
echo -e "${GREEN}[*] grub.cfg создан${RESET}"

echo -e "${YELLOW}[5️⃣] Копируем файлы...${RESET}"
cp "$BUILD_DIR/boot/boot.bin" "$ISO_DIR/boot/"
cp "$BUILD_DIR/kernel/kernel.elf" "$ISO_DIR/boot/"
echo -e "${GREEN}[*] Файлы скопированы${RESET}"

echo -e "${YELLOW}[5️⃣] Создаём ISO образ...${RESET}"
grub-mkrescue -o "$PWD/${OS_NAME}.iso" "$ISO_DIR"
echo -e "${GREEN}[*] ISO образ создан${RESET}"
echo -e "${CYAN}------------------------------------------------------------${RESET}"

# ========================================
# 6️⃣ Запуск
# ========================================
echo -e "${YELLOW}[6️⃣] Запуск в QEMU...${RESET}"
qemu-system-i386 -cdrom "$PWD/${OS_NAME}.iso" -m 512M

# ========================================
# 7️⃣ Завершение
# ========================================
echo -e "${CYAN}============================================================${RESET}"
echo -e "${GREEN}[🎉] LudvigOS успешно собран и запущен!${RESET}"
echo -e "${YELLOW}[📁] ISO образ: $PWD/${OS_NAME}.iso${RESET}"
echo -e "${YELLOW}[⚡] Команда для ручного запуска: qemu-system-i386 -cdrom $PWD/${OS_NAME}.iso -m 512M${RESET}"
echo -e "${CYAN}============================================================${RESET}"
