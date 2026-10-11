; EAX=unsigned value. Decimal/hex output preserves all general registers.
print_u32:
    pushad
    mov edi, number_buffer+11
    mov byte [edi], 0
    mov ebx, 10
.digit:
    xor edx, edx
    div ebx
    add dl, '0'
    dec edi
    mov [edi], dl
    test eax, eax
    jnz .digit
    mov esi, edi
    call console_puts
    popad
    ret
print_hex:
    pushad
    mov ebx, eax
    mov esi, hex_prefix
    call console_puts
    mov ecx, 8
.digit:
    rol ebx, 4
    mov eax, ebx
    and eax, 15
    mov al, [hex_digits+eax]
    call console_putc
    loop .digit
    popad
    ret
print_newline:
    push eax
    mov al, 10
    call console_putc
    pop eax
    ret
number_buffer times 12 db 0
hex_digits db '0123456789ABCDEF'
hex_prefix db '0x',0
