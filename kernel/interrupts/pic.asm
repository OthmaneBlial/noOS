pic_init:
    pushad
    mov al, 0x11
    out 0x20, al
    call io_wait
    out 0xa0, al
    call io_wait
    mov al, 0x20
    out 0x21, al
    call io_wait
    mov al, 0x28
    out 0xa1, al
    call io_wait
    mov al, 4
    out 0x21, al
    call io_wait
    mov al, 2
    out 0xa1, al
    call io_wait
    mov al, 1
    out 0x21, al
    call io_wait
    out 0xa1, al
    call io_wait
    mov al, 0xff
    out 0x21, al
    out 0xa1, al
    popad
    ret
io_wait:
    push eax
    xor al, al
    out 0x80, al
    pop eax
    ret
