initrd_init:
    pushad
    cmp dword [initrd_start], 0x4452494e
    jne .fail
    cmp dword [initrd_start+4], 1
    jne .fail
    mov ecx, [initrd_start+8]
    test ecx, ecx
    jz .fail
    cmp ecx, 16
    ja .fail
    cmp dword [initrd_start+12], initrd_end-initrd_start
    jne .fail
    imul edx, ecx, 40
    add edx, 16
    cmp edx, initrd_end-initrd_start
    ja .fail
    mov ebp, edx              ; minimum next data offset; reject overlapping/out-of-order data
    mov esi, initrd_start+16
.entry:
    cmp byte [esi], 0
    je .fail
    xor edi, edi
.name:
    mov al, [esi+edi]
    test al, al
    jz .name_ok
    cmp al, 32
    jb .fail
    cmp al, 127
    jae .fail
    cmp al, '/'
    je .fail
    inc edi
    cmp edi, 32
    jb .name
    jmp .fail
.name_ok:
    mov edi, initrd_start+16
.duplicate:
    cmp edi, esi
    je .bounds
    call string_equal
    test eax, eax
    jnz .fail
    add edi, 40
    jmp .duplicate
.bounds:
    mov eax, [esi+32]
    cmp eax, ebp
    jb .fail
    add eax, [esi+36]
    jc .fail
    cmp eax, initrd_end-initrd_start
    ja .fail
    mov ebp, eax
    add esi, 40
    loop .entry
    mov esi, initrd_ok
    call console_puts
    popad
    ret
.fail:
    mov esi, initrd_bad
    call console_puts
    int 3
; ESI=name, EAX=entry pointer or zero. Preserve other registers.
initrd_find:
    push ecx
    push edi
    mov ecx, [initrd_start+8]
    mov edi, initrd_start+16
.entry:
    call string_equal
    test eax, eax
    jnz .found
    add edi, 40
    loop .entry
    xor eax, eax
    jmp .done
.found:
    mov eax, edi
.done:
    pop edi
    pop ecx
    ret
initrd_ls:
    mov esi, initrd_heading
    call console_puts
    mov ebp, initrd_start+16
    mov ecx, [initrd_start+8]
.file:
    mov esi, ebp
    call console_puts
    mov esi, help_indent
    call console_puts
    mov eax, [ebp+36]
    call print_u32
    mov esi, initrd_bytes
    call console_puts
    add ebp, 40
    loop .file
    ret
initrd_cat:
    cmp byte [esi], 0
    je .usage
    call initrd_find
    test eax, eax
    jz .missing
    mov ecx, [eax+36]
    mov esi, [eax+32]
    add esi, initrd_start
    test ecx, ecx
    jz .newline
.byte:
    lodsb
    call console_putc
    loop .byte
.newline:
    jmp print_newline
.usage:
    mov esi, cat_usage
    jmp console_puts
.missing:
    mov esi, file_missing
    jmp console_puts
initrd_ok db '[FS] Validated read-only initrd',10,0
initrd_bad db '[FS ERROR] Invalid initrd metadata',10,0
initrd_heading db 'Read-only initrd /initrd',10,0
initrd_bytes db ' bytes',10,0
cat_usage db 'Usage: cat FILE',10,0
file_missing db 'File not found in read-only initrd.',10,0
align 4
initrd_start:
    incbin "build/initrd.bin"
initrd_end:
