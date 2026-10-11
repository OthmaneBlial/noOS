%define VGA_BASE 0xb8000
%define VGA_COLS 80
%define VGA_CELLS 2000
; AL=character, ESI=string; output routines preserve all general registers.
console_putc:
    call serial_putc
    jmp vga_putc
console_puts:
    pushad
.next:
    lodsb
    test al, al
    jz .done
    call console_putc
    jmp .next
.done:
    popad
    ret
vga_init:
    pushad
    mov dx, 0x3d4
    mov al, 0x0a
    out dx, al
    inc dx
    mov al, 14
    out dx, al
    dec dx
    mov al, 0x0b
    out dx, al
    inc dx
    mov al, 15
    out dx, al
    popad
    jmp vga_clear
vga_clear:
    pushad
    mov edi, VGA_BASE
    mov ah, [vga_color]
    mov al, ' '
    mov ecx, VGA_CELLS
    rep stosw
    mov word [vga_position], 0
    call vga_cursor
    popad
    ret
vga_cursor:
    pushad
    mov bx, [vga_position]
    mov dx, 0x3d4
    mov al, 0x0f
    out dx, al
    inc dx
    mov al, bl
    out dx, al
    dec dx
    mov al, 0x0e
    out dx, al
    inc dx
    mov al, bh
    out dx, al
    popad
    ret
; AL=0 hides cursor; any nonzero AL shows it without changing its shape.
vga_cursor_visible:
    pushad
    mov bl, al
    mov dx, 0x3d4
    mov al, 0x0a
    out dx, al
    inc dx
    in al, dx
    and al, 0xdf
    test bl, bl
    jnz .set
    or al, 0x20
.set:
    out dx, al
    popad
    ret
vga_putc:
    pushad
    movzx ebx, word [vga_position]
    cmp al, 10
    je .newline
    cmp al, 13
    je .return
    cmp al, 8
    je .backspace
    cmp al, 9
    je .tab
    cmp al, 32
    jb .done
    mov ah, [vga_color]
    mov [VGA_BASE+ebx*2], ax
    inc ebx
    jmp .adjust
.newline:
    mov eax, ebx
    xor edx, edx
    mov ecx, VGA_COLS
    div ecx
    sub ebx, edx
    add ebx, VGA_COLS
    jmp .adjust
.return:
    mov eax, ebx
    xor edx, edx
    mov ecx, VGA_COLS
    div ecx
    sub ebx, edx
    jmp .adjust
.backspace:
    test ebx, ebx
    jz .done
    dec ebx
    mov ah, [vga_color]
    mov al, ' '
    mov [VGA_BASE+ebx*2], ax
    jmp .adjust
.tab:
    mov ecx, ebx
    and ecx, 7
    neg ecx
    add ecx, 8
.spaces:
    mov al, ' '
    call vga_putc
    loop .spaces
    jmp .done
.adjust:
    cmp ebx, VGA_CELLS
    jb .store
    mov esi, VGA_BASE+VGA_COLS*2
    mov edi, VGA_BASE
    mov ecx, VGA_CELLS-VGA_COLS
    rep movsw
    mov ah, [vga_color]
    mov al, ' '
    mov ecx, VGA_COLS
    rep stosw
    sub ebx, VGA_COLS
.store:
    mov [vga_position], bx
    call vga_cursor
.done:
    popad
    ret
vga_color db 0x0b
vga_position dw 0
