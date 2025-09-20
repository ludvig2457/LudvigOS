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

echo -e "${CYAN}============================================================${RESET}"
echo -e "${CYAN}           Сборка ${OS_NAME}${RESET}"
echo -e "${CYAN}============================================================${RESET}"

# ========================================
# 0️⃣ Проверка инструментов
# ========================================
echo -e "${YELLOW}[0️⃣] Проверяем инструменты...${RESET}"

check_and_install() {
    local cmd="$1" pkg="$2" aur="$3"
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${RED}[!] $cmd не найден.${RESET}"
        if [ "$aur" = true ]; then
            echo -e "${YELLOW}[!] Устанавливаем $pkg из AUR...${RESET}"
            yay -S --noconfirm "$pkg"
        else
            echo -e "${YELLOW}[!] Устанавливаем $pkg...${RESET}"
            sudo pacman -S --needed "$pkg" --noconfirm
        fi
        echo -e "${GREEN}[+] $cmd установлен!${RESET}"
    else
        echo -e "${GREEN}[+] $cmd уже установлен.${RESET}"
    fi
}

check_and_install yay "yay" true
check_and_install nasm "nasm" false
check_and_install i686-elf-g++ "i686-elf-gcc i686-elf-binutils" true
check_and_install grub-mkrescue "grub" false
check_and_install xorriso "xorriso" false
check_and_install qemu-system-i386 "qemu-full" false

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

// Input buffer
char input_buffer[256];
int input_pos = 0;

void process_command() {
    if(input_pos == 0) return;

    print("\n", 0x0A);

    if(strcmp(input_buffer, "help") == 0) {
        print("Available commands:\n", 0x0E);
        print("help    - Show this help\n", 0x0E);
        print("clear   - Clear screen\n", 0x0E);
        print("version - Show OS version\n", 0x0E);
        print("reboot  - Reboot system\n", 0x0E);
    }
    else if(strcmp(input_buffer, "clear") == 0) {
        clear_screen();
    }
    else if(strcmp(input_buffer, "version") == 0) {
        print("LudvigOS v1.0\n", 0x0C);
    }
    else if(strcmp(input_buffer, "reboot") == 0) {
        print("Rebooting...\n", 0x0C);
        // Trigger reboot through keyboard controller
        asm volatile ("outb %0, $0x64" :: "a"((char)0xFE));
    }
    else {
        print("Unknown command: ", 0x0C);
        print(input_buffer, 0x0C);
        print("\nType 'help' for available commands\n", 0x0E);
    }

    // Reset buffer
    input_pos = 0;
    for(int i = 0; i < 256; i++) input_buffer[i] = 0;
}

// Function to simulate typing
void type_command(const char* command) {
    // Print prompt
    print("LudvigOS> ", 0x0A);

    // Type command character by character
    for(int i = 0; command[i] != '\0'; i++) {
        input_buffer[input_pos++] = command[i];
        print_char(command[i], 0x0F);

        // Add delay between key presses (0.1 second)
        for(volatile long j = 0; j < 10000000; j++);
    }

    // Press Enter
    print_char('\n');
    process_command();

    // Add 3-second delay before next command
    for(volatile long j = 0; j < 300000000; j++);
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

    // Demo commands with 3-second delays
    type_command("help");
    type_command("version");
    type_command("clear");
    type_command("version");
    type_command("reboot");

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
