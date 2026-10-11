irq_dispatch:
    mov ebp, eax
    cmp eax, 39
    je .spurious_master
    cmp eax, 47
    je .spurious_slave
    cmp eax, 33
    jne .eoi
    call keyboard_irq
.eoi:
    cmp ebp, 40
    jb .master
    mov al, 0x20
    out 0xa0, al
.master:
    mov al, 0x20
    out 0x20, al
    ret
.spurious_master:
    mov al, 0x0b
    out 0x20, al
    in al, 0x20
    test al, 0x80
    jnz .eoi
    ret
.spurious_slave:
    mov al, 0x0b
    out 0xa0, al
    in al, 0xa0
    test al, 0x80
    jnz .eoi
    jmp .master              ; acknowledge cascade, not a nonexistent slave IRQ
