%define PH_COUNT 1
%include "user/elf.inc"
_start:
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
message db 'Hello from a real ELF32 Assembly program in ring 3.',10
message_end:
text_end:
