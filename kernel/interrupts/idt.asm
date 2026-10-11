idt_init:
    pushad
    mov esi, isr_table
    mov edi, idt
    mov ecx, 256
.gate:
    lodsd
    mov [edi], ax
    mov word [edi+2], 0x08
    mov word [edi+4], 0x8e00
    shr eax, 16
    mov [edi+6], ax
    add edi, 8
    loop .gate
    mov byte [idt+128*8+5], 0xee ; INT 80h callable from CPL3
    lidt [idtr]
    popad
    ret
align 8
idt times 256 dq 0
idtr:
    dw 256*8-1
    dd idt
