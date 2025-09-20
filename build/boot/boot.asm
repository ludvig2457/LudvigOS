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
