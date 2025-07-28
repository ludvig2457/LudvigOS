[BITS 16]
[ORG 0x7C00]

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    ; Загрузим вторую часть (ядро) с диска в память
    mov ah, 0x02
    mov al, 1          ; кол-во секторов
    mov ch, 0
    mov cl, 2          ; сектор 2
    mov dh, 0
    mov dl, 0x80
    mov bx, 0x1000     ; адрес для загрузки ядра
    int 0x13
    jc disk_error

    jmp 0x0000:0x1000  ; прыжок в ядро

disk_error:
    mov si, disk_fail_msg
    call print
    jmp $

print:
    mov ah, 0x0E
.print_char:
    lodsb
    or al, al
    jz .done
    int 0x10
    jmp .print_char
.done:
    ret

disk_fail_msg db "Disk Read Error", 0

times 510 - ($ - $$) db 0
dw 0xAA55
