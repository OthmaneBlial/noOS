bits 32
org 0x10000
kernel_entry:
    cli
    mov esp, 0x90000
    cld
    call serial_init
    mov esi, hello
    call serial_puts
    mov edi, 0xb8000
    mov esi, hello
.print:
    lodsb
    test al, al
    jz .halt
    mov ah, 0x0b
    stosw
    jmp .print
.halt:
    hlt
    jmp .halt
hello db '[OK] Protected mode activated | noOS kernel entry',10,0
%include "kernel/drivers/serial.asm"
