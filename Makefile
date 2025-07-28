ISO_NAME = myos.iso
BOOT = boot/boot.asm
KERNEL = kernel/kernel.cpp
OBJ = build/kernel.o
BIN = build/kernel.bin
BOOTLOADER = build/bootloader.bin
LD = i686-elf-ld
GXX = i686-elf-g++

all: $(ISO_NAME)

build:
	mkdir -p build

$(OBJ): $(KERNEL) | build
	$(GXX) -ffreestanding -m32 -c $(KERNEL) -o $(OBJ)

$(BIN): $(OBJ)
	$(LD) -T linker.ld -o $(BIN) $(OBJ) -nostdlib

$(BOOTLOADER): $(BOOT) | build
	nasm -f bin $(BOOT) -o $(BOOTLOADER)

$(ISO_NAME): $(BOOTLOADER) $(BIN)
	cat $(BOOTLOADER) $(BIN) > $(ISO_NAME)

run: $(ISO_NAME)
	qemu-system-i386 -drive format=raw,file=$(ISO_NAME)

clean:
	rm -rf build *.iso
