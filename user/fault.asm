%define PH_COUNT 1
%include "user/elf.inc"
_start:
    mov eax, [0x10000]       ; supervisor memory: process terminates, kernel survives
    ud2
text_end:
