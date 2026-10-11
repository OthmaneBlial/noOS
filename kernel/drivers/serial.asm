; All functions preserve general registers. AL=character, ESI=NUL string.
serial_init:
    push eax
    push edx
    mov dx, 0x3f9
    xor al, al
    out dx, al
    mov dx, 0x3fb
    mov al, 0x80
    out dx, al
    mov dx, 0x3f8
    mov al, 1                 ; 115200 baud
    out dx, al
    inc dx
    xor al, al
    out dx, al
    mov dx, 0x3fb
    mov al, 3                 ; 8N1
    out dx, al
    mov dx, 0x3fa
    mov al, 0xc7
    out dx, al
    mov dx, 0x3fc
    mov al, 0x0b
    out dx, al
    pop edx
    pop eax
    ret
serial_putc:
    pushad
    mov bl, al
    mov ecx, 65536            ; bounded polling even if UART is absent
    mov dx, 0x3fd
.wait:
    in al, dx
    test al, 0x20
    jnz .send
    loop .wait
    jmp .done
.send:
    mov dx, 0x3f8
    mov al, bl
    out dx, al
.done:
    popad
    ret
serial_puts:
    pushad
.next:
    lodsb
    test al, al
    jz .done
    call serial_putc
    jmp .next
.done:
    popad
    ret
