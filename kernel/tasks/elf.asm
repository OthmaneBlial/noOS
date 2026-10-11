; Static ELF32/i386 subset: 1..4 ordered, page-aligned PT_LOAD segments, <=64 KiB.
command_run:
    call initrd_find
    test eax, eax
    jz .missing
    mov edx, [eax+36]
    mov [elf_size], edx
    mov esi, [eax+32]
    add esi, initrd_start
    mov [elf_file], esi
    call elf_validate
    jc .invalid
    call user_prepare
    jc .memory
    mov dword [user_mode], 0
    mov ebp, [elf_headers]
    mov eax, [elf_count]
    mov [elf_load_count], eax
.segment:
    mov ebx, [ebp+8]
    sub ebx, USER_BASE
    shr ebx, 12
    mov ecx, [ebp+20]
    add ecx, 4095
    shr ecx, 12
    mov esi, [ebp+4]
    add esi, [elf_file]
    mov edx, [ebp+16]
    mov [elf_remaining], edx
.page:
    call user_frame
    jc .cleanup
    mov edi, [user_table]
    mov edx, eax
    or edx, 5
    test byte [ebp+24], 2
    jz .permission
    or edx, 2
.permission:
    mov [edi+ebx*4], edx
    mov edi, eax
    push ecx
    mov ecx, [elf_remaining]
    cmp ecx, 4096
    jbe .copy
    mov ecx, 4096
.copy:
    sub [elf_remaining], ecx
    rep movsb               ; zero-filled remainder is the segment's BSS
    pop ecx
    inc ebx
    loop .page
    add ebp, 32
    dec dword [elf_load_count]
    jnz .segment
    mov eax, [elf_file]
    mov eax, [eax+24]
    mov [user_entry], eax
    call user_enter
    call user_cleanup
    mov esi, user_returned
    call console_puts
    call print_hex
    jmp print_newline
.cleanup:
    call user_cleanup
.memory:
    mov esi, user_no_memory
    jmp console_puts
.invalid:
    mov esi, elf_bad
    jmp console_puts
.missing:
    mov esi, elf_missing
    jmp console_puts
; Validate the complete untrusted metadata before allocating or copying anything.
elf_validate:
    pushad
    cmp dword [elf_size], 52
    jb .bad
    mov esi, [elf_file]
    cmp dword [esi], 0x464c457f
    jne .bad
    cmp dword [esi+4], 0x00010101 ; class32, little-endian, version1, System V ABI
    jne .bad
    cmp dword [esi+8], 0
    jne .bad
    cmp dword [esi+12], 0
    jne .bad
    cmp dword [esi+16], 0x00030002 ; ET_EXEC, EM_386
    jne .bad
    cmp dword [esi+20], 1
    jne .bad
    cmp dword [esi+36], 0
    jne .bad
    cmp word [esi+40], 52
    jne .bad
    cmp word [esi+42], 32
    jne .bad
    movzx ecx, word [esi+44]
    test ecx, ecx
    jz .bad
    cmp ecx, 4
    ja .bad
    mov [elf_count], ecx
    mov eax, [esi+28]
    cmp eax, 52
    jb .bad
    test eax, 3
    jnz .bad
    imul edx, ecx, 32
    add edx, eax
    jc .bad
    cmp edx, [elf_size]
    ja .bad
    mov [elf_header_end], edx
    add eax, esi
    mov [elf_headers], eax
    mov ebp, eax
    mov edi, USER_BASE        ; prior rounded segment end, disallow shared pages
    mov byte [elf_entry_valid], 0
.segment:
    cmp dword [ebp], 1
    jne .bad
    cmp dword [ebp+28], 4096
    jne .bad
    mov eax, [ebp+4]
    test eax, 4095
    jnz .bad
    cmp eax, [elf_header_end]
    jb .bad
    add eax, [ebp+16]
    jc .bad
    cmp eax, [elf_size]
    ja .bad
    mov eax, [ebp+8]
    test eax, 4095
    jnz .bad
    cmp eax, edi
    jb .bad
    cmp eax, USER_CODE_LIMIT
    jae .bad
    mov edx, [ebp+20]
    test edx, edx
    jz .bad
    cmp edx, [ebp+16]
    jb .bad
    add edx, eax
    jc .bad
    cmp edx, USER_CODE_LIMIT
    ja .bad
    add edx, 4095
    and edx, -4096
    mov edi, edx
    mov edx, [ebp+24]
    cmp edx, 4               ; supported flags: R, R|X, R|W; reject W|X
    je .next
    cmp edx, 6
    je .next
    cmp edx, 5
    jne .bad
    mov edx, [esi+24]
    cmp edx, eax
    jb .next
    add eax, [ebp+16]
    cmp edx, eax
    jae .next
    mov byte [elf_entry_valid], 1
.next:
    add ebp, 32
    dec ecx
    jnz .segment
    cmp byte [elf_entry_valid], 1
    jne .bad
    popad
    clc
    ret
.bad:
    popad
    stc
    ret
align 4
elf_file dd 0
elf_size dd 0
elf_headers dd 0
elf_count dd 0
elf_load_count dd 0
elf_header_end dd 0
elf_remaining dd 0
elf_entry_valid db 0
elf_bad db '[ELF ERROR] Unsupported or invalid ELF32 metadata',10,0
elf_missing db 'Usage: run NAME.elf (file in /initrd)',10,0
