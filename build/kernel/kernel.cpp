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
