kernel_main:
    call vga_selftest
    mov esi, welcome
    call console_puts
    call idt_init
    call pic_init
    call keyboard_init
    mov esi, keyboard_ready
    call console_puts
    sti
    jmp shell_start
keyboard_ready db '[KBD] IRQ1 ready',10,0
vga_selftest:
    call vga_clear
    mov byte [vga_color], 0x1e
    mov al, 'Q'
    call vga_putc
    cmp word [0xb8000], 0x1e51
    jne .fail
    mov al, 9
    call vga_putc
    cmp word [vga_position], 8
    jne .fail
    mov al, 8
    call vga_putc
    cmp word [vga_position], 7
    jne .fail
    mov al, 10
    call vga_putc
    cmp word [vga_position], 80
    jne .fail
    mov al, 'R'
    call vga_putc
    mov al, 13
    call vga_putc
    cmp word [vga_position], 80
    jne .fail
    mov word [vga_position], 1999
    mov al, 'X'
    call vga_putc
    cmp word [vga_position], 1920
    jne .fail
    cmp word [0xb8000+1919*2], 0x1e58
    jne .fail
    xor al, al
    call vga_cursor_visible
    mov dx, 0x3d5
    in al, dx
    test al, 0x20
    jz .fail
    mov al, 1
    call vga_cursor_visible
    in al, dx
    test al, 0x20
    jnz .fail
    call vga_cursor
    mov dx, 0x3d4
    mov al, 0x0f
    out dx, al
    inc dx
    in al, dx
    cmp al, 0x80              ; low byte of 1920
    jne .fail
    mov byte [vga_color], 0x0b
    call vga_clear
    mov esi, vga_test_ok
    call serial_puts
    ret
.fail:
    mov esi, vga_test_fail
    call serial_puts
    cli
.stop:
    hlt
    jmp .stop
vga_test_ok db '[TEST] VGA self-test PASS',10,0
vga_test_fail db '[FAIL] VGA self-test',10,0
welcome db 10
    db '  _ __   ___   ___  ____',10
    db ' | ',39,'_ \ / _ \ / _ \/ ___|',10
    db ' | | | | (_) | (_) \___ \',10
    db ' |_| |_|\___/ \___/|____/',10,10
    db '  No Linux. No Windows. No C. Just Assembly.',10
    db '  x86 / 32-bit protected mode / kernel 0.1.0',10,10
    db '  VGA terminal ready.',10,0
