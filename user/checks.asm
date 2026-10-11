%define PH_COUNT 2
%include "user/elf.inc"
_start:
    cmp dword [USER_DATA], 0x41544144
    jne .bad
    cmp dword [USER_DATA+4096], 0
    jne .bad
    mov dword [USER_DATA+4096], 0x12345678
    cmp dword [USER_DATA+4096], 0x12345678
    jne .bad
    mov byte [USER_DATA+4095], 'A'
    mov byte [USER_DATA+4096], 'B'
    mov eax, 1
    mov ebx, USER_DATA+4095
    mov ecx, 2
    int 0x80
    cmp eax, 2
    jne .bad
    mov eax, 1
    mov ebx, USER_BASE+4095
    mov ecx, 2               ; second page is absent: reject before copying first byte
    int 0x80
    cmp eax, -14
    jne .bad
    mov eax, 1
    mov ebx, 0xfffffff0
    mov ecx, 32
    int 0x80
    cmp eax, -14
    jne .bad
    mov eax, 1
    mov ebx, message
    mov ecx, 1025
    int 0x80
    cmp eax, -14
    jne .bad
    mov eax, 1
    mov ebx, message
    mov ecx, message_end-message
    int 0x80
    cmp eax, message_end-message
    jne .bad
    xor ebx, ebx
.exit:
    mov eax, 2
    int 0x80
    ud2
.bad:
    mov ebx, 1
    jmp .exit
message db 10,'ELF BSS/RW data and cross-page syscall checks PASS',10
message_end:
text_end:
    times 8192-($-$$) db 0
    db 'DATA'
